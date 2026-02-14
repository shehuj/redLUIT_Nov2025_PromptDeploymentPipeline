#!/usr/bin/env python3
"""
Prompt Processing Script for Amazon Bedrock
Loads prompt templates, fills in variables, sends to Bedrock, and uploads to S3.

Security Features:
- Path traversal protection
- Input validation
- Structured logging
- Error handling with context
"""

import json
import os
import sys
import argparse
import logging
import hashlib
import re
from pathlib import Path
from string import Template
from typing import Dict, Any, Optional, List
from jsonschema import validate, ValidationError
import boto3
from botocore.exceptions import ClientError, BotoCoreError

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('prompt_processor.log')
    ]
)
logger = logging.getLogger(__name__)

# JSON Schema for prompt configuration validation
PROMPT_CONFIG_SCHEMA = {
    "type": "object",
    "properties": {
        "template": {"type": "string", "pattern": "^[a-zA-Z0-9_-]+\\.txt$"},
        "output_name": {"type": "string", "pattern": "^[a-zA-Z0-9_-]+$"},
        "output_format": {"type": "string", "enum": ["html", "md"]},
        "model_id": {"type": "string"},
        "model_params": {
            "type": "object",
            "properties": {
                "max_tokens": {"type": "integer", "minimum": 1, "maximum": 100000},
                "temperature": {"type": "number", "minimum": 0, "maximum": 1},
                "top_p": {"type": "number", "minimum": 0, "maximum": 1}
            }
        },
        "variables": {"type": "object"}
    },
    "required": ["template", "output_name", "variables"]
}


