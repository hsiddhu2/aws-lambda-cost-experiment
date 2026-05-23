#!/bin/bash

# AWS Lambda Load Testing Script
# Usage: ./load-test.sh <function_url> <total_invocations> <delay_between_ms> <test_name>

set -e

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <function_url> <total_invocations> <delay_between_ms> [test_name]"
    echo ""
    echo "Examples:"
    echo "  Low traffic:    $0 https://xxx.lambda-url.us-east-1.on.aws/ 100 36000 low-ondemand"
    echo "  Steady traffic: $0 https://xxx.lambda-url.us-east-1.on.aws/ 3000 600 steady-ondemand"
    echo "  Bursty traffic: $0 https://xxx.lambda-url.us-east-1.on.aws/ 500 60 burst-ondemand"
    exit 1
fi

URL=$1
COUNT=$2
DELAY_MS=$3
TEST_NAME=${4:-"test-$(date +%s)"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Lambda Load Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Test name: $TEST_NAME"
echo "URL: $URL"
echo "Invocations: $COUNT"
echo "Delay: ${DELAY_MS}ms"
echo "Start time: $(date +%H:%M:%S)"
echo ""

# Create results directory
mkdir -p results
RESULT_FILE="results/${TEST_NAME}-$(date +%Y%m%d-%H%M%S).csv"

# Write CSV header
echo "invocation,timestamp_ms,http_code,duration_sec,cold_start,function_duration_ms,response_body" > "$RESULT_FILE"

# Progress tracking
COLD_STARTS=0
TOTAL_DURATION=0
SUCCESS_COUNT=0
ERROR_COUNT=0

for i in $(seq 1 $COUNT); do
    START_TIME=$(date +%s%3N)
    
    # Make the request and capture response with timing
    RESPONSE=$(curl -s -w "\n%{http_code}|%{time_total}" "$URL" 2>/dev/null || echo "ERROR|0")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1 | cut -d'|' -f1)
    DURATION=$(echo "$RESPONSE" | tail -n 1 | cut -d'|' -f2)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    # Parse response body for cold start info
    COLD_START="unknown"
    FUNCTION_DURATION="0"
    if [ "$HTTP_CODE" = "200" ]; then
        COLD_START=$(echo "$BODY" | grep -o '"cold_start":[^,}]*' | cut -d':' -f2 || echo "unknown")
        FUNCTION_DURATION=$(echo "$BODY" | grep -o '"duration_ms":[0-9]*' | cut -d':' -f2 || echo "0")
        
        if [ "$COLD_START" = "true" ]; then
            COLD_STARTS=$((COLD_STARTS + 1))
        fi
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
    
    # Escape body for CSV (replace quotes and newlines)
    BODY_ESCAPED=$(echo "$BODY" | tr '\n' ' ' | sed 's/"/""/g')
    
    # Write to CSV
    echo "$i,$START_TIME,$HTTP_CODE,$DURATION,$COLD_START,$FUNCTION_DURATION,\"$BODY_ESCAPED\"" >> "$RESULT_FILE"
    
    # Progress indicator
    if [ $((i % 10)) -eq 0 ]; then
        PERCENT=$((i * 100 / COUNT))
        echo -e "${YELLOW}Progress: $i / $COUNT ($PERCENT%) - Cold starts: $COLD_STARTS - Errors: $ERROR_COUNT${NC}"
    fi
    
    # Delay before next request
    if [ "$DELAY_MS" -gt 0 ] && [ "$i" -lt "$COUNT" ]; then
        sleep $(echo "scale=3; $DELAY_MS/1000" | bc)
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo "End time: $(date +%H:%M:%S)"
echo "Results saved to: $RESULT_FILE"
echo ""
echo "Summary:"
echo "  Total invocations: $COUNT"
echo "  Successful: $SUCCESS_COUNT"
echo "  Errors: $ERROR_COUNT"
echo "  Cold starts detected: $COLD_STARTS"
echo ""
