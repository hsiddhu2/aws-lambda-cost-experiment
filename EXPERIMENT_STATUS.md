# Experiment Status

## 🚀 Experiment Running!

**Start Time**: Friday, May 22, 2026 at 11:42 PM EDT

**Expected Completion**: Saturday, May 23, 2026 at ~2:10 AM EDT (approximately 2.5 hours)

---

## Deployed Resources

### Lambda Functions

**On-Demand Function**:
- Name: `cost-files-test-lambda-cost-ondemand`
- URL: https://7xjtmfyhl2f6mrd6edtu2d6fnq0wgvsu.lambda-url.us-east-1.on.aws/
- Configuration: Standard on-demand Lambda
- Memory: 512 MB
- Runtime: Node.js 22.x

**Provisioned Function**:
- Name: `cost-files-test-lambda-cost-provisioned`
- URL: https://dnjm4nybxyzyrhpdancl4dqs7y0toqdm.lambda-url.us-east-1.on.aws/
- Configuration: 5 provisioned concurrent executions
- Memory: 512 MB
- Runtime: Node.js 22.x

---

## Test Scenarios Running

### ✅ Scenario 1: Low Traffic (In Progress)
- **Pattern**: 100 invocations over 60 minutes
- **Started**: 11:42 PM
- **Expected End**: 12:42 AM
- **Status**: Running in parallel (both on-demand and provisioned)

### ⏳ Scenario 2: Steady Traffic (Queued)
- **Pattern**: 3,000 invocations over 30 minutes
- **Expected Start**: 12:42 AM
- **Expected End**: 1:12 AM

### ⏳ Scenario 3: Bursty Traffic (Queued)
- **Pattern**: 500 invocations in 30 seconds, 3 rounds
- **Expected Start**: 1:12 AM
- **Expected End**: ~2:10 AM

---

## Progress Tracking

You can monitor progress by checking:

```bash
# View live log
tail -f experiment-run.log

# Check results directory
ls -lh results/

# Check if processes are still running
ps aux | grep load-test
```

---

## Next Steps (After Completion)

### 1. Wait for Cost Data (24-48 hours)
AWS Cost Explorer needs time to populate. Set a reminder for Sunday, May 24.

### 2. Analyze Results (Sunday)
```bash
# Extract CloudWatch metrics
./scripts/analyze-cloudwatch.sh

# Get cost data
./scripts/analyze-costs.sh

# Generate report
./scripts/generate-report.sh
```

### 3. Review Data
Open `analysis/EXPERIMENT_REPORT.md` to see:
- Cold start counts
- P99 latency metrics
- Total costs by configuration
- The crossover point

### 4. Draft Blog Post
Use the data to write your "Cloud Cost Files #1" post with real numbers.

### 5. Cleanup Resources
```bash
./scripts/cleanup.sh
```

**⚠️ IMPORTANT**: Don't forget to run cleanup! Provisioned concurrency costs ~$0.90/day even when idle.

---

## Cost Tracking

**Provisioned Concurrency Charge**: Started at 11:18 PM EDT
- Rate: ~$0.0375/hour
- Daily: ~$0.90/day
- **Action Required**: Run cleanup.sh after analysis to stop charges

**Experiment Cost**: Expected < $1.00 total

---

## Files Generated

Results will be saved to:
- `results/low-ondemand-*.csv`
- `results/low-provisioned-*.csv`
- `results/steady-ondemand-*.csv`
- `results/steady-provisioned-*.csv`
- `results/burst-r1-ondemand-*.csv`
- `results/burst-r1-provisioned-*.csv`
- `results/burst-r2-ondemand-*.csv`
- `results/burst-r2-provisioned-*.csv`
- `results/burst-r3-ondemand-*.csv`
- `results/burst-r3-provisioned-*.csv`
- `results/experiment-log.txt`

---

## Troubleshooting

**Check if experiment is still running**:
```bash
ps aux | grep run-all-experiments
```

**View current progress**:
```bash
tail -f experiment-run.log
```

**Check results so far**:
```bash
ls -lh results/
wc -l results/*.csv
```

**If experiment stops unexpectedly**:
- Check `experiment-run.log` for errors
- Verify Lambda functions are still deployed: `aws lambda list-functions --region us-east-1`
- Re-run individual scenarios manually using `./scripts/load-test.sh`

---

## Timeline

- **Friday 11:18 PM**: Infrastructure deployed
- **Friday 11:42 PM**: Experiments started
- **Saturday 12:42 AM**: Low traffic complete, steady traffic starts
- **Saturday 1:12 AM**: Steady traffic complete, bursty traffic starts
- **Saturday 2:10 AM**: All experiments complete
- **Sunday**: Analyze data and draft blog post
- **Monday**: Cleanup resources

---

*Last Updated: Friday, May 22, 2026 at 11:42 PM EDT*
