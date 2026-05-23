#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Lambda Concurrent Load Experiment${NC}"
echo -e "${GREEN}Testing TRUE Concurrency${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Load function URLs
if [ ! -f .config/function-urls.env ]; then
    echo -e "${RED}Error: Function URLs not found. Run ./scripts/deploy.sh first${NC}"
    exit 1
fi

source .config/function-urls.env

echo "On-Demand URL: $ONDEMAND_URL"
echo "Provisioned URL: $PROVISIONED_URL"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if running non-interactively
if [ -t 0 ]; then
    # Interactive mode - confirm before starting
    echo -e "${YELLOW}This will run 3 concurrent test scenarios:${NC}"
    echo "  1. Moderate: 100 concurrent × 10 rounds (30s between) = ~5 min"
    echo "  2. High: 500 concurrent × 3 rounds (5min between) = ~15 min"
    echo "  3. Burst: 20 concurrent × 5 rounds (10s between) = ~1 min"
    echo ""
    echo -e "${YELLOW}Total time: ~25 minutes${NC}"
    echo ""
    echo -e "${YELLOW}This will trigger REAL cold starts and show the difference!${NC}"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
else
    # Non-interactive mode - just start
    echo -e "${YELLOW}Running in non-interactive mode. Starting experiments...${NC}"
    echo ""
fi

# Create results directory
mkdir -p results

# Track start time
EXPERIMENT_START=$(date +%s)
echo "Concurrent experiment started at: $(date)" | tee results/concurrent-experiment-log.txt
echo "" | tee -a results/concurrent-experiment-log.txt

# ============================================
# Scenario 1: Moderate Concurrency
# 100 concurrent requests, 10 rounds, 30s between
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Scenario 1: Moderate Concurrency${NC}"
echo -e "${BLUE}100 concurrent requests × 10 rounds${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Starting moderate concurrency tests (running in parallel)..."
echo "This will take approximately 5 minutes..."
echo ""

"$SCRIPT_DIR/concurrent-load-test.sh" "$ONDEMAND_URL" 100 10 30 "moderate-ondemand" &
PID_MOD_ONDEMAND=$!

"$SCRIPT_DIR/concurrent-load-test.sh" "$PROVISIONED_URL" 100 10 30 "moderate-provisioned" &
PID_MOD_PROVISIONED=$!

# Wait for both to complete
wait $PID_MOD_ONDEMAND
wait $PID_MOD_PROVISIONED

echo "Moderate concurrency scenario complete!" | tee -a results/concurrent-experiment-log.txt
echo "" | tee -a results/concurrent-experiment-log.txt

# ============================================
# Scenario 2: High Concurrency
# 500 concurrent requests, 3 rounds, 5min between
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Scenario 2: High Concurrency${NC}"
echo -e "${BLUE}500 concurrent requests × 3 rounds${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Starting high concurrency tests (running in parallel)..."
echo "This will take approximately 15 minutes..."
echo ""

"$SCRIPT_DIR/concurrent-load-test.sh" "$ONDEMAND_URL" 500 3 300 "high-ondemand" &
PID_HIGH_ONDEMAND=$!

"$SCRIPT_DIR/concurrent-load-test.sh" "$PROVISIONED_URL" 500 3 300 "high-provisioned" &
PID_HIGH_PROVISIONED=$!

# Wait for both to complete
wait $PID_HIGH_ONDEMAND
wait $PID_HIGH_PROVISIONED

echo "High concurrency scenario complete!" | tee -a results/concurrent-experiment-log.txt
echo "" | tee -a results/concurrent-experiment-log.txt

# ============================================
# Scenario 3: Burst Concurrency
# 20 concurrent requests, 5 rounds, 10s between
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Scenario 3: Burst Concurrency${NC}"
echo -e "${BLUE}20 concurrent requests × 5 rounds${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Starting burst concurrency tests (running in parallel)..."
echo "This will take approximately 1 minute..."
echo ""

"$SCRIPT_DIR/concurrent-load-test.sh" "$ONDEMAND_URL" 20 5 10 "burst-ondemand" &
PID_BURST_ONDEMAND=$!

"$SCRIPT_DIR/concurrent-load-test.sh" "$PROVISIONED_URL" 20 5 10 "burst-provisioned" &
PID_BURST_PROVISIONED=$!

# Wait for both to complete
wait $PID_BURST_ONDEMAND
wait $PID_BURST_PROVISIONED

echo "Burst concurrency scenario complete!" | tee -a results/concurrent-experiment-log.txt
echo "" | tee -a results/concurrent-experiment-log.txt

# ============================================
# Experiment Complete
# ============================================
EXPERIMENT_END=$(date +%s)
DURATION=$((EXPERIMENT_END - EXPERIMENT_START))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Concurrent Experiments Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Experiment ended at: $(date)" | tee -a results/concurrent-experiment-log.txt
echo "Total duration: ${MINUTES}m ${SECONDS}s" | tee -a results/concurrent-experiment-log.txt
echo ""
echo "Results saved to: results/"
echo ""

# Analyze cold starts
echo -e "${BLUE}Cold Start Analysis:${NC}"
echo ""

for scenario in moderate high burst; do
    echo -e "${YELLOW}${scenario^} Concurrency:${NC}"
    
    ONDEMAND_FILE=$(ls -t results/${scenario}-ondemand-*.csv 2>/dev/null | head -1)
    PROVISIONED_FILE=$(ls -t results/${scenario}-provisioned-*.csv 2>/dev/null | head -1)
    
    if [ -f "$ONDEMAND_FILE" ]; then
        OD_TOTAL=$(tail -n +2 "$ONDEMAND_FILE" | wc -l | tr -d ' ')
        OD_COLD=$(grep -c "true" "$ONDEMAND_FILE" || echo "0")
        OD_RATE=$(echo "scale=1; $OD_COLD * 100 / $OD_TOTAL" | bc)
        echo "  On-Demand: $OD_COLD cold starts out of $OD_TOTAL requests ($OD_RATE%)"
    fi
    
    if [ -f "$PROVISIONED_FILE" ]; then
        PR_TOTAL=$(tail -n +2 "$PROVISIONED_FILE" | wc -l | tr -d ' ')
        PR_COLD=$(grep -c "true" "$PROVISIONED_FILE" || echo "0")
        PR_RATE=$(echo "scale=1; $PR_COLD * 100 / $PR_TOTAL" | bc)
        echo "  Provisioned: $PR_COLD cold starts out of $PR_TOTAL requests ($PR_RATE%)"
    fi
    
    echo ""
done

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Wait 24-48 hours for AWS Cost Explorer data to populate"
echo "  2. Run: ./scripts/analyze-cloudwatch.sh"
echo "  3. Run: ./scripts/analyze-costs.sh"
echo "  4. Compare with sequential test results"
echo ""
echo -e "${YELLOW}⚠️  REMINDER: Provisioned concurrency is still charging!${NC}"
echo -e "${YELLOW}   Run ./scripts/cleanup.sh when done to stop charges${NC}"
