#!/usr/bin/env python3
"""
Setup verification script for Prompt Deployment Pipeline
Checks AWS credentials, Bedrock access, and S3 bucket permissions.
"""

import sys
import os
import boto3
from botocore.exceptions import ClientError, NoCredentialsError


def print_header(text):
    """Print formatted header."""
    print(f"\n{'=' * 60}")
    print(f"  {text}")
    print('=' * 60)


def print_success(text):
    """Print success message."""
    print(f"✅ {text}")


def print_error(text):
    """Print error message."""
    print(f"❌ {text}")


def print_warning(text):
    """Print warning message."""
    print(f"⚠️  {text}")


def check_aws_credentials():
    """Verify AWS credentials are configured."""
    print_header("Checking AWS Credentials")

    try:
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()

        print_success("AWS credentials are configured")
        print(f"   Account: {identity['Account']}")
        print(f"   User ARN: {identity['Arn']}")
        return True

    except NoCredentialsError:
        print_error("AWS credentials not found")
        print("   Please run 'aws configure' or set environment variables")
        return False
    except Exception as e:
        print_error(f"Error checking credentials: {e}")
        return False


def check_bedrock_access(region='us-east-1'):
    """Verify Bedrock access and model availability."""
    print_header(f"Checking Amazon Bedrock Access ({region})")

    try:
        bedrock = boto3.client('bedrock', region_name=region)

        # List available models
        response = bedrock.list_foundation_models()
        models = response.get('modelSummaries', [])

        if not models:
            print_warning("No Bedrock models found")
            print("   You may need to enable model access in the Bedrock console")
            return False

        print_success("Bedrock is accessible")

        # Check for Claude models
        claude_models = [m for m in models if 'claude' in m['modelId'].lower()]
        if claude_models:
            print_success(f"Found {len(claude_models)} Claude model(s)")
            for model in claude_models[:3]:  # Show first 3
                print(f"   - {model['modelId']}")
        else:
            print_warning("No Claude models found")
            print("   Enable Claude models in Bedrock console")

        return True

    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'AccessDeniedException':
            print_error("Access denied to Bedrock")
            print("   Check IAM permissions for bedrock:ListFoundationModels")
        else:
            print_error(f"Bedrock error: {e}")
        return False
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return False


def check_bedrock_runtime(region='us-east-1'):
    """Test Bedrock runtime by invoking a simple prompt."""
    print_header(f"Testing Bedrock Runtime ({region})")

    try:
        bedrock_runtime = boto3.client('bedrock-runtime', region_name=region)

        # Simple test prompt
        test_prompt = "Say 'Hello, Bedrock is working!' in a friendly tone."
        model_id = "anthropic.claude-3-haiku-20240307-v1:0"

        print(f"   Testing with model: {model_id}")

        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 100,
            "messages": [
                {
                    "role": "user",
                    "content": test_prompt
                }
            ]
        }

        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=str(body).replace("'", '"')
        )

        print_success("Successfully invoked Bedrock model")
        print("   Bedrock runtime is working correctly")
        return True

    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'AccessDeniedException':
            print_error("Access denied to Bedrock runtime")
            print("   Check IAM permissions for bedrock:InvokeModel")
        elif error_code == 'ResourceNotFoundException':
            print_error("Model not found or not enabled")
            print("   Enable model access in Bedrock console")
        else:
            print_error(f"Bedrock runtime error: {e}")
        return False
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return False


def check_s3_bucket(bucket_name, region='us-east-1'):
    """Verify S3 bucket exists and is accessible."""
    print_header(f"Checking S3 Bucket: {bucket_name}")

    try:
        s3 = boto3.client('s3', region_name=region)

        # Check if bucket exists
        s3.head_bucket(Bucket=bucket_name)
        print_success(f"Bucket '{bucket_name}' exists and is accessible")

        # Try to list objects
        response = s3.list_objects_v2(Bucket=bucket_name, MaxKeys=1)
        print_success("Can list objects in bucket")

        # Try to put a test object
        test_key = "test/setup-verification.txt"
        test_content = "This is a test file from setup verification"

        s3.put_object(
            Bucket=bucket_name,
            Key=test_key,
            Body=test_content,
            ContentType='text/plain'
        )
        print_success("Can write objects to bucket")

        # Clean up test object
        s3.delete_object(Bucket=bucket_name, Key=test_key)
        print_success("Can delete objects from bucket")

        return True

    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == '404':
            print_error(f"Bucket '{bucket_name}' does not exist")
        elif error_code == '403':
            print_error(f"Access denied to bucket '{bucket_name}'")
            print("   Check IAM permissions for s3:ListBucket, s3:PutObject")
        else:
            print_error(f"S3 error: {e}")
        return False
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return False


def check_project_structure():
    """Verify project directory structure."""
    print_header("Checking Project Structure")

    required_dirs = ['prompts', 'prompt_templates', 'outputs', 'scripts']
    required_files = [
        'scripts/process_prompt.py',
        'requirements.txt',
        'README.md'
    ]

    all_good = True

    for dir_name in required_dirs:
        if os.path.isdir(dir_name):
            print_success(f"Directory '{dir_name}/' exists")
        else:
            print_error(f"Directory '{dir_name}/' not found")
            all_good = False

    for file_path in required_files:
        if os.path.isfile(file_path):
            print_success(f"File '{file_path}' exists")
        else:
            print_error(f"File '{file_path}' not found")
            all_good = False

    return all_good


def main():
    """Main verification function."""
    print("\n" + "=" * 60)
    print("  Prompt Deployment Pipeline - Setup Verification")
    print("=" * 60)

    # Get configuration from environment or arguments
    aws_region = os.environ.get('AWS_REGION', 'us-east-1')
    s3_bucket_beta = os.environ.get('S3_BUCKET_BETA')
    s3_bucket_prod = os.environ.get('S3_BUCKET_PROD')

    print(f"\nConfiguration:")
    print(f"  AWS Region: {aws_region}")
    print(f"  Beta Bucket: {s3_bucket_beta or 'Not set'}")
    print(f"  Prod Bucket: {s3_bucket_prod or 'Not set'}")

    # Run checks
    results = {
        'Project Structure': check_project_structure(),
        'AWS Credentials': check_aws_credentials(),
        'Bedrock Access': check_bedrock_access(aws_region),
        'Bedrock Runtime': check_bedrock_runtime(aws_region),
    }

    # Check S3 buckets if specified
    if s3_bucket_beta:
        results['S3 Beta Bucket'] = check_s3_bucket(s3_bucket_beta, aws_region)
    else:
        print_header("S3 Beta Bucket")
        print_warning("S3_BUCKET_BETA not set - skipping check")

    if s3_bucket_prod:
        results['S3 Prod Bucket'] = check_s3_bucket(s3_bucket_prod, aws_region)
    else:
        print_header("S3 Prod Bucket")
        print_warning("S3_BUCKET_PROD not set - skipping check")

    # Print summary
    print_header("Verification Summary")

    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for check_name, passed_check in results.items():
        if passed_check:
            print_success(check_name)
        else:
            print_error(check_name)

    print(f"\n{'=' * 60}")
    print(f"  Results: {passed}/{total} checks passed")
    print('=' * 60)

    if passed == total:
        print("\n🎉 All checks passed! You're ready to use the pipeline.")
        return 0
    else:
        print("\n⚠️  Some checks failed. Please review the errors above.")
        print("\nFor help, see:")
        print("  - SETUP_GUIDE.md for detailed setup instructions")
        print("  - README.md for troubleshooting tips")
        return 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nVerification cancelled by user")
        sys.exit(1)
