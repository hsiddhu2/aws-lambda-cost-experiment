#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Cost Explorer Analysis${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Load config
if [ ! -f .config/function-urls.env ]; then
    echo "Error: Configuration not found. Run ./scripts/deploy.sh first"
    exit 1
fi

source .config/function-urls.env

# Create analysis directory
mkdir -p analysis

# Get experiment date range
if [ -f results/experiment-log.txt ]; then
    EXPERIMENT_DATE=$(grep "Experiment started" results/experiment-log.txt | head -1 | awk '{print $4}')
    if [ -n "$EXPERIMENT_DATE" ]; then
        # Parse date and create range
        START_DATE=$(date -j -f "%Y-%m-%d" "$EXPERIMENT_DATE" "+%Y-%m-%d" 2>/dev/null || echo "$EXPERIMENT_DATE")
        END_DATE=$(date -j -v+2d -f "%Y-%m-%d" "$START_DATE" "+%Y-%m-%d" 2>/dev/null || date -d "$START_DATE + 2 days" "+%Y-%m-%d" 2>/dev/null || echo "$START_DATE")
    fi
fi

# Default to last 7 days if we can't determine experiment date
if [ -z "$START_DATE" ]; then
    START_DATE=$(date -v-7d "+%Y-%m-%d" 2>/dev/null || date -d "7 days ago" "+%Y-%m-%d")
    END_DATE=$(date "+%Y-%m-%d")
    echo -e "${YELLOW}Note: Using last 7 days for cost analysis${NC}"
fi

echo "Date range: $START_DATE to $END_DATE"
echo ""

echo -e "${YELLOW}Fetching cost data from AWS Cost Explorer...${NC}"
echo "This may take a moment..."
echo ""

# Get overall Lambda costs for the project
echo "Querying costs by Project tag..."
aws ce get-cost-and-usage \
    --time-period Start="$START_DATE",End="$END_DATE" \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --filter file://<(cat <<EOF
{
    "And": [
        {
            "Dimensions": {
                "Key": "SERVICE",
                "Values": ["AWS Lambda"]
            }
        },
        {
            "Tags": {
                "Key": "Project",
                "Values": ["cost-files-01"]
            }
        }
    ]
}
EOF
) \
    --group-by Type=TAG,Key=Function \
    --region "$REGION" \
    --output json > analysis/costs-by-function.json

echo "✓ Cost data saved to analysis/costs-by-function.json"
echo ""

# Get detailed cost breakdown
echo "Querying detailed cost breakdown..."
aws ce get-cost-and-usage \
    --time-period Start="$START_DATE",End="$END_DATE" \
    --granularity DAILY \
    --metrics "UnblendedCost" "UsageQuantity" \
    --filter file://<(cat <<EOF
{
    "And": [
        {
            "Dimensions": {
                "Key": "SERVICE",
                "Values": ["AWS Lambda"]
            }
        },
        {
            "Tags": {
                "Key": "Project",
                "Values": ["cost-files-01"]
            }
        }
    ]
}
EOF
) \
    --group-by Type=DIMENSION,Key=USAGE_TYPE \
    --region "$REGION" \
    --output json > analysis/costs-detailed.json

echo "✓ Detailed costs saved to analysis/costs-detailed.json"
echo ""

# Display summary
echo -e "${BLUE}Cost Summary:${NC}"
echo ""

if command -v jq &> /dev/null; then
    # Parse and display costs by function
    echo -e "${YELLOW}Costs by Function:${NC}"
    
    jq -r '.ResultsByTime[] | 
        .TimePeriod.Start as $date | 
        .Groups[] | 
        "\($date) - \(.Keys[0]): $\(.Metrics.UnblendedCost.Amount)"' \
        analysis/costs-by-function.json 2>/dev/null || echo "No cost data found yet"
    
    echo ""
    
    # Calculate totals
    ONDEMAND_TOTAL=$(jq -r '[.ResultsByTime[].Groups[] | select(.Keys[0] == "ondemand") | .Metrics.UnblendedCost.Amount | tonumber] | add // 0' analysis/costs-by-function.json)
    PROVISIONED_TOTAL=$(jq -r '[.ResultsByTime[].Groups[] | select(.Keys[0] == "provisioned") | .Metrics.UnblendedCost.Amount | tonumber] | add // 0' analysis/costs-by-function.json)
    
    echo -e "${GREEN}Total Costs:${NC}"
    printf "  On-Demand:   \$%.4f\n" "$ONDEMAND_TOTAL"
    printf "  Provisioned: \$%.4f\n" "$PROVISIONED_TOTAL"
    echo ""
    
    # Show usage type breakdown
    echo -e "${YELLOW}Cost Breakdown by Usage Type:${NC}"
    jq -r '.ResultsByTime[].Groups[] | 
        "\(.Keys[0]): $\(.Metrics.UnblendedCost.Amount) (\(.Metrics.UsageQuantity.Amount) \(.Metrics.UsageQuantity.Unit // "units"))"' \
        analysis/costs-detailed.json 2>/dev/null | head -20
    
else
    echo -e "${YELLOW}Install jq for formatted cost display${NC}"
    echo "Raw data available in:"
    echo "  - analysis/costs-by-function.json"
    echo "  - analysis/costs-detailed.json"
fi

echo ""
echo -e "${GREEN}Cost analysis complete!${NC}"
echo ""

# Check if costs are available
TOTAL_COST=$(jq -r '[.ResultsByTime[].Groups[].Metrics.UnblendedCost.Amount | tonumber] | add // 0' analysis/costs-by-function.json 2>/dev/null || echo "0")

if [ "$TOTAL_COST" = "0" ] || [ "$TOTAL_COST" = "0.0" ]; then
    echo -e "${YELLOW}⚠️  No cost data found yet${NC}"
    echo "Cost Explorer data can take 24-48 hours to populate."
    echo "Try running this script again tomorrow."
    echo ""
fi

echo "Next step: ./scripts/generate-report.sh"
