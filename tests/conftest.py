"""Pytest configuration and shared fixtures."""

import pytest
import os
from pathlib import Path
import tempfile
import shutil
import json


@pytest.fixture
def temp_dir():
    """Create a temporary directory for tests."""
    temp = tempfile.mkdtemp()
    yield Path(temp)
    shutil.rmtree(temp)


@pytest.fixture
def mock_aws_credentials(monkeypatch):
    """Mock AWS credentials for testing."""
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")


@pytest.fixture
def sample_config():
    """Sample prompt configuration for testing."""
    return {
        "template": "test_template.txt",
        "output_name": "test_output",
        "output_format": "html",
        "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
        "model_params": {
            "max_tokens": 2048,
            "temperature": 0.7,
            "top_p": 0.9
        },
        "variables": {
            "name": "Test User",
            "company": "Test Corp"
        }
    }


@pytest.fixture
def sample_template():
    """Sample prompt template for testing."""
    return "Hello $name from $company!"


@pytest.fixture
def create_test_files(temp_dir):
    """Create test directory structure with files."""
    # Create directories
    (temp_dir / "prompts").mkdir()
    (temp_dir / "prompt_templates").mkdir()
    (temp_dir / "outputs").mkdir()

    # Create sample config
    config = {
        "template": "test_template.txt",
        "output_name": "test_output",
        "variables": {"name": "Test"}
    }
    config_path = temp_dir / "prompts" / "test_config.json"
    with open(config_path, 'w') as f:
        json.dump(config, f)

    # Create sample template
    template_path = temp_dir / "prompt_templates" / "test_template.txt"
    with open(template_path, 'w') as f:
        f.write("Hello $name!")

    return temp_dir
