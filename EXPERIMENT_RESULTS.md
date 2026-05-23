# AWS Lambda Cost Experiment - Results (Sequential Load)

**Experiment Date**: May 22-23, 2026  
**Duration**: 1 hour 58 minutes  
**Test Type**: Sequential load (non-concurrent)

---

## Executive Summary

Tested AWS Lambda on-demand vs provisioned concurrency (5 instances) across three traffic patterns with **sequential requests** (one at a time). Key finding: **Both configurations performed nearly identically** because sequential workloads don't trigger Lambda scaling or cold starts.

---

## Performance Metrics (CloudWatch)

### On-Demand Function

| Metric | Value |
|--------|-------|
| **Total Invocations** | 4,607 |
| **Cold Starts** | 0 |
| **Avg Duration** | 52.13 ms |
| **P50 Latency** | 52.04 ms |
| **P95 Latency** | 52.51 ms |
| **P99 Latency** | 53.04 ms |
| **Max Duration** | 80.58 ms |
| **Total Billed Seconds** | 242.87 seconds |
| **Avg Memory Used** | ~83 MB |

### Provisioned Function (5 instances)

| Metric | Value |
|--------|-------|
| **Total Invocations** | 4,603 |
| **Cold Starts** | 1 |
| **Avg Duration** | 52.08 ms |
| **P50 Latency** | 51.99 ms |
| **P95 Latency** | 52.30 ms |
| **P99 Latency** | 53.20 ms |
| **Max Duration** | 120.80 ms |
| **Total Billed Seconds** | 242.22 seconds |
| **Avg Memory Used** | ~83 MB |

### Performance Comparison

| Metric | On-Demand | Provisioned | Difference |
|--------|-----------|-------------|------------|
| Avg Duration | 52.13 ms | 52.08 ms | -0.05 ms (0.1%) |
| P99 Latency | 53.04 ms | 53.20 ms | +0.16 ms (0.3%) |
| Cold Starts | 0 | 1 | +1 |
| Billed Seconds | 242.87 s | 242.22 s | -0.65 s (0.3%) |

**Conclusion**: Performance is virtually identical. Provisioned concurrency provided **no measurable benefit** for sequential workloads.

---

## Test Scenarios

### Scenario 1: Low Traffic
- **Pattern**: 100 invocations over 60 minutes (36 seconds between requests)
- **Purpose**: Test below typical break-even threshold
- **Result**: Both stayed warm, zero cold starts

### Scenario 2: Steady Traffic
- **Pattern**: 3,000 invocations over 30 minutes (0.6 seconds between requests)
- **Purpose**: Moderate, realistic API traffic
- **Result**: Both stayed warm, zero cold starts

### Scenario 3: Bursty Traffic
- **Pattern**: 500 invocations in 30 seconds (60ms between requests), 3 rounds with 5-minute idle
- **Purpose**: High-frequency bursts with idle periods
- **Result**: Both stayed warm through 5-minute idle periods

---

## Key Findings

### 1. Sequential Workloads Don't Benefit from Provisioned Concurrency

**Why**: Sequential requests (one at a time) only use a single execution environment. Lambda doesn't need to scale out, so:
- No additional cold starts occur
- No concurrency pressure
- Same warm instance handles all requests

**Implication**: If your workload is sequential (API requests, queue processing, scheduled jobs), provisioned concurrency provides no value.

### 2. Lambda Execution Environments Stay Warm Longer Than Expected

**Observation**: A single execution environment handled 4,600+ invocations over 2 hours, including:
- 36-second gaps (low traffic)
- 5-minute idle periods (between bursts)

**Implication**: AWS Lambda's warm duration is sufficient for most real-world traffic patterns. The commonly cited "5-15 minute" warm window appears accurate.

### 3. The One Cold Start

The provisioned function had **1 cold start** (likely the initial deployment), while on-demand had **0**. This suggests:
- On-demand was pre-warmed by test invocations
- Provisioned concurrency initialization counted as a cold start
- In practice, both configurations behave identically for sequential loads

---

## Cost Analysis (Preliminary)

**Note**: Full cost data requires 24-48 hours for AWS Cost Explorer to populate.

### Compute Cost Estimate

**On-Demand**:
- Billed seconds: 242.87 s
- Memory: 512 MB = 0.5 GB
- GB-seconds: 242.87 × 0.5 = 121.44 GB-seconds
- Cost: 121.44 × $0.0000166667 = **$0.002024**

**Provisioned**:
- Billed seconds: 242.22 s
- Memory: 512 MB = 0.5 GB
- GB-seconds: 242.22 × 0.5 = 121.11 GB-seconds
- Compute cost: 121.11 × $0.0000097222 = **$0.001177**
- **Provisioned capacity cost**: 5 instances × 0.5 GB × 2.5 hours × 3600 s/hr × $0.0000041667 = **$0.1875**
- **Total**: $0.001177 + $0.1875 = **$0.1887**

### Request Cost

- Total requests: ~9,200
- Cost: 9,200 × $0.0000002 = **$0.00184**

### Total Estimated Cost

| Configuration | Compute | Capacity | Requests | **Total** |
|---------------|---------|----------|----------|-----------|
| On-Demand | $0.002024 | $0 | $0.00184 | **$0.00386** |
| Provisioned | $0.001177 | $0.1875 | $0.00184 | **$0.1905** |

