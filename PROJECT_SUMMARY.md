# AWS Lambda Cost Experiment - Project Summary

## ✅ Project Status: Ready to Run

**GitHub Repository**: https://github.com/hsiddhu2/aws-lambda-cost-experiment

**AWS Account**: 975050220345 (harrysiddhu)

**Prerequisites**: ✅ All verified
- AWS CLI: v2.31.27
- SAM CLI: v1.154.0
- AWS Credentials: Configured
- GitHub: Repository created and pushed

---

## 📋 What You Have

### Complete Infrastructure
- **Lambda Functions**: Node.js 22.x and Python 3.13 implementations
- **SAM Templates**: Infrastructure as Code for both on-demand and provisioned configurations
- **Automated Scripts**: Deploy, test, analyze, cleanup - all automated
- **Documentation**: README, Quick Start, and detailed experiment guide

### Project Structure
```
aws-lambda-cost-experiment/
├── README.md                          # Main documentation
├── QUICKSTART.md                      # 5-minute start guide
├── LICENSE                            # MIT license
├── cost_files_01_experiment.md        # Detailed experiment guide
├── functions/
│   ├── nodejs/index.mjs              # Node.js Lambda function
│   └── python/lambda_function.py     # Python Lambda function
├── infrastructure/
│   ├── template.yaml                 # SAM CloudFormation template
│   └── samconfig.toml                # SAM configuration
└── scripts/
    ├── deploy.sh                     # Deploy both Lambda functions
    ├── run-all-experiments.sh        # Run all 3 scenarios
    ├── load-test.sh                  # Core load testing script
    ├── analyze-cloudwatch.sh         # Extract CloudWatch metrics
    ├── analyze-costs.sh              # Fetch Cost Explorer data
    ├── generate-report.sh            # Create summary report
    └── cleanup.sh                    # Remove all resources
```

---

## 🚀 Next Steps: Run the Experiment

### Step 1: Deploy (5 minutes)
```bash
cd /Users/harpreetsiddhu/Documents/Personal/Projects/aws-lambda-cost
./scripts/deploy.sh
```

This will:
- Build and deploy two Lambda functions
- Configure provisioned concurrency (5 instances)
- Create function URLs for testing
- Save configuration to `.config/function-urls.env`

**⚠️ Cost Alert**: Provisioned concurrency starts charging immediately (~$0.0375/hour = ~$0.90/day)

### Step 2: Run Experiments (2.5 hours)
```bash
./scripts/run-all-experiments.sh
```

This runs:
1. **Low traffic**: 100 invocations over 60 minutes (both configs in parallel)
2. **Steady traffic**: 3,000 invocations over 30 minutes (both configs in parallel)
3. **Bursty traffic**: 500 invocations in 30 seconds, 3 rounds (both configs in parallel)

Results saved to `results/` directory.

### Step 3: Wait for Cost Data (24-48 hours)
AWS Cost Explorer needs time to populate. Set a reminder for Sunday.

### Step 4: Analyze (5 minutes)
```bash
# Get performance metrics
./scripts/analyze-cloudwatch.sh

# Get cost data (after 24-48 hours)
./scripts/analyze-costs.sh

# Generate report
./scripts/generate-report.sh
```

Output: `analysis/EXPERIMENT_REPORT.md`

### Step 5: Cleanup (1 minute)
```bash
./scripts/cleanup.sh
```

**⚠️ Critical**: Don't forget this or you'll pay ~$15/month for idle provisioned concurrency!

---

## 📊 What You'll Measure

### Performance Metrics
- **Cold starts**: How many times Lambda had to initialize
- **P99 latency**: 99th percentile response time
- **Average duration**: Mean execution time
- **Total billed seconds**: Actual compute time charged

### Cost Breakdown
- **On-demand compute**: Per-invocation charges
- **Provisioned compute**: Per-invocation charges (cheaper per invocation)
- **Provisioned capacity**: Continuous charge for warm instances
- **Request charges**: $0.20 per million requests

### The Key Finding
**The crossover point**: At what traffic level does provisioned concurrency become cheaper than on-demand?

This is the number nobody is publishing with real data post-August 2025 INIT billing change.

---

## 💰 Expected Costs

| Item | Cost |
|------|------|
| Experiment runtime | < $1.00 |
| If you forget cleanup | ~$15/month |

---

## 📝 For Your Blog Post

After the experiment, you'll have:

1. **Real data** from your AWS account
2. **Actual costs** down to the cent
3. **Performance metrics** with cold start counts
4. **The crossover point** - when provisioned wins
5. **Visual data** - CloudWatch charts you can screenshot

### Post Structure (from experiment guide)
1. **Hook**: "I ran this in my AWS account this week..."
2. **Setup**: Brief experiment description
3. **Data**: Your table with real numbers
4. **Surprise**: What wasn't obvious
5. **Decision rule**: When to use provisioned vs on-demand
6. **Question**: "What's your strategy?"

---

## 🔧 Troubleshooting

### Provisioned concurrency stuck
```bash
# Check your Lambda concurrent execution limit
aws lambda get-account-settings --region us-east-1

# If needed, reduce provisioned count in infrastructure/template.yaml
# Change ProvisionedConcurrency from 5 to 2
```

### Cost Explorer shows $0
- Wait 24-48 hours after experiment
- Tags can take time to populate
- Check billing dashboard as alternative

### Function URL returns 502
- Check function timeout (should be 30 seconds)
- Check CloudWatch logs for errors
- Verify handler name matches runtime

---

## 📅 Timeline

**Friday (Today)**: 
- ✅ Project created
- ✅ GitHub repository set up
- Ready to deploy

**Friday Evening**: 
- Deploy infrastructure (5 min)
- Start experiments (2.5 hours)
- Let it run

**Saturday**: 
- Wait for Cost Explorer data

**Sunday**: 
- Run analysis scripts (5 min)
- Review data
- Draft blog post with the data

**Monday**: 
- Publish post
- Share on LinkedIn/Twitter

---

## 🎯 Success Criteria

You'll know the experiment succeeded when you have:

- [ ] Both Lambda functions deployed
- [ ] All 6 test scenarios completed (3 scenarios × 2 configs)
- [ ] CloudWatch metrics showing cold starts and latency
- [ ] Cost Explorer data showing actual costs
- [ ] Generated report with all findings
- [ ] Resources cleaned up (no ongoing charges)

---

## 📞 Support

If you run into issues:

1. Check `QUICKSTART.md` for common problems
2. Review `cost_files_01_experiment.md` for detailed guidance
3. Check CloudWatch logs: `/aws/lambda/cost-files-test-*`
4. Verify AWS credentials: `aws sts get-caller-identity`

---

## 🎉 Ready to Go!

Everything is set up and ready. When you're ready to start:

```bash
cd /Users/harpreetsiddhu/Documents/Personal/Projects/aws-lambda-cost
./scripts/deploy.sh
```

Good luck with the experiment! The data you collect will make a great blog post.