class PromptProcessor:
    """Handles prompt processing with Amazon Bedrock and S3 upload.

    Security features:
    - Validates all file paths to prevent directory traversal
    - Validates JSON schemas
    - Implements structured logging
    - Validates AWS resource names
    """

    # Allowed base directories
    PROMPT_TEMPLATES_DIR = Path('prompt_templates').resolve()
    OUTPUTS_DIR = Path('outputs').resolve()
    PROMPTS_DIR = Path('prompts').resolve()

    # Security limits
    MAX_TEMPLATE_SIZE = 100 * 1024  # 100KB
    MAX_OUTPUT_SIZE = 10 * 1024 * 1024  # 10MB
    MAX_VARIABLES = 50

    # Allowed AWS regions (restrict to known regions)
    ALLOWED_REGIONS = {
        'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2',
        'eu-west-1', 'eu-west-2', 'eu-central-1',
        'ap-southeast-1', 'ap-southeast-2', 'ap-northeast-1'
    }

    def __init__(self, aws_region: str, s3_bucket: str, s3_prefix: str):
        """
        Initialize the processor with security validation.

        Args:
            aws_region: AWS region for Bedrock and S3
            s3_bucket: S3 bucket name for uploads
            s3_prefix: S3 prefix (e.g., 'beta/' or 'prod/')

        Raises:
            ValueError: If parameters fail validation
        """
        # Validate AWS region
        if aws_region not in self.ALLOWED_REGIONS:
            raise ValueError(f"Invalid AWS region: {aws_region}. Allowed: {self.ALLOWED_REGIONS}")

        # Validate S3 bucket name format
        if not self._validate_s3_bucket_name(s3_bucket):
            raise ValueError(f"Invalid S3 bucket name: {s3_bucket}")

        # Validate and sanitize S3 prefix
        if not self._validate_s3_prefix(s3_prefix):
            raise ValueError(f"Invalid S3 prefix: {s3_prefix}")

        self.aws_region = aws_region
        self.s3_bucket = s3_bucket
        self.s3_prefix = s3_prefix.rstrip('/') + '/'

        logger.info(f"Initializing PromptProcessor: region={aws_region}, bucket={s3_bucket}, prefix={s3_prefix}")

        try:
            # Initialize AWS clients
            self.bedrock_runtime = boto3.client(
                service_name='bedrock-runtime',
                region_name=aws_region
            )
            self.s3_client = boto3.client('s3', region_name=aws_region)
            logger.info("AWS clients initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize AWS clients: {e}", exc_info=True)
            raise

    @staticmethod
    def _validate_s3_bucket_name(bucket_name: str) -> bool:
        """Validate S3 bucket name format.

        Args:
            bucket_name: Bucket name to validate

        Returns:
            True if valid, False otherwise
        """
        # S3 bucket naming rules
        pattern = r'^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$'
        if not re.match(pattern, bucket_name):
            return False
        if '..' in bucket_name or '.-' in bucket_name or '-.' in bucket_name:
            return False
        return True

    @staticmethod
    def _validate_s3_prefix(prefix: str) -> bool:
        """Validate S3 prefix (no path traversal).

        Args:
            prefix: S3 prefix to validate

        Returns:
            True if valid, False otherwise
        """
        # Disallow path traversal attempts
        if '..' in prefix or prefix.startswith('/'):
            return False
        # Only allow alphanumeric, hyphens, underscores, and forward slashes
        pattern = r'^[a-zA-Z0-9/_-]*$'
        return bool(re.match(pattern, prefix))

    def _validate_path(self, file_path: Path, base_dir: Path) -> Path:
        """Validate that a file path is within the allowed base directory.

        Args:
            file_path: Path to validate
            base_dir: Base directory that path must be within

        Returns:
            Resolved absolute path

        Raises:
            ValueError: If path is outside base directory
        """
        try:
            # Resolve to absolute path
            resolved_path = file_path.resolve()
            resolved_base = base_dir.resolve()

            # Check if path is within base directory
            if not str(resolved_path).startswith(str(resolved_base)):
                logger.error(f"Path traversal attempt detected: {file_path} outside {base_dir}")
                raise ValueError(f"Path {file_path} is outside allowed directory {base_dir}")

            return resolved_path
        except Exception as e:
            logger.error(f"Path validation failed: {e}", exc_info=True)
            raise ValueError(f"Invalid path: {file_path}")

    def load_config(self, config_path: str) -> Dict[str, Any]:
        """Load and validate prompt configuration from JSON file.

        Args:
            config_path: Path to configuration JSON file

        Returns:
            Validated configuration dictionary

        Raises:
            ValueError: If config is invalid
            FileNotFoundError: If file doesn't exist
        """
        try:
            config_file = Path(config_path)

            # Validate path is within prompts directory
            validated_path = self._validate_path(config_file, self.PROMPTS_DIR)

            logger.info(f"Loading configuration from: {validated_path}")

            with open(validated_path, 'r') as f:
                config = json.load(f)

            # Validate against schema
            try:
                validate(instance=config, schema=PROMPT_CONFIG_SCHEMA)
            except ValidationError as e:
                logger.error(f"Configuration validation failed: {e.message}")
                raise ValueError(f"Invalid configuration: {e.message}")

            # Additional security validations
            if len(config.get('variables', {})) > self.MAX_VARIABLES:
                raise ValueError(f"Too many variables: {len(config['variables'])} > {self.MAX_VARIABLES}")

            logger.info(f"Configuration loaded and validated successfully")
            return config

        except FileNotFoundError:
            logger.error(f"Configuration file not found: {config_path}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in configuration file: {e}")
            raise ValueError(f"Invalid JSON: {e}")
        except Exception as e:
            logger.error(f"Error loading configuration: {e}", exc_info=True)
            raise

    def load_template(self, template_path: str) -> str:
        """Load and validate prompt template from file.

        Args:
            template_path: Path to template file

        Returns:
            Template content

        Raises:
            ValueError: If template is invalid
            FileNotFoundError: If file doesn't exist
        """
        try:
            template_file = Path(template_path)

            # Validate path is within templates directory
            validated_path = self._validate_path(template_file, self.PROMPT_TEMPLATES_DIR)

            logger.info(f"Loading template from: {validated_path}")

            # Check file size
            file_size = validated_path.stat().st_size
            if file_size > self.MAX_TEMPLATE_SIZE:
                raise ValueError(f"Template too large: {file_size} > {self.MAX_TEMPLATE_SIZE}")

            with open(validated_path, 'r', encoding='utf-8') as f:
                content = f.read()

            logger.info(f"Template loaded successfully: {len(content)} bytes")
            return content

        except FileNotFoundError:
            logger.error(f"Template file not found: {template_path}")
            raise
        except Exception as e:
            logger.error(f"Error loading template: {e}", exc_info=True)
            raise

    def render_template(self, template_content: str, variables: Dict[str, Any]) -> str:
        """
        Render template with variables using Python's Template.

        Args:
            template_content: Template string with $variable placeholders
            variables: Dictionary of variable values

        Returns:
            Rendered string

        Raises:
            ValueError: If required variables are missing
        """
        try:
            template = Template(template_content)
            # Use substitute() instead of safe_substitute() to fail on missing variables
            rendered = template.substitute(variables)
            logger.debug(f"Template rendered successfully: {len(rendered)} bytes")
            return rendered
        except KeyError as e:
            logger.error(f"Missing required variable: {e}")
            raise ValueError(f"Missing required variable: {e}")
        except Exception as e:
            logger.error(f"Error rendering template: {e}", exc_info=True)
            raise

    def invoke_bedrock(self, prompt, model_id=None, model_params=None):
        """
        Send prompt to Amazon Bedrock and get response.

        Args:
            prompt: The rendered prompt to send
            model_id: Bedrock model ID (default: Claude 3 Sonnet)
            model_params: Model-specific parameters

        Returns:
            Generated text response
        """
        if model_id is None:
            model_id = "anthropic.claude-3-sonnet-20240229-v1:0"

        if model_params is None:
            model_params = {
                "max_tokens": 2048,
                "temperature": 0.7,
                "top_p": 0.9
            }

        # Prepare request body based on model family
        if "anthropic.claude" in model_id:
            body = json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": model_params.get("max_tokens", 2048),
                "temperature": model_params.get("temperature", 0.7),
                "top_p": model_params.get("top_p", 0.9),
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            })
        elif "amazon.titan" in model_id:
            body = json.dumps({
                "inputText": prompt,
                "textGenerationConfig": {
                    "maxTokenCount": model_params.get("max_tokens", 2048),
                    "temperature": model_params.get("temperature", 0.7),
                    "topP": model_params.get("top_p", 0.9)
                }
            })
        else:
            raise ValueError(f"Unsupported model family: {model_id}")

        try:
            response = self.bedrock_runtime.invoke_model(
                modelId=model_id,
                contentType="application/json",
                accept="application/json",
                body=body
            )

            response_body = json.loads(response['body'].read())

            # Extract text based on model family
            if "anthropic.claude" in model_id:
                return response_body['content'][0]['text']
            elif "amazon.titan" in model_id:
                return response_body['results'][0]['outputText']
            else:
                return str(response_body)

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            logger.error(f"Bedrock API error [{error_code}]: {error_message}", exc_info=True)
            raise RuntimeError(f"Bedrock invocation failed: {error_code} - {error_message}")
        except BotoCoreError as e:
            logger.error(f"Boto core error: {e}", exc_info=True)
            raise RuntimeError(f"AWS SDK error: {e}")

    def save_output(self, content, output_path, format_type='html'):
        """
        Save generated content to file.

        Args:
            content: Generated content from Bedrock
            output_path: Local file path to save
            format_type: Output format ('html' or 'md')
        """
        # Add HTML wrapper if needed
        if format_type == 'html' and not content.strip().startswith('<!DOCTYPE') and not content.strip().startswith('<html'):
            content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Generated Content</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }}
        pre {{
            background: #f4f4f4;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 15px;
            overflow-x: auto;
        }}
        code {{
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
        }}
    </style>
