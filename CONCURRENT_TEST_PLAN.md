# Concurrent Load Test Plan

## Why We Need This Test

The first experiment (sequential load) revealed that **provisioned concurrency provides no value for sequential workloads**. We saw:
- Zero cold starts on on-demand
- Identical performance (52ms avg)
- 49x higher cost for provisioned

**The problem**: Our test sent requests one at a time, so Lambda never needed to scale out.

**The solution**: Test with **true concurrent load** to force Lambda scaling and measure real cold start impact.

---

## Test Design

### Scenario 1: Moderate Concurrency
**Pattern**: 100 concurrent requests × 10 rounds (30s between rounds)

**Purpose**: Simulate moderate API traffic spikes

**Expected Results**:
- **On-Demand**: ~100 cold starts in first round, then warm instances reused
- **Provisioned**: ~95 cold starts (5 provisioned handle first 5, rest are cold)
- **Duration**: ~5 minutes

### Scenario 2: High Concurrency
**Pattern**: 500 concurrent requests × 3 rounds (5min between rounds)

**Purpose**: Simulate high-traffic events (product launches, viral content)

**Expected Results**:
- **On-Demand**: ~500 cold starts per round (5min gap causes instances to shut down)
- **Provisioned**: ~495 cold starts per round (only 5 stay warm)
- **Duration**: ~15 minutes

### Scenario 3: Burst Concurrency
**Pattern**: 20 concurrent requests × 5 rounds (10s between rounds)

**Purpose**: Test within provisioned capacity (5 instances)

**Expected Results**:
- **On-Demand**: ~20 cold starts in first round, then warm
- **Provisioned**: ~15 cold starts in first round (5 provisioned + 15 cold), then warm
- **Duration**: ~1 minute

---

## How It Works

### Sequential vs Concurrent

**Sequential (previous test)**:
```bash
for i in 1..100; do
    curl $URL    # Wait for response
    sleep 60ms   # Then next request
done
# Result: 1 execution environment handles all requests
```

**Concurrent (new test)**:
```bash
for i in 1..100; do
    curl $URL &  # & = run in background (don't wait)
done
wait  # Wait for ALL to complete
# Result: Lambda creates 100 execution environments
```

### What This Triggers

**Concurrent load forces Lambda to**:
1. Create multiple execution environments simultaneously
2. Initialize new instances (cold starts)
3. Scale out to handle load
4. Show the value of pre-warmed provisioned instances

---

## Expected Metrics

### Cold Starts

| Scenario | On-Demand | Provisioned (5 instances) | Provisioned Benefit |
|----------|-----------|---------------------------|---------------------|
| Moderate (100 concurrent) | ~100 first round | ~95 first round | 5% reduction |
| High (500 concurrent) | ~500 per round | ~495 per round | 1% reduction |
| Burst (20 concurrent) | ~20 first round | ~15 first round | 25% reduction |

**Key insight**: Provisioned concurrency only helps for the first N requests (where N = provisioned count).

### Latency Impact

**Cold start latency**: ~150-400ms (vs ~50ms warm)

**Expected P99 latency**:
- **On-Demand**: 200-400ms (includes cold starts)
- **Provisioned**: 100-150ms (mostly warm, some spillover cold starts)

### Cost Analysis

**Provisioned capacity cost**: $0.1875 for 2.5 hours (from first test)

**Break-even calculation**:
- If cold starts cost you > $0.1875 in user experience, provisioned wins
- Example: If 1% of users abandon due to cold start latency, calculate revenue impact

---

## Running the Test

### Quick Start

```bash
# Run all concurrent scenarios
./scripts/run-concurrent-experiments.sh
```

### Individual Scenarios

```bash
# Source function URLs
source .config/function-urls.env

# Moderate concurrency
./scripts/concurrent-load-test.sh "$ONDEMAND_URL" 100 10 30 "moderate-ondemand"
./scripts/concurrent-load-test.sh "$PROVISIONED_URL" 100 10 30 "moderate-provisioned"

# High concurrency
./scripts/concurrent-load-test.sh "$ONDEMAND_URL" 500 3 300 "high-ondemand"
./scripts/concurrent-load-test.sh "$PROVISIONED_URL" 500 3 300 "high-provisioned"

# Burst concurrency
./scripts/concurrent-load-test.sh "$ONDEMAND_URL" 20 5 10 "burst-ondemand"
./scripts/concurrent-load-test.sh "$PROVISIONED_URL" 20 5 10 "burst-provisioned"
```

---

## What We'll Learn

### 1. Actual Cold Start Frequency
How often do cold starts really happen under concurrent load?

### 2. Cold Start Impact
What's the latency penalty? How does it affect P99?

### 3. Provisioned Concurrency Value
Does pre-warming 5 instances make a meaningful difference?

### 4. Cost/Performance Trade-off
Is the $0.90/day cost justified by the performance improvement?

### 5. Scaling Behavior
How quickly does Lambda scale? How many cold starts occur during scale-out?

---

## Comparison: Sequential vs Concurrent

| Metric | Sequential Test | Concurrent Test (Expected) |
|--------|----------------|---------------------------|
| **Cold Starts** | 0 (on-demand) | ~620 (on-demand) |
| **Concurrency** | 1 (single instance) | Up to 500 (multiple instances) |
| **Provisioned Benefit** | None | Reduced cold starts |
| **Use Case** | Queue processing, scheduled jobs | API endpoints, real-time apps |

---

## After the Test

### Analysis Steps

1. **Count cold starts**:
   ```bash
   grep -c "true" results/moderate-ondemand-*.csv
   grep -c "true" results/moderate-provisioned-*.csv
   ```

2. **Calculate cold start rate**:
   ```bash
   # On-demand
   TOTAL=$(tail -n +2 results/moderate-ondemand-*.csv | wc -l)
   COLD=$(grep -c "true" results/moderate-ondemand-*.csv)
   echo "scale=2; $COLD * 100 / $TOTAL" | bc
   ```

3. **Compare latency**:
   - Extract P99 from CloudWatch
   - Compare on-demand vs provisioned
   - Calculate improvement

4. **Cost analysis**:
   - Wait 24-48 hours for Cost Explorer
   - Compare total cost
   - Calculate cost per request

---

## Blog Post Outline

### Part 1: The Sequential Test (Already Done)
"I tested Lambda with 9,200 requests and saw zero cold starts. Here's why that doesn't matter."

### Part 2: The Concurrent Test (After This)
"Then I tested with concurrent load and everything changed. Here's when provisioned concurrency actually matters."

### Key Findings to Share
1. Sequential vs concurrent workload behavior
2. Actual cold start frequency under load
3. Provisioned concurrency value proposition
4. Cost/performance trade-off analysis
5. Decision framework: When to use provisioned concurrency

---

## Timeline

- **Now**: Sequential test complete, documented
- **Next**: Run concurrent test (~25 minutes)
- **+24-48 hours**: Cost Explorer data available
- **Then**: Write blog post with both datasets

---

## Cost Estimate

**Concurrent test**:
- Total requests: 100×10 + 500×3 + 20×5 = 2,600 requests
- Estimated cost: < $0.50 (mostly cold start INIT charges)

**Total experiment cost**: < $1.00 for both sequential and concurrent tests

---

*Ready to run when you are!*
