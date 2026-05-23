# Quick Start Guide

Get your AWS Lambda cost experiment running in 5 minutes.

## Prerequisites Check

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check SAM CLI
sam --version

# Check Node.js (optional, for local testing)
node --version
```

If SAM CLI is not installed:
```bash
brew install aws-sam-cli
```

## Run the Experiment

### 1. Deploy (5 minutes)

```bash
./scripts/deploy.sh
```

This creates two Lambda functions:
- `cost-files-test-lambda-cost-ondemand` - Standard on-demand
- `cost-files-test-lambda-cost-provisioned` - With 5 provisioned instances

**⚠️ Provisioned concurrency starts charging immediately (~$0.0375/hour)**

### 2. Run Tests (2.5 hours)

```bash
./scripts/run-all-experiments.sh
```

This runs all three traffic scenarios in parallel where possible:
- Low traffic: 60 minutes
- Steady traffic: 30 minutes  
- Bursty traffic: ~15 minutes

You can walk away - it runs unattended.

### 3. Wait for Cost Data (24-48 hours)

AWS Cost Explorer needs time to populate. Set a reminder for tomorrow.

### 4. Analyze Results (5 minutes)

```bash
# Get CloudWatch metrics
./scripts/analyze-cloudwatch.sh

# Get cost data (after 24-48 hours)
./scripts/analyze-costs.sh

# Generate report
./scripts/generate-report.sh
```

### 5. Cleanup (1 minute)

```bash
./scripts/cleanup.sh
```

**⚠️ Don't forget this step or you'll keep paying for provisioned concurrency!**

## What You'll Get

After analysis, you'll have:

1. **Performance data**: Cold starts, P99 latency, average duration
2. **Cost breakdown**: Exact costs for each configuration
3. **The crossover point**: When provisioned becomes cheaper than on-demand
4. **A report**: `analysis/EXPERIMENT_REPORT.md` with all findings

## Troubleshooting

**"SAM CLI not found"**
```bash
brew install aws-sam-cli
```

**"AWS credentials not configured"**
```bash
aws configure
```

**"Provisioned concurrency stuck"**
- Check your account's Lambda concurrent execution limit
- Reduce provisioned count from 5 to 2 in `infrastructure/template.yaml`

**"Cost Explorer shows $0"**
- Wait 24-48 hours after the experiment
- Check the billing dashboard as an alternative

## Running Individual Scenarios

If you want to test just one scenario:

```bash
# Source the function URLs
source .config/function-urls.env

# Low traffic (60 min)
./scripts/load-test.sh "$ONDEMAND_URL" 100 36000 "low-ondemand"

# Steady traffic (30 min)
./scripts/load-test.sh "$ONDEMAND_URL" 3000 600 "steady-ondemand"

# Bursty traffic (30 sec)
./scripts/load-test.sh "$ONDEMAND_URL" 500 60 "burst-ondemand"
```

## Expected Costs

- **Total experiment cost**: < $1 USD
- **If you forget cleanup**: ~$15/month for idle provisioned concurrency

## Next Steps

Use your data for:
- Blog post about Lambda cost optimization
- Internal documentation for your team
- Decision-making on provisioned concurrency strategy

See `cost_files_01_experiment.md` for the full experiment guide and post outline.
