"""Unit tests for process_prompt.py"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from jsonschema import ValidationError

# Import after path is set
import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from scripts.process_prompt import PromptProcessor, PROMPT_CONFIG_SCHEMA


class TestPromptProcessor:
    """Test cases for PromptProcessor class."""

    def test_validate_s3_bucket_name_valid(self):
        """Test S3 bucket name validation with valid names."""
        valid_names = [
            "my-bucket",
            "my.bucket.123",
            "a-b-c",
            "test-bucket-2024"
        ]
        for name in valid_names:
            assert PromptProcessor._validate_s3_bucket_name(name), f"Should be valid: {name}"

    def test_validate_s3_bucket_name_invalid(self):
        """Test S3 bucket name validation with invalid names."""
        invalid_names = [
            "My-Bucket",  # uppercase
            "my_bucket",  # underscore
            "a",  # too short
            "-bucket",  # starts with hyphen
            "bucket-",  # ends with hyphen
            "bucket..name",  # consecutive dots
            "bucket.-name",  # dot-dash
        ]
        for name in invalid_names:
            assert not PromptProcessor._validate_s3_bucket_name(name), f"Should be invalid: {name}"

    def test_validate_s3_prefix_valid(self):
        """Test S3 prefix validation with valid prefixes."""
        valid_prefixes = [
            "beta/",
            "prod/",
            "test/outputs/",
            "a-b-c/",
            ""
        ]
        for prefix in valid_prefixes:
            assert PromptProcessor._validate_s3_prefix(prefix), f"Should be valid: {prefix}"

    def test_validate_s3_prefix_invalid(self):
        """Test S3 prefix validation with invalid prefixes."""
        invalid_prefixes = [
            "../etc/",  # path traversal
            "/absolute/",  # absolute path
            "test/../prod/",  # path traversal
        ]
        for prefix in invalid_prefixes:
            assert not PromptProcessor._validate_s3_prefix(prefix), f"Should be invalid: {prefix}"

    def test_init_valid_parameters(self, mock_aws_credentials):
        """Test PromptProcessor initialization with valid parameters."""
        processor = PromptProcessor(
            aws_region="us-east-1",
            s3_bucket="test-bucket",
            s3_prefix="beta/"
        )
        assert processor.aws_region == "us-east-1"
        assert processor.s3_bucket == "test-bucket"
        assert processor.s3_prefix == "beta/"

    def test_init_invalid_region(self, mock_aws_credentials):
        """Test PromptProcessor initialization with invalid region."""
        with pytest.raises(ValueError, match="Invalid AWS region"):
            PromptProcessor(
                aws_region="invalid-region",
                s3_bucket="test-bucket",
                s3_prefix="beta/"
            )

    def test_init_invalid_bucket_name(self, mock_aws_credentials):
        """Test PromptProcessor initialization with invalid bucket name."""
        with pytest.raises(ValueError, match="Invalid S3 bucket name"):
            PromptProcessor(
                aws_region="us-east-1",
                s3_bucket="Invalid_Bucket",
                s3_prefix="beta/"
            )

    def test_validate_path_within_base_dir(self, temp_dir):
        """Test path validation for paths within base directory."""
        processor = PromptProcessor(
            aws_region="us-east-1",
            s3_bucket="test-bucket",
            s3_prefix="beta/"
        )

        base_dir = temp_dir
        test_file = base_dir / "test.txt"
        test_file.touch()

        validated = processor._validate_path(test_file, base_dir)
        assert validated == test_file.resolve()

    def test_validate_path_outside_base_dir(self, temp_dir):
        """Test path validation for paths outside base directory."""
        processor = PromptProcessor(
            aws_region="us-east-1",
            s3_bucket="test-bucket",
            s3_prefix="beta/"
        )

        base_dir = temp_dir / "allowed"
        base_dir.mkdir()

        outside_dir = temp_dir / "forbidden"
        outside_dir.mkdir()
        test_file = outside_dir / "test.txt"
        test_file.touch()

        with pytest.raises(ValueError, match="outside allowed directory"):
            processor._validate_path(test_file, base_dir)

    def test_load_config_valid(self, temp_dir, sample_config):
        """Test loading valid configuration file."""
        # Create config file
        config_path = temp_dir / "prompts" / "test.json"
        config_path.parent.mkdir(parents=True)
        with open(config_path, 'w') as f:
            json.dump(sample_config, f)

        # Change working directory
        import os
        old_cwd = os.getcwd()
        os.chdir(temp_dir)

        try:
            processor = PromptProcessor(
                aws_region="us-east-1",
                s3_bucket="test-bucket",
                s3_prefix="beta/"
            )
            config = processor.load_config(str(config_path))
            assert config == sample_config
        finally:
            os.chdir(old_cwd)

    def test_load_config_invalid_json(self, temp_dir):
        """Test loading invalid JSON configuration."""
        config_path = temp_dir / "prompts" / "invalid.json"
        config_path.parent.mkdir(parents=True)
        with open(config_path, 'w') as f:
            f.write("{ invalid json }")

        import os
        old_cwd = os.getcwd()
        os.chdir(temp_dir)

        try:
            processor = PromptProcessor(
                aws_region="us-east-1",
                s3_bucket="test-bucket",
                s3_prefix="beta/"
            )
            with pytest.raises(ValueError, match="Invalid JSON"):
                processor.load_config(str(config_path))
        finally:
            os.chdir(old_cwd)

    def test_load_template_valid(self, temp_dir):
        """Test loading valid template file."""
        template_path = temp_dir / "prompt_templates" / "test.txt"
        template_path.parent.mkdir(parents=True)
        template_content = "Hello $name!"
        with open(template_path, 'w') as f:
            f.write(template_content)

        import os
        old_cwd = os.getcwd()
        os.chdir(temp_dir)

        try:
            processor = PromptProcessor(
                aws_region="us-east-1",
                s3_bucket="test-bucket",
                s3_prefix="beta/"
            )
            content = processor.load_template(str(template_path))
            assert content == template_content
        finally:
            os.chdir(old_cwd)

    def test_render_template_success(self):
        """Test template rendering with all variables provided."""
        processor = PromptProcessor(
            aws_region="us-east-1",
            s3_bucket="test-bucket",
            s3_prefix="beta/"
        )

        template = "Hello $name from $company!"
        variables = {"name": "John", "company": "TechCorp"}

        result = processor.render_template(template, variables)
        assert result == "Hello John from TechCorp!"

    def test_render_template_missing_variable(self):
        """Test template rendering with missing variables."""
        processor = PromptProcessor(
            aws_region="us-east-1",
            s3_bucket="test-bucket",
            s3_prefix="beta/"
        )

        template = "Hello $name from $company!"
        variables = {"name": "John"}  # missing 'company'

        with pytest.raises(ValueError, match="Missing required variable"):
            processor.render_template(template, variables)


class TestSecurityValidation:
    """Test security features and input validation."""

    def test_path_traversal_prevention_in_template(self, temp_dir):
        """Test that path traversal is prevented in template loading."""
        import os
        old_cwd = os.getcwd()
        os.chdir(temp_dir)

        try:
            processor = PromptProcessor(
                aws_region="us-east-1",
                s3_bucket="test-bucket",
                s3_prefix="beta/"
            )

            malicious_path = "../../etc/passwd"
            with pytest.raises((ValueError, FileNotFoundError)):
                processor.load_template(malicious_path)
        finally:
            os.chdir(old_cwd)

    def test_config_schema_validation(self):
        """Test that configuration schema validation works."""
        from jsonschema import validate

        # Valid config
        valid_config = {
            "template": "valid.txt",
            "output_name": "output",
            "variables": {"key": "value"}
        }
        validate(instance=valid_config, schema=PROMPT_CONFIG_SCHEMA)  # Should not raise

        # Invalid config - bad template name
        invalid_config = {
            "template": "../etc/passwd",
            "output_name": "output",
            "variables": {}
        }
        with pytest.raises(ValidationError):
            validate(instance=invalid_config, schema=PROMPT_CONFIG_SCHEMA)

    def test_max_variables_limit(self, temp_dir, sample_config):
        """Test that configuration with too many variables is rejected."""
        # Create config with too many variables
        sample_config["variables"] = {f"var_{i}": f"value_{i}" for i in range(100)}

        config_path = temp_dir / "prompts" / "test.json"
        config_path.parent.mkdir(parents=True)
        with open(config_path, 'w') as f:
            json.dump(sample_config, f)

        import os
        old_cwd = os.getcwd()
        os.chdir(temp_dir)

        try:
            processor = PromptProcessor(
                aws_region="us-east-1",
                s3_bucket="test-bucket",
                s3_prefix="beta/"
            )

            with pytest.raises(ValueError, match="Too many variables"):
                processor.load_config(str(config_path))
        finally:
            os.chdir(old_cwd)
