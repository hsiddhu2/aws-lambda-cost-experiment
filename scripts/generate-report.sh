#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Generating Experiment Report${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Create analysis directory
mkdir -p analysis

REPORT_FILE="analysis/EXPERIMENT_REPORT.md"

# Start building the report
cat > "$REPORT_FILE" << 'EOF'
# AWS Lambda Cost Experiment Report

## Experiment Overview

This report summarizes the results of comparing AWS Lambda on-demand vs provisioned concurrency across three traffic patterns.

**Experiment Date:** 
EOF

# Add experiment date
if [ -f results/experiment-log.txt ]; then
    grep "Experiment started" results/experiment-log.txt | head -1 | sed 's/Experiment started at: //' >> "$REPORT_FILE"
else
    date >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << 'EOF'

**Configuration:**
- Runtime: Node.js 22.x
- Memory: 512 MB
- Architecture: x86_64
- Region: us-east-1
- Provisioned Concurrency: 5 instances

---

## Test Scenarios

### Scenario 1: Low Traffic
- **Pattern:** 100 invocations spread over 60 minutes
- **Purpose:** Test below break-even threshold

### Scenario 2: Steady Traffic
- **Pattern:** 100 invocations/minute for 30 minutes (3,000 total)
- **Purpose:** Moderate, realistic API traffic

### Scenario 3: Bursty Traffic
- **Pattern:** 500 invocations in 30 seconds, repeated 3 times
- **Purpose:** High concurrency spikes

---

## Results Summary

EOF

# Add CloudWatch metrics if available
if [ -f analysis/cloudwatch-ondemand.json ] && [ -f analysis/cloudwatch-provisioned.json ]; then
    cat >> "$REPORT_FILE" << 'EOF'
### Performance Metrics

| Metric | On-Demand | Provisioned |
|--------|-----------|-------------|
EOF

    if command -v jq &> /dev/null; then
        # Extract metrics
        OD_INV=$(jq -r '.results[0][] | select(.field=="invocations") | .value' analysis/cloudwatch-ondemand.json 2>/dev/null || echo "N/A")
        OD_COLD=$(jq -r '.results[0][] | select(.field=="cold_starts") | .value' analysis/cloudwatch-ondemand.json 2>/dev/null || echo "N/A")
        OD_P99=$(jq -r '.results[0][] | select(.field=="p99_duration_ms") | .value' analysis/cloudwatch-ondemand.json 2>/dev/null || echo "N/A")
        OD_AVG=$(jq -r '.results[0][] | select(.field=="avg_duration_ms") | .value' analysis/cloudwatch-ondemand.json 2>/dev/null || echo "N/A")
        
        PR_INV=$(jq -r '.results[0][] | select(.field=="invocations") | .value' analysis/cloudwatch-provisioned.json 2>/dev/null || echo "N/A")
        PR_COLD=$(jq -r '.results[0][] | select(.field=="cold_starts") | .value' analysis/cloudwatch-provisioned.json 2>/dev/null || echo "N/A")
        PR_P99=$(jq -r '.results[0][] | select(.field=="p99_duration_ms") | .value' analysis/cloudwatch-provisioned.json 2>/dev/null || echo "N/A")
        PR_AVG=$(jq -r '.results[0][] | select(.field=="avg_duration_ms") | .value' analysis/cloudwatch-provisioned.json 2>/dev/null || echo "N/A")
        
        # Format numbers
        if [ "$OD_P99" != "N/A" ]; then
            OD_P99=$(printf "%.2f ms" "$OD_P99")
        fi
        if [ "$PR_P99" != "N/A" ]; then
            PR_P99=$(printf "%.2f ms" "$PR_P99")
        fi
        if [ "$OD_AVG" != "N/A" ]; then
            OD_AVG=$(printf "%.2f ms" "$OD_AVG")
        fi
        if [ "$PR_AVG" != "N/A" ]; then
            PR_AVG=$(printf "%.2f ms" "$PR_AVG")
        fi
        
        cat >> "$REPORT_FILE" << EOF
| Total Invocations | $OD_INV | $PR_INV |
| Cold Starts | $OD_COLD | $PR_COLD |
| Avg Latency | $OD_AVG | $PR_AVG |
| P99 Latency | $OD_P99 | $PR_P99 |

EOF
    else
        echo "| (Install jq to see metrics) | - | - |" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
fi

