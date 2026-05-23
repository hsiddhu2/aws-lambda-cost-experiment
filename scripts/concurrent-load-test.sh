#!/bin/bash

# AWS Lambda Concurrent Load Testing Script
# Usage: ./concurrent-load-test.sh <function_url> <concurrent_requests> <rounds> <delay_between_rounds_sec> <test_name>

set -e

if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <function_url> <concurrent_requests> <rounds> <delay_between_rounds_sec> [test_name]"
    echo ""
    echo "Examples:"
    echo "  Moderate:  $0 https://xxx.lambda-url.us-east-1.on.aws/ 100 10 30 moderate-ondemand"
    echo "  High:      $0 https://xxx.lambda-url.us-east-1.on.aws/ 500 3 300 high-ondemand"
    echo "  Burst:     $0 https://xxx.lambda-url.us-east-1.on.aws/ 20 5 10 burst-ondemand"
    exit 1
fi

URL=$1
CONCURRENT=$2
ROUNDS=$3
DELAY_SEC=$4
TEST_NAME=${5:-"concurrent-test-$(date +%s)"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Lambda Concurrent Load Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Test name: $TEST_NAME"
echo "URL: $URL"
echo "Concurrent requests: $CONCURRENT"
echo "Rounds: $ROUNDS"
echo "Delay between rounds: ${DELAY_SEC}s"
echo "Start time: $(date +%H:%M:%S)"
echo ""

# Create results directory
mkdir -p results
RESULT_FILE="results/${TEST_NAME}-$(date +%Y%m%d-%H%M%S).csv"

# Write CSV header
echo "round,invocation,timestamp_ms,http_code,duration_sec,cold_start,function_duration_ms,response_body" > "$RESULT_FILE"

# Progress tracking
TOTAL_COLD_STARTS=0
TOTAL_SUCCESS=0
TOTAL_ERRORS=0
TOTAL_REQUESTS=$((CONCURRENT * ROUNDS))

for round in $(seq 1 $ROUNDS); do
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Round $round of $ROUNDS${NC}"
    echo -e "${BLUE}Launching $CONCURRENT concurrent requests...${NC}"
    echo ""
    
    ROUND_START=$(date +%s)
    ROUND_COLD_STARTS=0
    ROUND_SUCCESS=0
    ROUND_ERRORS=0
    
    # Launch concurrent requests
    for i in $(seq 1 $CONCURRENT); do
        (
            START_TIME=$(date +%s%3N)
            
            # Make the request and capture response with timing
            RESPONSE=$(curl -s -w "\n%{http_code}|%{time_total}" "$URL" 2>/dev/null || echo "ERROR|0")
            
            # Extract last line (status and timing)
            LAST_LINE=$(echo "$RESPONSE" | tail -n 1)
            HTTP_CODE=$(echo "$LAST_LINE" | cut -d'|' -f1)
            DURATION=$(echo "$LAST_LINE" | cut -d'|' -f2)
            
            # Extract body (all lines except last)
            BODY=$(echo "$RESPONSE" | sed '$d')
            
            # Parse response body for cold start info
            COLD_START="unknown"
            FUNCTION_DURATION="0"
            if [ "$HTTP_CODE" = "200" ]; then
                COLD_START=$(echo "$BODY" | grep -o '"cold_start":[^,}]*' | cut -d':' -f2 || echo "unknown")
                FUNCTION_DURATION=$(echo "$BODY" | grep -o '"duration_ms":[0-9]*' | cut -d':' -f2 || echo "0")
            fi
            
            # Escape body for CSV
            BODY_ESCAPED=$(echo "$BODY" | tr '\n' ' ' | sed 's/"/""/g')
            
            # Write to CSV (with file locking to prevent corruption)
            (
                flock -x 200
                echo "$round,$i,$START_TIME,$HTTP_CODE,$DURATION,$COLD_START,$FUNCTION_DURATION,\"$BODY_ESCAPED\"" >> "$RESULT_FILE"
            ) 200>/tmp/concurrent-load-test.lock
            
        ) &
    done
    
    # Wait for all concurrent requests to complete
    wait
    
    ROUND_END=$(date +%s)
    ROUND_DURATION=$((ROUND_END - ROUND_START))
    
    # Count results for this round
    ROUND_LINES=$(grep "^$round," "$RESULT_FILE" | wc -l | tr -d ' ')
    ROUND_COLD_STARTS=$(grep "^$round," "$RESULT_FILE" | grep -c "true" || echo "0")
    ROUND_SUCCESS=$(grep "^$round," "$RESULT_FILE" | grep -c ",200," || echo "0")
    ROUND_ERRORS=$((ROUND_LINES - ROUND_SUCCESS))
    
    TOTAL_COLD_STARTS=$((TOTAL_COLD_STARTS + ROUND_COLD_STARTS))
    TOTAL_SUCCESS=$((TOTAL_SUCCESS + ROUND_SUCCESS))
    TOTAL_ERRORS=$((TOTAL_ERRORS + ROUND_ERRORS))
    
    echo -e "${YELLOW}Round $round complete in ${ROUND_DURATION}s${NC}"
    echo "  Requests: $ROUND_LINES"
    echo "  Success: $ROUND_SUCCESS"
    echo "  Errors: $ROUND_ERRORS"
    echo "  Cold starts: $ROUND_COLD_STARTS"
    echo ""
    
    # Delay before next round (except after last round)
    if [ $round -lt $ROUNDS ]; then
        echo -e "${YELLOW}Waiting ${DELAY_SEC}s before next round...${NC}"
        sleep $DELAY_SEC
        echo ""
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
echo "  Total requests: $TOTAL_REQUESTS"
echo "  Successful: $TOTAL_SUCCESS"
echo "  Errors: $TOTAL_ERRORS"
echo "  Cold starts detected: $TOTAL_COLD_STARTS"
echo "  Cold start rate: $(echo "scale=2; $TOTAL_COLD_STARTS * 100 / $TOTAL_REQUESTS" | bc)%"
echo ""
