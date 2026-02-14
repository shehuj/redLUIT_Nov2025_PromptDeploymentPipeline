# Makefile for Prompt Deployment Pipeline
# Simplifies common development and deployment tasks

.PHONY: help install install-dev test lint format security clean docs deploy-infra destroy-infra

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Prompt Deployment Pipeline - Make Commands"
	@echo "==========================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Development Commands

install: ## Install production dependencies
	pip install -r requirements.txt

install-dev: install ## Install development dependencies
	pip install -r requirements-dev.txt
	pre-commit install
	@echo "✅ Development environment ready!"

venv: ## Create virtual environment
	python3 -m venv venv
	@echo "✅ Virtual environment created. Activate with: source venv/bin/activate"

## Code Quality Commands

test: ## Run tests with coverage
	pytest tests/ -v --cov=scripts --cov-report=html --cov-report=term

test-unit: ## Run only unit tests
	pytest tests/unit/ -v

test-integration: ## Run only integration tests
	pytest tests/integration/ -v -m integration

test-security: ## Run security-focused tests
	pytest tests/ -v -m security

coverage: ## Generate coverage report
	pytest tests/ --cov=scripts --cov-report=html
	@echo "✅ Coverage report generated in htmlcov/index.html"
	open htmlcov/index.html || xdg-open htmlcov/index.html

lint: ## Run all linters
	@echo "Running Flake8..."
	flake8 scripts/ tests/
	@echo "Running MyPy..."
	mypy scripts/
	@echo "Running Bandit..."
	bandit -r scripts/ -ll
	@echo "✅ All linting passed!"

format: ## Format code with Black and isort
	black scripts/ tests/
	isort scripts/ tests/
	@echo "✅ Code formatted!"

format-check: ## Check code formatting without modifying
	black --check scripts/ tests/
	isort --check scripts/ tests/

security: ## Run security scans
	@echo "Running Bandit security scan..."
	bandit -r scripts/ -ll -f screen
	@echo "Running Safety check..."
	safety check
	@echo "Running pip-audit..."
	pip-audit
	@echo "Scanning for secrets..."
	gitleaks detect --source . --verbose || true
	@echo "✅ Security scans complete!"

pre-commit: ## Run all pre-commit hooks
	pre-commit run --all-files

clean: ## Clean up generated files
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -delete
	find . -type d -name '*.egg-info' -exec rm -rf {} + || true
	find . -type d -name '.pytest_cache' -exec rm -rf {} + || true
	find . -type d -name '.mypy_cache' -exec rm -rf {} + || true
	rm -rf build/ dist/ htmlcov/ .coverage
	@echo "✅ Cleanup complete!"

## Terraform Commands

tf-init: ## Initialize Terraform
	cd terraform && terraform init

tf-fmt: ## Format Terraform files
	cd terraform && terraform fmt -recursive

tf-validate: ## Validate Terraform configuration
	cd terraform && terraform fmt -check -recursive
	cd terraform && terraform validate

tf-plan: ## Create Terraform plan
	cd terraform && terraform plan -out=tfplan

tf-apply: ## Apply Terraform changes
	cd terraform && terraform apply tfplan

tf-destroy: ## Destroy Terraform infrastructure
	cd terraform && terraform destroy

tf-security: ## Run Terraform security scans
	tfsec terraform/
	checkov -d terraform/

deploy-infra: tf-init tf-validate tf-plan ## Deploy infrastructure (plan only - manual apply required)
	@echo "⚠️  Review the plan above. To apply, run: make tf-apply"

## AWS Commands

aws-test: ## Test AWS credentials
	aws sts get-caller-identity
	@echo "✅ AWS credentials are valid!"

s3-list-beta: ## List beta S3 bucket contents
	aws s3 ls s3://$(S3_BUCKET_BETA)/ --recursive --human-readable

s3-list-prod: ## List production S3 bucket contents
	aws s3 ls s3://$(S3_BUCKET_PROD)/ --recursive --human-readable

bedrock-models: ## List available Bedrock models
	aws bedrock list-foundation-models --region $(AWS_REGION) --query 'modelSummaries[].modelId'

## Local Testing Commands