# Add cost data if available
if [ -f analysis/costs-by-function.json ]; then
    cat >> "$REPORT_FILE" << 'EOF'
### Cost Breakdown

EOF

    if command -v jq &> /dev/null; then
        ONDEMAND_TOTAL=$(jq -r '[.ResultsByTime[].Groups[] | select(.Keys[0] == "ondemand") | .Metrics.UnblendedCost.Amount | tonumber] | add // 0' analysis/costs-by-function.json)
        PROVISIONED_TOTAL=$(jq -r '[.ResultsByTime[].Groups[] | select(.Keys[0] == "provisioned") | .Metrics.UnblendedCost.Amount | tonumber] | add // 0' analysis/costs-by-function.json)
        
        cat >> "$REPORT_FILE" << EOF
| Configuration | Total Cost |
|---------------|------------|
| On-Demand | \$$(printf "%.4f" "$ONDEMAND_TOTAL") |
| Provisioned | \$$(printf "%.4f" "$PROVISIONED_TOTAL") |

**Cost Difference:** \$$(printf "%.4f" "$(echo "$PROVISIONED_TOTAL - $ONDEMAND_TOTAL" | bc)")

EOF
    else
        echo "*(Install jq to see cost breakdown)*" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
fi

# Add analysis section
cat >> "$REPORT_FILE" << 'EOF'
---

## Key Findings

### Cold Start Impact

EOF

# Add cold start analysis
if command -v jq &> /dev/null && [ -f analysis/cloudwatch-ondemand.json ]; then
    OD_COLD=$(jq -r '.results[0][] | select(.field=="cold_starts") | .value' analysis/cloudwatch-ondemand.json 2>/dev/null || echo "0")
    PR_COLD=$(jq -r '.results[0][] | select(.field=="cold_starts") | .value' analysis/cloudwatch-provisioned.json 2>/dev/null || echo "0")
    
    cat >> "$REPORT_FILE" << EOF
- On-Demand experienced **$OD_COLD cold starts**
- Provisioned experienced **$PR_COLD cold starts**
- Cold start reduction: **$(echo "scale=1; ($OD_COLD - $PR_COLD) * 100 / $OD_COLD" | bc)%**

EOF
fi

cat >> "$REPORT_FILE" << 'EOF'
### Latency Performance

*(Add your observations about P99 latency differences)*

### Cost Efficiency

*(Add your analysis of when provisioned concurrency becomes cost-effective)*

---

## Conclusions

### When to Use On-Demand

- 

### When to Use Provisioned Concurrency

- 

### The Crossover Point

*(Based on your data, at what traffic level does provisioned concurrency become more cost-effective?)*

---

## Raw Data Files

- CloudWatch Metrics: `analysis/cloudwatch-*.json`
- Cost Data: `analysis/costs-*.json`
- Load Test Results: `results/*.csv`

---

## Appendix: Detailed Results

### Load Test Summary

EOF

# Add summary of each test file
if [ -d results ]; then
    for file in results/*.csv; do
        if [ -f "$file" ]; then
            FILENAME=$(basename "$file")
            TOTAL_LINES=$(wc -l < "$file")
            INVOCATIONS=$((TOTAL_LINES - 1))  # Subtract header
            
            if [ $INVOCATIONS -gt 0 ]; then
                COLD_COUNT=$(grep -c "true" "$file" || echo "0")
                ERROR_COUNT=$(grep -cv "200" "$file" || echo "0")
                ERROR_COUNT=$((ERROR_COUNT - 1))  # Subtract header
                
                cat >> "$REPORT_FILE" << EOF

**$FILENAME**
- Total invocations: $INVOCATIONS
- Cold starts: $COLD_COUNT
- Errors: $ERROR_COUNT

EOF
            fi
        fi
    done
fi

cat >> "$REPORT_FILE" << 'EOF'

---

*Report generated automatically from experiment data*
EOF

echo -e "${GREEN}✓ Report generated: $REPORT_FILE${NC}"
echo ""

# Display the report
if command -v bat &> /dev/null; then
    bat "$REPORT_FILE"
elif command -v less &> /dev/null; then
    less "$REPORT_FILE"
else
    cat "$REPORT_FILE"
fi

echo ""
echo -e "${BLUE}Report saved to: $REPORT_FILE${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the report and fill in your observations"
echo "  2. Use this data for your blog post"
echo "  3. Run ./scripts/cleanup.sh to remove resources"
