#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}AWS Lambda Cost Experiment - Cleanup${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Load config if available
if [ -f .config/function-urls.env ]; then
    source .config/function-urls.env
    REGION=${REGION:-us-east-1}
else
    REGION=${AWS_REGION:-us-east-1}
fi

echo "This will:"
echo "  1. Disable provisioned concurrency (stops ongoing charges)"
echo "  2. Delete both Lambda functions"
echo "  3. Delete CloudFormation stacks"
echo "  4. Delete CloudWatch log groups"
echo ""
echo -e "${RED}⚠️  This cannot be undone!${NC}"
echo ""
read -p "Continue with cleanup? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1: Disabling provisioned concurrency...${NC}"

# Try to delete provisioned concurrency config
PROVISIONED_FUNCTION="cost-files-test-lambda-cost-provisioned"
if aws lambda get-function --function-name "$PROVISIONED_FUNCTION" --region "$REGION" &>/dev/null; then
    echo "Removing provisioned concurrency from $PROVISIONED_FUNCTION..."
    aws lambda delete-provisioned-concurrency-config \
        --function-name "$PROVISIONED_FUNCTION" \
        --qualifier live \
        --region "$REGION" 2>/dev/null || echo "  (No provisioned concurrency to remove)"
    echo -e "${GREEN}✓ Provisioned concurrency disabled${NC}"
else
    echo "  Function not found (may already be deleted)"
fi

echo ""
echo -e "${YELLOW}Step 2: Deleting CloudFormation stacks...${NC}"

# Delete on-demand stack
if aws cloudformation describe-stacks --stack-name lambda-cost-ondemand --region "$REGION" &>/dev/null; then
    echo "Deleting lambda-cost-ondemand stack..."
    aws cloudformation delete-stack \
        --stack-name lambda-cost-ondemand \
        --region "$REGION"
    echo "  Waiting for stack deletion..."
    aws cloudformation wait stack-delete-complete \
        --stack-name lambda-cost-ondemand \
        --region "$REGION" 2>/dev/null || echo "  (Stack deletion in progress)"
    echo -e "${GREEN}✓ On-demand stack deleted${NC}"
else
    echo "  On-demand stack not found"
fi

# Delete provisioned stack
if aws cloudformation describe-stacks --stack-name lambda-cost-provisioned --region "$REGION" &>/dev/null; then
    echo "Deleting lambda-cost-provisioned stack..."
    aws cloudformation delete-stack \
        --stack-name lambda-cost-provisioned \
        --region "$REGION"
    echo "  Waiting for stack deletion..."
    aws cloudformation wait stack-delete-complete \
        --stack-name lambda-cost-provisioned \
        --region "$REGION" 2>/dev/null || echo "  (Stack deletion in progress)"
    echo -e "${GREEN}✓ Provisioned stack deleted${NC}"
else
    echo "  Provisioned stack not found"
fi

echo ""
echo -e "${YELLOW}Step 3: Deleting CloudWatch log groups...${NC}"

# Delete log groups
for function in "cost-files-test-lambda-cost-ondemand" "cost-files-test-lambda-cost-provisioned"; do
    LOG_GROUP="/aws/lambda/$function"
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" 2>/dev/null | grep -q "$LOG_GROUP"; then
        echo "Deleting log group: $LOG_GROUP"
        aws logs delete-log-group \
            --log-group-name "$LOG_GROUP" \
            --region "$REGION" 2>/dev/null || echo "  (Could not delete log group)"
        echo -e "${GREEN}✓ Log group deleted${NC}"
    else
        echo "  Log group $LOG_GROUP not found"
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All AWS resources have been removed."
echo "Provisioned concurrency charges have stopped."
echo ""
echo -e "${YELLOW}Local files preserved:${NC}"
echo "  - results/ (your test data)"
echo "  - analysis/ (your analysis)"
echo ""
echo "To remove local files:"
echo "  rm -rf results/ analysis/ .config/"
echo ""
