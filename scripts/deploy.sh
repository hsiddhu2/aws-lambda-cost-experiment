#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Lambda Cost Experiment - Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v sam &> /dev/null; then
    echo -e "${RED}Error: AWS SAM CLI is not installed${NC}"
    echo "Install from: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-1}

echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ Region: ${REGION}${NC}"
echo ""

# Navigate to infrastructure directory
cd "$(dirname "$0")/../infrastructure"

# Build the SAM application
echo -e "${YELLOW}Building SAM application...${NC}"
sam build

# Deploy on-demand function
echo ""
echo -e "${YELLOW}Deploying on-demand Lambda function...${NC}"
sam deploy --config-env ondemand --no-confirm-changeset

# Deploy provisioned function
echo ""
echo -e "${YELLOW}Deploying provisioned Lambda function...${NC}"
sam deploy --config-env provisioned --no-confirm-changeset

# Get function URLs
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

ONDEMAND_URL=$(aws cloudformation describe-stacks \
    --stack-name lambda-cost-ondemand \
    --query 'Stacks[0].Outputs[?OutputKey==`FunctionUrl`].OutputValue' \
    --output text \
    --region "$REGION")

PROVISIONED_URL=$(aws cloudformation describe-stacks \
    --stack-name lambda-cost-provisioned \
    --query 'Stacks[0].Outputs[?OutputKey==`FunctionUrl`].OutputValue' \
    --output text \
    --region "$REGION")

echo -e "${GREEN}On-Demand Function URL:${NC}"
echo "$ONDEMAND_URL"
echo ""
echo -e "${GREEN}Provisioned Function URL:${NC}"
echo "$PROVISIONED_URL"
echo ""

# Save URLs to file for scripts
cd "$(dirname "$0")/.."
mkdir -p .config
cat > .config/function-urls.env << EOF
ONDEMAND_URL=$ONDEMAND_URL
PROVISIONED_URL=$PROVISIONED_URL
REGION=$REGION
ACCOUNT_ID=$ACCOUNT_ID
EOF

echo -e "${GREEN}Function URLs saved to .config/function-urls.env${NC}"
echo ""

# Wait for provisioned concurrency to be ready
echo -e "${YELLOW}Waiting for provisioned concurrency to be ready...${NC}"
echo "This may take 2-3 minutes..."

FUNCTION_NAME="cost-files-test-lambda-cost-provisioned"
MAX_WAIT=300  # 5 minutes
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(aws lambda get-provisioned-concurrency-config \
        --function-name "$FUNCTION_NAME" \
        --qualifier live \
        --query 'Status' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$STATUS" = "READY" ]; then
        echo -e "${GREEN}✓ Provisioned concurrency is ready!${NC}"
        break
    elif [ "$STATUS" = "NOT_FOUND" ]; then
        echo -e "${YELLOW}Note: Provisioned concurrency not configured (this is expected for on-demand only tests)${NC}"
        break
    fi
    
    echo -n "."
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Ready to run experiments!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Run all experiments: ./scripts/run-all-experiments.sh"
echo "  2. Or run individual scenarios with: ./scripts/load-test.sh"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Provisioned concurrency is now charging ~\$0.0375/hour${NC}"
echo -e "${YELLOW}   Run cleanup.sh when done to stop charges!${NC}"
