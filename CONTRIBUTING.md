# Contributing to Prompt Deployment Pipeline

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Code Review Process](#code-review-process)
- [Style Guide](#style-guide)
- [Security](#security)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors.

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Accepting constructive criticism gracefully
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes:**
- Harassment or discriminatory language
- Trolling or insulting comments
- Public or private harassment
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

## Getting Started

### Prerequisites

- **Python 3.11+**
- **Terraform 1.5+**
- **AWS CLI** configured
- **Git**
- **GitHub account**

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/redLUIT_Nov2025_PromptDeploymentPipeline.git
   cd redLUIT_Nov2025_PromptDeploymentPipeline
   ```

3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/shehuj/redLUIT_Nov2025_PromptDeploymentPipeline.git
   ```

## Development Setup

### 1. Create Virtual Environment

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
# Production dependencies
pip install -r requirements.txt

# Development dependencies
pip install -r requirements-dev.txt
```

### 3. Install Pre-commit Hooks

```bash
pre-commit install
pre-commit run --all-files  # Test that hooks work
```

### 4. Configure AWS Credentials

```bash
aws configure
# Or set environment variables:
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_REGION=us-east-1
```

### 5. Run Tests

```bash
pytest tests/ -v --cov=scripts
```

## Making Changes

### Branch Naming Convention

- **Feature**: `feature/description-of-feature`
- **Bug Fix**: `fix/description-of-bug`
- **Documentation**: `docs/description-of-docs`
- **Refactor**: `refactor/description-of-refactor`
- **Security**: `security/description-of-fix`

Example:
```bash
git checkout -b feature/add-caching-layer
```

### Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short summary>

<longer description>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `security`: Security improvements

**Examples:**
```
feat(bedrock): add support for Claude 3.5 Opus model

Added support for the new Claude 3.5 Opus model including:
- Model ID configuration
- Request/response handling
- Documentation updates

Closes #123
```

```
fix(s3): prevent path traversal in template loading

Implemented path validation to prevent directory traversal attacks.
All template paths are now resolved and validated against allowed
base directories.

Security impact: High
```

## Testing

### Running Tests

```bash
# All tests
pytest

# With coverage
pytest --cov=scripts --cov-report=html

# Specific test file
pytest tests/test_process_prompt.py

# Specific test
pytest tests/test_process_prompt.py::test_load_config
```

### Writing Tests

#### Unit Tests

Place in `tests/unit/`:

```python
import pytest
from scripts.process_prompt import PromptProcessor

def test_validate_s3_bucket_name():
    """Test S3 bucket name validation."""
    # Valid names
    assert PromptProcessor._validate_s3_bucket_name("my-bucket")
    assert PromptProcessor._validate_s3_bucket_name("my.bucket.123")

    # Invalid names
    assert not PromptProcessor._validate_s3_bucket_name("My-Bucket")  # uppercase
    assert not PromptProcessor._validate_s3_bucket_name("my_bucket")  # underscore
```

#### Integration Tests

Place in `tests/integration/`:

```python
import pytest
import boto3
from moto import mock_s3, mock_bedrock

@mock_s3
@mock_bedrock
def test_full_prompt_processing():
    """Test end-to-end prompt processing."""
    # Setup mocked AWS services
    s3 = boto3.client('s3', region_name='us-east-1')
    s3.create_bucket(Bucket='test-bucket')

    # Your test code here
```

### Test Coverage Requirements

- **Minimum**: 80% coverage
- **Target**: 90% coverage
- **Critical paths**: 100% coverage

## Submitting Changes

### Before Submitting

1. **Update documentation** - README, docstrings, comments
2. **Add tests** - Unit and integration tests for new code
3. **Run linters** - `black`, `flake8`, `mypy`
4. **Run security scans** - `bandit`, `safety`
5. **Update CHANGELOG.md** - Document your changes
6. **Test locally** - Ensure all tests pass

### Pre-commit Checklist

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Run tests
pytest --cov=scripts

# Security scan
bandit -r scripts/
safety check

# Type checking
mypy scripts/

# Check Terraform
cd terraform
terraform fmt -check
terraform validate
```

### Creating a Pull Request

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create PR on GitHub**:
   - Use descriptive title
   - Fill out PR template completely
   - Link related issues
   - Add screenshots if UI changes

3. **PR Description Template**:
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update
   - [ ] Security fix

   ## Testing
   - [ ] Unit tests added
   - [ ] Integration tests added
   - [ ] Manual testing completed

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Comments added for complex code
   - [ ] Documentation updated
   - [ ] No new warnings generated
   - [ ] Tests pass locally
   - [ ] Security considerations reviewed

   ## Related Issues
   Closes #123

   ## Screenshots (if applicable)
   ```

## Code Review Process

### Review Timeline

- **Initial Response**: Within 24 hours
- **Full Review**: Within 3 business days
- **Follow-up**: Within 1 business day

### Review Criteria

Reviewers will check:
- ✅ Code quality and style
- ✅ Test coverage
- ✅ Security implications
- ✅ Performance impact
- ✅ Documentation completeness
- ✅ Breaking changes documented

### Addressing Feedback

1. **Respond to all comments** - Even if just acknowledging
2. **Push updates** - Commit fixes to your branch
3. **Request re-review** - When ready
4. **Be patient** - Reviews take time

## Style Guide

### Python Code Style

We follow **PEP 8** with some modifications:

```python
# Good: Clear, documented function
def process_prompt(config_path: str) -> Dict[str, Any]:
    """
    Process a prompt configuration file.

    Args:
        config_path: Path to the configuration file

    Returns:
        Dictionary with processing results

    Raises:
        ValueError: If configuration is invalid
    """
    logger.info(f"Processing: {config_path}")
    # Implementation
```

#### Key Points

- **Line Length**: 120 characters max (not 79)
- **Strings**: Use double quotes `"`
- **Docstrings**: Google style
- **Type Hints**: Always use for function signatures
- **Imports**: Sorted with `isort`
- **Formatting**: Auto-formatted with `black`

### Terraform Style

```hcl
# Good: Well-documented resource
resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name

  tags = {
    Name        = "Example Bucket"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

#### Key Points

- **Use `terraform fmt`**: Always format code
- **Comments**: Explain why, not what
- **Variables**: Group related variables
- **Outputs**: Document all outputs
- **Modules**: Use for repeated patterns

### Documentation Style

- **Markdown**: Use for all documentation
- **Headers**: ATX style (`#` not `===`)
- **Line Length**: 120 characters
- **Code Blocks**: Always specify language
- **Links**: Use reference-style for repeated links

## Security

### Security Considerations

When contributing, always consider:

1. **Never commit secrets** - Use environment variables
2. **Validate all inputs** - Never trust user input
3. **Use parameterized queries** - Prevent injection
4. **Follow least privilege** - Minimum required permissions
5. **Encrypt sensitive data** - At rest and in transit

### Security Testing

```bash
# Scan for secrets
gitleaks detect --source . --verbose

# Python security scan
bandit -r scripts/ -ll

# Dependency vulnerabilities
safety check
pip-audit

# Terraform security
tfsec terraform/
checkov -d terraform/
```

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities.

See [SECURITY.md](SECURITY.md) for responsible disclosure procedures.

## Getting Help

### Resources

- **Documentation**: Check README.md and wiki
- **Issues**: Search existing issues first
- **Discussions**: Use GitHub Discussions for questions
- **Slack/Discord**: Join our community channel

### Questions?

- **General Questions**: GitHub Discussions
- **Bug Reports**: GitHub Issues
- **Security Issues**: See SECURITY.md
- **Feature Requests**: GitHub Issues with `enhancement` label

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing! 🎉
