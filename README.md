# AWS Lambda Cost Experiment: On-Demand vs Provisioned Concurrency

A reproducible benchmark measuring the cost and performance differences between AWS Lambda on-demand and provisioned concurrency configurations, particularly after the August 2025 billing change that introduced INIT phase charges.

## 🎯 What This Measures

This experiment quantifies the actual crossover point where provisioned concurrency becomes more cost-effective than on-demand Lambda, across three realistic traffic patterns:

- **Low traffic**: 100 invocations over 60 minutes
- **Steady traffic**: 100 invocations/minute for 30 minutes (3,000 total)
- **Bursty traffic**: 500 invocations in 30 seconds, repeated 3 times

## 📊 Key Metrics

For each scenario, we measure:
- Cold start count
- P99 latency
- Total cost (compute + requests + provisioned capacity)

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with credentials
- AWS SAM CLI installed ([installation guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html))
- Node.js 22.x or Python 3.13
- `jq` for JSON processing (optional, for analysis)

### 1. Deploy the Lambda Functions

```bash
# Deploy both on-demand and provisioned configurations
./scripts/deploy.sh
```

This creates:
- `cost-files-test-ondemand` - Standard Lambda function
- `cost-files-test-provisioned` - Lambda with 5 provisioned concurrent executions

### 2. Run the Experiments

```bash
# Run all three traffic scenarios for both configurations
./scripts/run-all-experiments.sh
```

This takes approximately 2.5 hours to complete. Results are saved to `results/`.

### 3. Analyze the Data

Wait 24-48 hours for AWS Cost Explorer data to populate, then:

```bash
# Extract CloudWatch metrics
./scripts/analyze-cloudwatch.sh

# Fetch cost data from Cost Explorer
./scripts/analyze-costs.sh
```

### 4. Generate the Report

```bash
# Create a summary report with all metrics
./scripts/generate-report.sh
```

## 📁 Project Structure

```
.
├── README.md                          # This file
├── cost_files_01_experiment.md        # Detailed experiment guide
├── functions/
│   ├── nodejs/                        # Node.js Lambda function
│   │   └── index.mjs
│   └── python/                        # Python Lambda function
│       └── lambda_function.py
├── infrastructure/
│   ├── template.yaml                  # SAM template for deployment
│   └── samconfig.toml                 # SAM configuration
├── scripts/
│   ├── deploy.sh                      # Deploy Lambda functions
│   ├── load-test.sh                   # Core load testing script
│   ├── run-all-experiments.sh         # Run all scenarios
│   ├── analyze-cloudwatch.sh          # Extract CloudWatch metrics
│   ├── analyze-costs.sh               # Fetch Cost Explorer data
│   ├── generate-report.sh             # Create summary report
│   └── cleanup.sh                     # Remove all resources
├── results/                           # Test results (gitignored)
└── analysis/                          # Analysis outputs (gitignored)
```

## 🧪 Running Individual Scenarios

If you want to run specific scenarios:

```bash
# Get function URLs from deployment output
ONDEMAND_URL=$(aws cloudformation describe-stacks --stack-name lambda-cost-ondemand --query 'Stacks[0].Outputs[?OutputKey==`FunctionUrl`].OutputValue' --output text)
PROVISIONED_URL=$(aws cloudformation describe-stacks --stack-name lambda-cost-provisioned --query 'Stacks[0].Outputs[?OutputKey==`FunctionUrl`].OutputValue' --output text)

# Low traffic: 100 invocations over 60 minutes
./scripts/load-test.sh "$ONDEMAND_URL" 100 36000 "low-ondemand"
./scripts/load-test.sh "$PROVISIONED_URL" 100 36000 "low-provisioned"

# Steady traffic: 3,000 invocations over 30 minutes
./scripts/load-test.sh "$ONDEMAND_URL" 3000 600 "steady-ondemand"
./scripts/load-test.sh "$PROVISIONED_URL" 3000 600 "steady-provisioned"

# Bursty traffic: 500 invocations in 30 seconds, 3 rounds
./scripts/load-test.sh "$ONDEMAND_URL" 500 60 "burst-ondemand"
./scripts/load-test.sh "$PROVISIONED_URL" 500 60 "burst-provisioned"
```

## 💰 Cost Considerations

**Expected total cost**: < $1 USD for the entire experiment

**⚠️ IMPORTANT**: Provisioned concurrency charges continuously (~$0.0375/hour for 5 instances at 512MB). The cleanup script disables this automatically, but if you stop mid-experiment, manually disable it:

```bash
aws lambda delete-provisioned-concurrency-config \
  --function-name cost-files-test-provisioned \
  --qualifier '$LATEST'
```

Or run:
```bash
./scripts/cleanup.sh
```

## 🧹 Cleanup

Remove all resources and stop charges:

```bash
./scripts/cleanup.sh
```

This will:
- Delete both Lambda functions
- Remove CloudWatch log groups
- Delete CloudFormation stacks
- Disable provisioned concurrency

## 📈 Expected Results

Based on current AWS pricing (US-East-1):

- **Cold starts**: On-demand will show 10-20 cold starts in bursty scenarios; provisioned should show 0-2
- **Latency**: Provisioned should have consistent ~80-100ms p99; on-demand will spike to 150-400ms on cold starts
- **Cost**: Provisioned wins on per-invocation cost in bursty scenarios but has continuous idle charges

The actual crossover point is what we're measuring!

## 🔧 Troubleshooting

**Provisioned concurrency stuck in IN_PROGRESS**
- Check your account's concurrent execution limit
- Reduce provisioned count from 5 to 2 in `infrastructure/template.yaml`

**Function URL returns 502**
- Verify function timeout is set to 30 seconds
- Check CloudWatch logs for errors

**Cost Explorer shows $0 after 24 hours**
- Tags can take up to 48 hours to populate
- Check the billing dashboard as an alternative

## 📝 License

MIT

## 🤝 Contributing

This is an experiment template. Feel free to fork and adapt for your own cost analysis!

## 📚 Related Reading

- [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [Provisioned Concurrency Documentation](https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html)
- [AWS Lambda INIT Phase Billing (August 2025 change)](https://aws.amazon.com/blogs/aws/aws-lambda-init-phase-billing/)