</head>
<body>
{content}
</body>
</html>"""

        # Create output directory if it doesn't exist
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with open(output_path, 'w') as f:
            f.write(content)

        print(f"✅ Saved output to: {output_path}")

    def upload_to_s3(self, local_path, s3_key):
        """
        Upload file to S3 bucket.

        Args:
            local_path: Local file path
            s3_key: S3 object key (with prefix)
        """
        # Determine content type
        if s3_key.endswith('.html'):
            content_type = 'text/html'
        elif s3_key.endswith('.md'):
            content_type = 'text/markdown'
        else:
            content_type = 'text/plain'

        try:
            self.s3_client.upload_file(
                local_path,
                self.s3_bucket,
                s3_key,
                ExtraArgs={
                    'ContentType': content_type,
                    'CacheControl': 'max-age=300'
                }
            )

            s3_url = f"https://{self.s3_bucket}.s3.{self.aws_region}.amazonaws.com/{s3_key}"
            print(f"✅ Uploaded to S3: s3://{self.s3_bucket}/{s3_key}")
            print(f"   URL: {s3_url}")
            return s3_url

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_message = e.response.get('Error', {}).get('Message', str(e))
            logger.error(f"S3 upload error [{error_code}]: {error_message}", exc_info=True)
            raise RuntimeError(f"S3 upload failed: {error_code} - {error_message}")

    def process_prompt(self, config_path: str) -> Dict[str, Any]:
        """
        Main processing function: load config, render template, invoke Bedrock, save, and upload.

        Args:
            config_path: Path to prompt configuration JSON file

        Returns:
            Dictionary with processing results

        Raises:
            RuntimeError: If processing fails
        """
        logger.info(f"Starting prompt processing: {config_path}")
        print(f"📋 Processing prompt config: {config_path}")

        # Load configuration
        config = self.load_config(config_path)

        # Extract configuration
        template_name = config.get('template')
        variables = config.get('variables', {})
        output_name = config.get('output_name')
        output_format = config.get('output_format', 'html')
        model_id = config.get('model_id')
        model_params = config.get('model_params', {})

        # Validate required fields
        if not template_name:
            raise ValueError("Config must specify 'template' field")
        if not output_name:
            raise ValueError("Config must specify 'output_name' field")

        # Construct paths
        template_path = Path('prompt_templates') / template_name
        output_path = Path('outputs') / f"{output_name}.{output_format}"

        print(f"📄 Template: {template_path}")
        print(f"📝 Variables: {json.dumps(variables, indent=2)}")

        # Load and render template
        template_content = self.load_template(template_path)
        rendered_prompt = self.render_template(template_content, variables)

        print(f"\n🔹 Rendered Prompt:\n{'-' * 50}")
        print(rendered_prompt[:500] + ('...' if len(rendered_prompt) > 500 else ''))
        print(f"{'-' * 50}\n")

        # Invoke Bedrock
        print(f"🤖 Invoking Bedrock (model: {model_id or 'default'})...")
        generated_content = self.invoke_bedrock(
            rendered_prompt,
            model_id=model_id,
            model_params=model_params
        )

        print(f"\n🔹 Generated Content:\n{'-' * 50}")
        print(generated_content[:500] + ('...' if len(generated_content) > 500 else ''))
        print(f"{'-' * 50}\n")

        # Save output locally
        self.save_output(generated_content, str(output_path), output_format)

        # Upload to S3
        s3_key = f"{self.s3_prefix}outputs/{output_name}.{output_format}"
        s3_url = self.upload_to_s3(str(output_path), s3_key)

        return {
            'config_path': str(config_path),
            'output_path': str(output_path),
            's3_key': s3_key,
            's3_url': s3_url,
            'status': 'success'
        }


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description='Process prompts with Amazon Bedrock and upload to S3'
    )
    parser.add_argument(
        'config_files',
        nargs='+',
        help='Path(s) to prompt configuration JSON file(s)'
    )
    parser.add_argument(
        '--region',
        default=os.environ.get('AWS_REGION', 'us-east-1'),
        help='AWS region (default: AWS_REGION env var or us-east-1)'
    )
    parser.add_argument(
        '--bucket',
        default=os.environ.get('S3_BUCKET'),
        required=False,
        help='S3 bucket name (default: S3_BUCKET env var)'
    )
    parser.add_argument(
        '--prefix',
        default=os.environ.get('S3_PREFIX', 'beta/'),
        help='S3 prefix (default: S3_PREFIX env var or beta/)'
    )

    args = parser.parse_args()

    # Validate required parameters
    if not args.bucket:
        print("❌ Error: S3 bucket must be specified via --bucket or S3_BUCKET env var")
        sys.exit(1)

    # Initialize processor
    processor = PromptProcessor(
        aws_region=args.region,
        s3_bucket=args.bucket,
        s3_prefix=args.prefix
    )

    # Process each config file
    results = []
    failed = []

    for config_file in args.config_files:
        try:
            result = processor.process_prompt(config_file)
            results.append(result)
            print(f"✅ Successfully processed: {config_file}\n")
        except Exception as e:
            print(f"❌ Failed to process {config_file}: {e}\n")
            failed.append(config_file)

    # Print summary
    print("\n" + "=" * 60)
    print("📊 PROCESSING SUMMARY")
    print("=" * 60)
    print(f"✅ Successful: {len(results)}")
    print(f"❌ Failed: {len(failed)}")

    if results:
        print("\n🔗 Generated URLs:")
        for result in results:
            print(f"  - {result['s3_url']}")

    if failed:
        print("\n⚠️  Failed files:")
        for f in failed:
            print(f"  - {f}")
        sys.exit(1)

    print("\n✅ All prompts processed successfully!")


if __name__ == '__main__':
    main()