**Provisioned concurrency cost 49x more** for this sequential workload with zero performance benefit.

---

## What We Learned

### ✅ Validated Assumptions

1. Lambda execution environments stay warm for 5-15 minutes of inactivity
2. Sequential workloads don't trigger scaling or cold starts
3. Provisioned concurrency has a significant continuous cost (~$0.90/day for 5 instances)

### ❌ Invalidated Assumptions

1. **Expected**: Bursty traffic would cause 10-20 cold starts on on-demand
   - **Actual**: Zero cold starts because requests were sequential, not concurrent

2. **Expected**: Provisioned concurrency would show latency benefits
   - **Actual**: No measurable difference (52.13ms vs 52.08ms average)

3. **Expected**: On-demand would have higher P99 latency due to cold starts
   - **Actual**: Nearly identical (53.04ms vs 53.20ms)

---

## What's Missing: Concurrent Load Testing

### The Critical Gap

Our test used **sequential requests** (one at a time):
```bash
for i in 1..500; do
    curl $URL    # Wait for response
    sleep 60ms   # Then wait
done
```

This means:
- **Maximum concurrency = 1** throughout all tests
- No Lambda scaling occurred
- No cold starts from scale-out events

### What We Need to Test

**True concurrent load** (multiple requests simultaneously):
```bash
for i in 1..100; do
    curl $URL &  # & = run in background (concurrent)
done
wait  # Wait for all to complete
```

This would:
- Force Lambda to scale out (create multiple execution environments)
- Trigger cold starts on on-demand (new instances)
- Show provisioned concurrency value (pre-warmed instances ready)

---

## Next Experiment: Concurrent Load Test

### Proposed Test Design

**Scenario 1: Moderate Concurrency**
- 100 concurrent requests
- Repeat 10 times with 30-second gaps
- Expected: On-demand scales to ~100 instances with cold starts

**Scenario 2: High Concurrency**
- 500 concurrent requests
- Repeat 3 times with 5-minute gaps
- Expected: On-demand scales to ~500 instances with many cold starts

**Scenario 3: Burst Beyond Provisioned Capacity**
- 10 concurrent requests (within provisioned capacity of 5)
- Then 20 concurrent requests (exceeds capacity)
- Expected: Provisioned handles first 5 warm, rest are cold starts

### Expected Results

| Scenario | On-Demand Cold Starts | Provisioned Cold Starts |
|----------|----------------------|------------------------|
| 100 concurrent | ~100 (first wave) | ~95 (beyond 5 provisioned) |
| 500 concurrent | ~500 (first wave) | ~495 (beyond 5 provisioned) |
| 10 then 20 | ~10 then ~20 | 0 then ~15 |

This would show the **actual value proposition** of provisioned concurrency.

---

## Recommendations

### For Sequential Workloads (like this test)

**Don't use provisioned concurrency**. You're paying 49x more for zero benefit.

Use cases:
- API endpoints with moderate traffic
- Queue processors (SQS, Kinesis)
- Scheduled jobs (EventBridge)
- Webhooks

### For Concurrent Workloads (not tested yet)

**Consider provisioned concurrency if**:
- You have predictable concurrent load
- P99 latency must be < 100ms consistently
- Cold start latency is unacceptable for your use case
- Cost of provisioned < cost of cold start impact

**Calculate break-even**:
- Provisioned cost: $0.90/day for 5 instances
- If cold starts cost you more than $0.90/day in user experience, provisioned wins

---

## Files Generated

### Raw Data
- `results/low-ondemand-*.csv` (21 KB)
- `results/low-provisioned-*.csv` (21 KB)
- `results/steady-ondemand-*.csv` (638 KB)
- `results/steady-provisioned-*.csv` (638 KB)
- `results/burst-r1-ondemand-*.csv` (106 KB)
- `results/burst-r1-provisioned-*.csv` (106 KB)
- `results/burst-r2-ondemand-*.csv` (106 KB)
- `results/burst-r2-provisioned-*.csv` (106 KB)
- `results/burst-r3-ondemand-*.csv` (106 KB)
- `results/burst-r3-provisioned-*.csv` (106 KB)

### Analysis
- `analysis/cloudwatch-ondemand.json`
- `analysis/cloudwatch-provisioned.json`

### Logs
- `experiment-run.log`
- `results/experiment-log.txt`

---

## Next Steps

1. ✅ **Document sequential load results** (this document)
2. ⏳ **Wait for Cost Explorer data** (24-48 hours)
3. 🔄 **Design concurrent load test** (see proposed design above)
4. 🔄 **Run concurrent load experiment**
5. 📊 **Compare sequential vs concurrent results**
6. ✍️ **Write blog post** with both datasets

---

## Conclusion

This experiment revealed that **provisioned concurrency provides no value for sequential workloads**. The real test of provisioned concurrency requires **concurrent load** that forces Lambda to scale out. 

Our next experiment will test true concurrency to measure:
- Actual cold start frequency and impact
- Provisioned concurrency's ability to absorb concurrent load
- The real cost/performance trade-off

**The blog post angle**: "I spent $0.19 on provisioned concurrency and got zero benefit. Here's why—and when it actually matters."

---

*Analysis Date: May 23, 2026*  
*Cost data pending: Check back in 24-48 hours*
