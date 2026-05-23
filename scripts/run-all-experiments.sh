#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Lambda Cost Experiment${NC}"
echo -e "${GREEN}Running All Test Scenarios${NC}"
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

# Confirm before starting
echo -e "${YELLOW}This will run 6 test scenarios and take approximately 2.5 hours.${NC}"
echo -e "${YELLOW}Tests will run in parallel where possible to save time.${NC}"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Create results directory
mkdir -p results

# Track start time
EXPERIMENT_START=$(date +%s)
echo "Experiment started at: $(date)" | tee results/experiment-log.txt
echo "" | tee -a results/experiment-log.txt

# ============================================
# Scenario 1: Low Traffic
# 100 invocations over 60 minutes
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Scenario 1: Low Traffic${NC}"
echo -e "${BLUE}100 invocations over 60 minutes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Starting low traffic tests (running in parallel)..."
echo "This will take approximately 60 minutes..."
echo ""

"$SCRIPT_DIR/load-test.sh" "$ONDEMAND_URL" 100 36000 "low-ondemand" &
PID_LOW_ONDEMAND=$!

"$SCRIPT_DIR/load-test.sh" "$PROVISIONED_URL" 100 36000 "low-provisioned" &
PID_LOW_PROVISIONED=$!

# Wait for both to complete
wait $PID_LOW_ONDEMAND
wait $PID_LOW_PROVISIONED

echo "Low traffic scenario complete!" | tee -a results/experiment-log.txt
echo "" | tee -a results/experiment-log.txt

# ============================================
# Scenario 2: Steady Traffic
# 3,000 invocations over 30 minutes
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Scenario 2: Steady Traffic${NC}"
echo -e "${BLUE}3,000 invocations over 30 minutes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Starting steady traffic tests (running in parallel)..."
echo "This will take approximately 30 minutes..."
echo ""

"$SCRIPT_DIR/load-test.sh" "$ONDEMAND_URL" 3000 600 "steady-ondemand" &
PID_STEADY_ONDEMAND=$!

"$SCRIPT_DIR/load-test.sh" "$PROVISIONED_URL" 3000 600 "steady-provisioned" &
PID_STEADY_PROVISIONED=$!

# Wait for both to complete
wait $PID_STEADY_ONDEMAND
wait $PID_STEADY_PROVISIONED

echo "Steady traffic scenario complete!" | tee -a results/experiment-log.txt
echo "" | tee -a results/experiment-log.txt

# ============================================
# Scenario 3: Bursty Traffic
# 500 invocations in 30 seconds, repeated 3 times
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Scenario 3: Bursty Traffic${NC}"
echo -e "${BLUE}500 invocations in 30 sec, 3 rounds${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

for round in 1 2 3; do
    echo -e "${YELLOW}Burst round $round of 3${NC}"
    
    "$SCRIPT_DIR/load-test.sh" "$ONDEMAND_URL" 500 60 "burst-r${round}-ondemand" &
    PID_BURST_ONDEMAND=$!
    
    "$SCRIPT_DIR/load-test.sh" "$PROVISIONED_URL" 500 60 "burst-r${round}-provisioned" &
    PID_BURST_PROVISIONED=$!
    
    # Wait for both bursts to complete
    wait $PID_BURST_ONDEMAND
    wait $PID_BURST_PROVISIONED
    
    echo "Burst round $round complete!" | tee -a results/experiment-log.txt
    
    # Wait 5 minutes between rounds (except after the last round)
    if [ $round -lt 3 ]; then
        echo "Waiting 5 minutes before next burst..."
        sleep 300
    fi
done

echo "" | tee -a results/experiment-log.txt

# ============================================
# Experiment Complete
# ============================================
EXPERIMENT_END=$(date +%s)
DURATION=$((EXPERIMENT_END - EXPERIMENT_START))
HOURS=$((DURATION / 3600))
MINUTES=$(((DURATION % 3600) / 60))

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Experiments Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Experiment ended at: $(date)" | tee -a results/experiment-log.txt
echo "Total duration: ${HOURS}h ${MINUTES}m" | tee -a results/experiment-log.txt
echo ""
echo "Results saved to: results/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Wait 24-48 hours for AWS Cost Explorer data to populate"
echo "  2. Run: ./scripts/analyze-cloudwatch.sh"
echo "  3. Run: ./scripts/analyze-costs.sh"
echo "  4. Run: ./scripts/generate-report.sh"
echo ""
echo -e "${YELLOW}⚠️  REMINDER: Provisioned concurrency is still charging!${NC}"
echo -e "${YELLOW}   Run ./scripts/cleanup.sh to stop charges${NC}"
