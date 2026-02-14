#!/bin/bash
# Cleanup Script for Prompt Deployment Pipeline
# Safely removes all AWS resources created by this project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
PROJECT_NAME="PromptDeploymentPipeline"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Prompt Deployment Pipeline - Cleanup Script  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not configured. Run 'aws configure' first.${NC}"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ AWS Region: ${AWS_REGION}${NC}"
echo ""

# Function to confirm action
confirm() {
    local message=$1
    local default=${2:-n}

    while true; do
        if [ "$default" = "y" ]; then
            read -p "$(echo -e ${YELLOW}${message} [Y/n]: ${NC})" yn
            yn=${yn:-y}
        else
            read -p "$(echo -e ${YELLOW}${message} [y/N]: ${NC})" yn
            yn=${yn:-n}
        fi

        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to safely delete S3 bucket
delete_s3_bucket() {
    local bucket_name=$1

    if aws s3 ls "s3://${bucket_name}" &> /dev/null; then
        echo -e "${BLUE}Found bucket: ${bucket_name}${NC}"

        # Count objects
        local object_count=$(aws s3 ls "s3://${bucket_name}" --recursive | wc -l | tr -d ' ')
        echo "  Objects: ${object_count}"

        if confirm "Delete bucket ${bucket_name} and all its contents?"; then
            echo "  Emptying bucket..."

            # Delete all objects
            aws s3 rm "s3://${bucket_name}" --recursive 2>/dev/null || true

            # Delete all versions if versioning is enabled
            aws s3api list-object-versions \
                --bucket "${bucket_name}" \
                --output json \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
            jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
            xargs -I {} aws s3api delete-object --bucket "${bucket_name}" {} 2>/dev/null || true

            # Delete all delete markers
            aws s3api list-object-versions \
                --bucket "${bucket_name}" \
                --output json \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
            jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
            xargs -I {} aws s3api delete-object --bucket "${bucket_name}" {} 2>/dev/null || true

            # Delete the bucket
            aws s3 rb "s3://${bucket_name}" 2>/dev/null || true

            echo -e "${GREEN}  ✓ Bucket deleted${NC}"
        else
            echo -e "${YELLOW}  ⊘ Skipped${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ Bucket not found: ${bucket_name}${NC}"
    fi
}

# Function to delete KMS key alias
delete_kms_alias() {
    local alias_name=$1

    if aws kms describe-alias --alias-name "${alias_name}" &> /dev/null; then
        echo -e "${BLUE}Found KMS alias: ${alias_name}${NC}"

        if confirm "Delete KMS alias ${alias_name}?"; then
            aws kms delete-alias --alias-name "${alias_name}"
            echo -e "${GREEN}  ✓ Alias deleted${NC}"
            echo -e "${YELLOW}  ⚠ Note: KMS key scheduled for deletion (30-day window)${NC}"
        else
            echo -e "${YELLOW}  ⊘ Skipped${NC}"
        fi
    fi
}

# Function to delete CloudWatch log group
delete_log_group() {
    local log_group=$1

    if aws logs describe-log-groups --log-group-name-prefix "${log_group}" --query 'logGroups[].logGroupName' --output text | grep -q "${log_group}"; then
        echo -e "${BLUE}Found log group: ${log_group}${NC}"

        if confirm "Delete log group ${log_group}?"; then
            aws logs delete-log-group --log-group-name "${log_group}"
            echo -e "${GREEN}  ✓ Log group deleted${NC}"
        else
            echo -e "${YELLOW}  ⊘ Skipped${NC}"
        fi
    fi
}

# Main menu
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Cleanup Options                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo "1) Delete only Beta environment"
echo "2) Delete only Prod environment"
echo "3) Delete ALL resources (complete cleanup)"
echo "4) Empty S3 buckets only (keep infrastructure)"
echo "5) Terraform destroy (keeps S3 data)"
echo "6) Custom cleanup"
echo "0) Exit"
echo ""

read -p "Enter your choice [0-6]: " choice

case $choice in
    0)
        echo "Exiting..."
        exit 0
        ;;

    1)
        echo -e "\n${BLUE}═══ Cleaning up Beta Environment ═══${NC}\n"

        # Get bucket name from tfvars or ask
        BETA_BUCKET=$(grep 'beta_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-beta")

        delete_s3_bucket "${BETA_BUCKET}"
        delete_kms_alias "alias/${PROJECT_NAME}-beta"
        ;;

    2)
        echo -e "\n${BLUE}═══ Cleaning up Prod Environment ═══${NC}\n"

        # Get bucket name from tfvars or ask
        PROD_BUCKET=$(grep 'prod_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-prod")

        delete_s3_bucket "${PROD_BUCKET}"
        delete_kms_alias "alias/${PROJECT_NAME}-prod"
        ;;

    3)
        echo -e "\n${RED}⚠️  WARNING: This will delete ALL resources!${NC}"
        echo -e "${RED}This includes:${NC}"
        echo "  - All S3 buckets and their contents"
        echo "  - KMS keys (30-day deletion window)"
        echo "  - CloudWatch logs and alarms"
        echo "  - SNS topics"
        echo "  - All Terraform-managed resources"
        echo ""

        if confirm "Are you ABSOLUTELY sure you want to delete everything?" "n"; then
            if confirm "Type 'yes' to confirm again" "n"; then
                echo -e "\n${BLUE}═══ Complete Cleanup Started ═══${NC}\n"

                # S3 Buckets
                echo -e "${BLUE}1. Cleaning S3 Buckets${NC}"
                BETA_BUCKET=$(grep 'beta_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-beta")
                PROD_BUCKET=$(grep 'prod_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-prod")

                delete_s3_bucket "${BETA_BUCKET}"
                delete_s3_bucket "${PROD_BUCKET}"
                delete_s3_bucket "${BETA_BUCKET}-access-logs"

                # KMS
                echo -e "\n${BLUE}2. Cleaning KMS Keys${NC}"
                delete_kms_alias "alias/${PROJECT_NAME}-beta"
                delete_kms_alias "alias/${PROJECT_NAME}-prod"

                # CloudWatch
                echo -e "\n${BLUE}3. Cleaning CloudWatch Resources${NC}"
                delete_log_group "/aws/s3/${PROJECT_NAME}"

                # SNS
                echo -e "\n${BLUE}4. Cleaning SNS Topics${NC}"
                SNS_TOPICS=$(aws sns list-topics --query "Topics[?contains(TopicArn, '${PROJECT_NAME}')].TopicArn" --output text)
                if [ -n "$SNS_TOPICS" ]; then
                    for topic in $SNS_TOPICS; do
                        if confirm "Delete SNS topic ${topic}?"; then
                            aws sns delete-topic --topic-arn "$topic"
                            echo -e "${GREEN}  ✓ Topic deleted${NC}"
                        fi
                    done
                fi

                # Terraform destroy
                echo -e "\n${BLUE}5. Running Terraform Destroy${NC}"
                if confirm "Run 'terraform destroy' to remove all infrastructure?"; then
                    cd terraform
                    terraform destroy -auto-approve || echo -e "${YELLOW}⚠ Terraform destroy encountered errors (may be normal if resources already deleted)${NC}"
                    cd ..
                fi

                echo -e "\n${GREEN}═══ Complete Cleanup Finished ═══${NC}\n"
            else
                echo -e "${YELLOW}Cleanup cancelled${NC}"
            fi
        else
            echo -e "${YELLOW}Cleanup cancelled${NC}"
        fi
        ;;

    4)
        echo -e "\n${BLUE}═══ Emptying S3 Buckets (keeping infrastructure) ═══${NC}\n"

        BETA_BUCKET=$(grep 'beta_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-beta")
        PROD_BUCKET=$(grep 'prod_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-prod")

        if aws s3 ls "s3://${BETA_BUCKET}" &> /dev/null; then
            if confirm "Empty beta bucket ${BETA_BUCKET}?"; then
                aws s3 rm "s3://${BETA_BUCKET}" --recursive
                echo -e "${GREEN}  ✓ Beta bucket emptied${NC}"
            fi
        fi

        if aws s3 ls "s3://${PROD_BUCKET}" &> /dev/null; then
            if confirm "Empty prod bucket ${PROD_BUCKET}?"; then
                aws s3 rm "s3://${PROD_BUCKET}" --recursive
                echo -e "${GREEN}  ✓ Prod bucket emptied${NC}"
            fi
        fi
        ;;

    5)
        echo -e "\n${BLUE}═══ Running Terraform Destroy ═══${NC}\n"
        echo "This will destroy all Terraform-managed infrastructure"
        echo "S3 bucket contents will be preserved"
        echo ""

        if confirm "Run terraform destroy?"; then
            cd terraform
            terraform destroy
            cd ..
        else
            echo -e "${YELLOW}Cancelled${NC}"
        fi
        ;;

    6)
        echo -e "\n${BLUE}═══ Custom Cleanup ═══${NC}\n"
        echo "Select resources to clean up:"
        echo ""

        if confirm "Delete beta S3 bucket?"; then
            BETA_BUCKET=$(grep 'beta_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-beta")
            delete_s3_bucket "${BETA_BUCKET}"
        fi

        if confirm "Delete prod S3 bucket?"; then
            PROD_BUCKET=$(grep 'prod_bucket_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "prompt-deploy-pipeline-prod")
            delete_s3_bucket "${PROD_BUCKET}"
        fi

        if confirm "Delete KMS keys?"; then
            delete_kms_alias "alias/${PROJECT_NAME}-beta"
            delete_kms_alias "alias/${PROJECT_NAME}-prod"
        fi

        if confirm "Delete CloudWatch resources?"; then
            delete_log_group "/aws/s3/${PROJECT_NAME}"
        fi
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Cleanup Process Complete           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Note: Some resources may take time to fully delete:${NC}"
echo "  - KMS keys have a 30-day deletion window"
echo "  - CloudWatch alarms may take a few minutes"
echo "  - S3 buckets with many objects may take time"
echo ""
echo -e "${BLUE}To verify cleanup, run:${NC}"
echo "  aws s3 ls | grep prompt"
echo "  aws kms list-aliases | grep ${PROJECT_NAME}"
echo "  aws logs describe-log-groups | grep ${PROJECT_NAME}"
echo ""