test-prompt: ## Test prompt processing locally (requires PROMPT_FILE variable)
	@if [ -z "$(PROMPT_FILE)" ]; then \
		echo "❌ Error: PROMPT_FILE not set. Usage: make test-prompt PROMPT_FILE=prompts/welcome_prompt.json"; \
		exit 1; \
	fi
	python scripts/process_prompt.py $(PROMPT_FILE) \
		--region $(AWS_REGION) \
		--bucket $(S3_BUCKET) \
		--prefix test/

validate-config: ## Validate prompt configuration file (requires CONFIG_FILE variable)
	@if [ -z "$(CONFIG_FILE)" ]; then \
		echo "❌ Error: CONFIG_FILE not set. Usage: make validate-config CONFIG_FILE=prompts/test.json"; \
		exit 1; \
	fi
	python -c "import json; import jsonschema; \
		config = json.load(open('$(CONFIG_FILE)')); \
		schema = json.load(open('scripts/config_schema.json')); \
		jsonschema.validate(config, schema); \
		print('✅ Configuration valid!')"

## Documentation Commands

docs: ## Generate documentation
	@echo "Generating documentation..."
	@echo "📚 Available documentation:"
	@echo "  - README.md"
	@echo "  - SECURITY.md"
	@echo "  - CONTRIBUTING.md"
	@echo "  - SETUP_GUIDE.md"
	@echo "  - IMPROVEMENTS_SUMMARY.md"

docs-serve: ## Serve documentation locally (requires Python http.server)
	python -m http.server 8000 --directory .

## CI/CD Simulation

ci-test: install-dev lint security test ## Run full CI test suite locally
	@echo "✅ All CI checks passed!"

ci-validate: format-check lint tf-validate ## Validate code without modifying
	@echo "✅ Validation complete!"

## Utility Commands

version: ## Show versions of key tools
	@echo "Python: $$(python --version)"
	@echo "Pip: $$(pip --version)"
	@echo "Terraform: $$(terraform version -json | python -c 'import sys, json; print(json.load(sys.stdin)["terraform_version"])')"
	@echo "AWS CLI: $$(aws --version)"
	@echo "Pytest: $$(pytest --version)"

env-check: ## Check required environment variables
	@echo "Checking environment variables..."
	@echo "AWS_REGION: ${AWS_REGION:-not set}"
	@echo "AWS_ACCESS_KEY_ID: $${AWS_ACCESS_KEY_ID:+set}"
	@echo "AWS_SECRET_ACCESS_KEY: $${AWS_SECRET_ACCESS_KEY:+set}"
	@echo "S3_BUCKET_BETA: ${S3_BUCKET_BETA:-not set}"
	@echo "S3_BUCKET_PROD: ${S3_BUCKET_PROD:-not set}"

setup-hooks: ## Setup git hooks
	pre-commit install
	pre-commit install --hook-type commit-msg
	@echo "✅ Git hooks installed!"

## Release Commands

tag: ## Create a git tag (requires TAG variable)
	@if [ -z "$(TAG)" ]; then \
		echo "❌ Error: TAG not set. Usage: make tag TAG=v2.0.0"; \
		exit 1; \
	fi
	git tag -a $(TAG) -m "Release $(TAG)"
	@echo "✅ Tag $(TAG) created. Push with: git push origin $(TAG)"

changelog: ## Update CHANGELOG.md (manual edit required)
	@echo "📝 Update CHANGELOG.md with your changes"
	@echo "Follow format: https://keepachangelog.com/"

## Quick Start Commands

quickstart: venv install-dev setup-hooks ## Complete development setup
	@echo ""
	@echo "🎉 Quick start complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Activate virtual environment: source venv/bin/activate"
	@echo "  2. Configure AWS: aws configure"
	@echo "  3. Set environment variables in .env"
	@echo "  4. Initialize Terraform: make tf-init"
	@echo "  5. Run tests: make test"
	@echo ""

## Variables (can be overridden)
AWS_REGION ?= us-east-1
S3_BUCKET_BETA ?= prompt-deployment-pipeline-beta
S3_BUCKET_PROD ?= prompt-deployment-pipeline-prod
S3_BUCKET ?= $(S3_BUCKET_BETA)
PYTHON ?= python3
