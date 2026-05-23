#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CloudWatch Metrics Analysis${NC}"
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

# Function names
ONDEMAND_FUNCTION="cost-files-test-lambda-cost-ondemand"
PROVISIONED_FUNCTION="cost-files-test-lambda-cost-provisioned"

# Get experiment time range from log
if [ -f results/experiment-log.txt ]; then
    START_TIME=$(grep "Experiment started" results/experiment-log.txt | head -1 | sed 's/Experiment started at: //')
    END_TIME=$(grep "Experiment ended" results/experiment-log.txt | head -1 | sed 's/Experiment ended at: //')
    
    if [ -n "$START_TIME" ]; then
        echo "Experiment time range:"
        echo "  Start: $START_TIME"
        echo "  End: $END_TIME"
        echo ""
    fi
fi

echo -e "${YELLOW}Querying CloudWatch Logs Insights...${NC}"
echo "This may take a minute..."
echo ""

# Function to run CloudWatch Insights query
run_query() {
    local FUNCTION_NAME=$1
    local OUTPUT_FILE=$2
    local LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
    
    echo "Analyzing $FUNCTION_NAME..."
    
    # Check if log group exists
    if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" | grep -q "$LOG_GROUP"; then
        echo "  Warning: Log group $LOG_GROUP not found"
        return
    fi
    
    # Query for the last 7 days (adjust if needed)
    START_TIMESTAMP=$(($(date +%s) - 604800))
    END_TIMESTAMP=$(date +%s)
    
    # Start the query
    QUERY_ID=$(aws logs start-query \
        --log-group-name "$LOG_GROUP" \
        --start-time "$START_TIMESTAMP" \
        --end-time "$END_TIMESTAMP" \
        --query-string 'fields @timestamp, @duration, @initDuration, @billedDuration, @memorySize, @maxMemoryUsed
| filter @type = "REPORT"
| stats 
    count() as invocations,
    sum(@initDuration > 0) as cold_starts,
    avg(@duration) as avg_duration_ms,
    pct(@duration, 50) as p50_duration_ms,
    pct(@duration, 95) as p95_duration_ms,
    pct(@duration, 99) as p99_duration_ms,
    max(@duration) as max_duration_ms,
    sum(@billedDuration)/1000 as total_billed_seconds,
    avg(@maxMemoryUsed) as avg_memory_used_mb' \
        --region "$REGION" \
        --query 'queryId' \
        --output text)
    
    # Wait for query to complete
    STATUS="Running"
    while [ "$STATUS" = "Running" ] || [ "$STATUS" = "Scheduled" ]; do
        sleep 2
        STATUS=$(aws logs get-query-results \
            --query-id "$QUERY_ID" \
            --region "$REGION" \
            --query 'status' \
            --output text)
    done
    
    # Get results
    aws logs get-query-results \
        --query-id "$QUERY_ID" \
        --region "$REGION" \
        --output json > "$OUTPUT_FILE"
    
    echo "  ✓ Results saved to $OUTPUT_FILE"
}

# Run queries for both functions
run_query "$ONDEMAND_FUNCTION" "analysis/cloudwatch-ondemand.json"
run_query "$PROVISIONED_FUNCTION" "analysis/cloudwatch-provisioned.json"

echo ""
echo -e "${GREEN}CloudWatch analysis complete!${NC}"
echo ""

# Parse and display summary
echo -e "${BLUE}Summary:${NC}"
echo ""

for config in ondemand provisioned; do
    FILE="analysis/cloudwatch-${config}.json"
    if [ -f "$FILE" ]; then
        echo -e "${YELLOW}${config^} Configuration:${NC}"
        
        # Extract metrics using jq if available, otherwise show file location
        if command -v jq &> /dev/null; then
            INVOCATIONS=$(jq -r '.results[0][] | select(.field=="invocations") | .value' "$FILE" 2>/dev/null || echo "N/A")
            COLD_STARTS=$(jq -r '.results[0][] | select(.field=="cold_starts") | .value' "$FILE" 2>/dev/null || echo "N/A")
            P99=$(jq -r '.results[0][] | select(.field=="p99_duration_ms") | .value' "$FILE" 2>/dev/null || echo "N/A")
            BILLED_SEC=$(jq -r '.results[0][] | select(.field=="total_billed_seconds") | .value' "$FILE" 2>/dev/null || echo "N/A")
            
            echo "  Invocations: $INVOCATIONS"
            echo "  Cold starts: $COLD_STARTS"
            echo "  P99 latency: ${P99} ms"
            echo "  Total billed seconds: $BILLED_SEC"
        else
            echo "  (Install jq for formatted output)"
            echo "  Raw data: $FILE"
        fi
        echo ""
    fi
done

echo "Next step: Wait 24-48 hours, then run ./scripts/analyze-costs.sh"
