# Cost Files #1 — The Experiment Guide

## What you're going to measure (and why this is the right experiment)

The research turned up something genuinely interesting that strengthens this experiment.

In **August 2025, AWS changed Lambda billing** to charge for the INIT phase (cold start initialization) in addition to the INVOKE phase. Before this, cold starts were "free" — just a latency problem. After this, cold starts cost money. This shifted the math on whether provisioned concurrency is worth it.

But here's the catch: most teams haven't recalibrated. They're either (a) avoiding provisioned concurrency because "it's expensive" using pre-2025 mental models, or (b) using provisioned concurrency at the wrong level because they're guessing instead of measuring.

**Your experiment will measure the actual crossover point** — the traffic level where provisioned concurrency becomes cheaper than on-demand, post-INIT-billing. That's a number nobody is publishing with real data right now.

That's a much stronger anchor than a generic "on-demand vs provisioned" comparison. The post writes itself once you have the data.

---

## The experiment plan

### What you're measuring

Three traffic scenarios × two function configurations = 6 data points

| Scenario | Pattern | Why |
|---|---|---|
| **Low traffic** | 100 invocations spread over 60 min | Below provisioned concurrency break-even (probably) |
| **Steady** | 100 invocations/min for 30 min (3,000 total) | Moderate, realistic API traffic |
| **Bursty** | 500 invocations in 30 sec, then idle | The scenario provisioned concurrency is supposed to solve |

For each scenario, you run TWO Lambda configurations:
- **On-demand** (default, no provisioned concurrency)
- **Provisioned concurrency = 5** (enough to handle the bursty case mostly without spillover)

Capture for each: cold start count, p99 latency, total cost.

### Total time estimate

- Setup: 20 min
- Running 3 scenarios × 2 configs: ~90 min (mostly waiting)
- Wait 24h for Cost Explorer
- Data capture and analysis: 30 min
- Drafting the post (with me on Sunday): 60 min

---

## Setup — copy-paste ready

### 1. Create the test Lambda function

Use the AWS Console (fastest) or CLI. Either is fine.

**Configuration:**
- Name: `cost-files-test-ondemand`
- Runtime: **Node.js 22.x** (or Python 3.13 if you prefer)
- Architecture: **x86_64** (we want the standard pricing for the post — note we could test ARM later for a #2 post)
- Memory: **512 MB**
- Timeout: **30 seconds**

**Function code (Node.js):**

```javascript
export const handler = async (event) => {
    // Simulate real work — small CPU + small I/O delay
    const start = Date.now();
    
    // Light CPU work
    let sum = 0;
    for (let i = 0; i < 100000; i++) {
        sum += Math.sqrt(i);
    }
    
    // Simulated I/O delay (50ms)
    await new Promise(resolve => setTimeout(resolve, 50));
    
    const duration = Date.now() - start;
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'OK',
            sum: sum,
            duration_ms: duration,
            cold_start: !global.warm,
        }),
    };
};

// This sets a global the first time the function runs — used to detect cold starts
global.warm = true;
```

**Function code (Python alternative):**

```python
import json
import math
import time

is_warm = False

def lambda_handler(event, context):
    global is_warm
    cold_start = not is_warm
    is_warm = True
    
    start = time.time()
    
    # Light CPU work
    total = 0
    for i in range(100000):
        total += math.sqrt(i)
    
    # Simulated I/O delay
    time.sleep(0.05)
    
    duration_ms = int((time.time() - start) * 1000)
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'OK',
            'sum': total,
            'duration_ms': duration_ms,
            'cold_start': cold_start
        })
    }
```

### 2. Clone it for the provisioned-concurrency version

- Name: `cost-files-test-provisioned`
- Same code, same memory, same runtime, same architecture
- After creating: go to **Configuration → Concurrency** → set **Provisioned concurrency = 5**
- Wait for status to show "Ready" (takes 2-3 min)

### 3. Tag both functions for cost tracking

This is critical — without tags, you can't isolate the experiment cost in Cost Explorer.

For each function:
- Configuration → Tags → Add tag
- Key: `Project` Value: `cost-files-01`
- Key: `Function` Value: `ondemand` or `provisioned` (so you can split them later)

### 4. Set up the function URL for easy invocation

For each function:
- Configuration → Function URL → Create function URL
- Auth type: **NONE** (it's a throwaway test — delete after)
- Save the URL — you'll hit it with curl

---

## Running the load tests

Use a simple bash script. Save this as `load-test.sh`:

```bash
#!/bin/bash

# Usage: ./load-test.sh <function_url> <total_invocations> <delay_between_ms>

URL=$1
COUNT=$2
DELAY_MS=$3

echo "Starting load test: $COUNT invocations to $URL with ${DELAY_MS}ms delay"
echo "Start time: $(date +%H:%M:%S)"

mkdir -p results
RESULT_FILE="results/$(basename $URL | cut -d'.' -f1)-$(date +%s).log"

for i in $(seq 1 $COUNT); do
    START_TIME=$(date +%s%3N)
    RESPONSE=$(curl -s -w "\n%{http_code}|%{time_total}" "$URL")
    END_TIME=$(date +%s%3N)
    
    BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1 | cut -d'|' -f1)
    DURATION=$(echo "$RESPONSE" | tail -n 1 | cut -d'|' -f2)
    
    echo "$i,$START_TIME,$HTTP_CODE,$DURATION,$BODY" >> "$RESULT_FILE"
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "Completed $i / $COUNT"
    fi
    
    if [ "$DELAY_MS" -gt 0 ]; then
        sleep $(echo "scale=3; $DELAY_MS/1000" | bc)
    fi
done

echo "End time: $(date +%H:%M:%S)"
echo "Results saved to: $RESULT_FILE"
```

Make it executable:
```bash
chmod +x load-test.sh
```

### Run the three scenarios — for EACH function

**Scenario 1: Low traffic** — 100 invocations over 60 min (delay = 36,000 ms = 36 sec between calls)
```bash
./load-test.sh "https://YOUR-ONDEMAND-URL/" 100 36000
./load-test.sh "https://YOUR-PROVISIONED-URL/" 100 36000
```
This takes 60 min per function. You can run them in parallel (open two terminals).

**Scenario 2: Steady** — 100 inv/min for 30 min = 3,000 invocations (delay = 600 ms)
```bash
./load-test.sh "https://YOUR-ONDEMAND-URL/" 3000 600
./load-test.sh "https://YOUR-PROVISIONED-URL/" 3000 600
```
30 min per function. Run in parallel.

**Scenario 3: Bursty** — 500 invocations in 30 sec (delay = 60 ms), then wait 5 min, repeat 3 times
```bash
for round in 1 2 3; do
    echo "Round $round burst"
    ./load-test.sh "https://YOUR-ONDEMAND-URL/" 500 60 &
    ./load-test.sh "https://YOUR-PROVISIONED-URL/" 500 60 &
    wait
    sleep 300
done
```

**Total wall-clock time:** ~2.5 hours if you do them sequentially per function, ~90 min if you run on-demand and provisioned in parallel.

---

## Capturing the data

### Cold starts and latency — from CloudWatch Logs Insights

Open CloudWatch → Logs → Logs Insights. Select the log group `/aws/lambda/cost-files-test-ondemand` (then repeat for provisioned).

Run this query for each function and each scenario time window:

```
fields @timestamp, @duration, @initDuration, @billedDuration
| filter @type = "REPORT"
| stats 
    count() as invocations,
    sum(@initDuration > 0) as cold_starts,
    avg(@duration) as avg_duration_ms,
    pct(@duration, 99) as p99_duration_ms,
    sum(@billedDuration)/1000 as total_billed_seconds
```

Set the time range to match the exact window of each scenario. Export the results — those are your real numbers.

### Cost data — from Cost Explorer (after 24 hours)

Go to **Billing → Cost Explorer**. Wait at least 24 hours after the experiment for the data to populate fully.

**Setup:**
- Group by: **Tag**
- Filter: Tag → `Project = cost-files-01`
- Service: **AWS Lambda** only
- Granularity: **Daily**
- Time range: the date(s) of your experiment

**Then split:**
- Add second filter: Tag → `Function` to separate `ondemand` vs `provisioned`

This gives you the actual dollar cost per configuration. Down to the cent.

**Important note about provisioned concurrency cost:** the provisioned function is BURNING $$ continuously while provisioned concurrency is enabled, even when no requests are hitting it. Plan for this. **Disable provisioned concurrency as soon as you finish the experiment**, or you'll keep paying. The fastest way: Configuration → Concurrency → Edit provisioned → set to 0.

---

## What the data will probably show (so you know what to look for)

I'm going to predict the outcome, not because I know your exact result, but so you have a hypothesis to test. If the actual data deviates significantly, **that's the post** — surprises make better content than confirmations.

### Predicted results

**Cold starts:**
- On-demand: First invocation of each scenario is a cold start (3 cold starts total minimum). Bursty scenario may produce 10-20 cold starts as Lambda scales out.
- Provisioned: 0 or near-0 cold starts. Maybe 1-2 spillover cold starts in the bursty scenario if the burst exceeds 5 concurrent.

**Latency (p99):**
- On-demand cold: ~150-400 ms (depending on runtime)
- On-demand warm: ~80-100 ms
- Provisioned: ~80-100 ms across all scenarios

**Cost (24h after experiment):**

Rough math at current US-East-1 prices:
- On-demand compute: $0.0000166667 per GB-second
- Provisioned compute: $0.0000097222 per GB-second (cheaper while warm)
- Provisioned capacity: $0.0000041667 per GB-second (continuous charge for warm instances)

For your 5-instance, 512 MB provisioned function:
- Idle cost per hour: 5 × 0.5 × 3600 × $0.0000041667 = **$0.0375/hour** ($0.90/day)
- Across your ~2.5 hour experiment: provisioned capacity charge alone = ~$0.09

For 3,100 invocations at on-demand (sum of all three scenarios):
- Compute: ~$0.02
- Requests: ~$0.0006

**The interesting story will be in the bursty scenario.** Provisioned likely wins on cost-per-invocation AND latency for the bursty case. On-demand likely wins on total cost in the low-traffic case.

The "Cloud Files #1" insight is probably going to be: **provisioned concurrency makes sense at a much LOWER traffic level than most people assume**, once you account for INIT billing. Or it could be the opposite — that the continuous idle charge dominates at low traffic. Either way, you'll have a real number to share.

---

## Cleanup checklist (do this immediately after data capture)

1. **Disable provisioned concurrency** (Configuration → Concurrency → set to 0)
2. **Delete the function URLs** (Configuration → Function URL → Delete)
3. **Optionally delete the functions** if you don't need them for follow-up experiments

If you keep them: total ongoing cost is ~$0 since they won't be invoked.

If you forget to disable provisioned concurrency: you'll pay ~$15/month for those 5 warm instances doing nothing.

---

## What to bring to our Sunday session

After you've run the experiment and pulled the data, bring:

1. **A small results table** — fill this in with your actual numbers:

| Scenario | Config | Invocations | Cold starts | p99 latency | Total cost |
|---|---|---|---|---|---|
| Low | On-demand | | | | |
| Low | Provisioned | | | | |
| Steady | On-demand | | | | |
| Steady | Provisioned | | | | |
| Bursty | On-demand | | | | |
| Bursty | Provisioned | | | | |

2. **The one thing that surprised you** — even if it's small. "I thought X but actual was Y."

3. **A screenshot of your most interesting CloudWatch chart** — anything visual we can use as a diagram source for the post.

With those three things, I can help you draft Cloud Cost Files #1 in under an hour on Sunday.

---

## Troubleshooting

**"My provisioned concurrency status stays IN_PROGRESS forever"**
- Check your account-level concurrent execution limit (default is 1,000). If you have other Lambda functions running, you may not have headroom for 5 provisioned. Solution: reduce to 2 provisioned, or request a limit increase.

**"My function URL returns 502"**
- Check function timeout is 30 sec (default is 3 sec, which may be too short with cold starts)
- Check the handler name matches your file (default is `index.handler` for Node.js)

**"Cost Explorer shows $0 even after 24 hours"**
- Tags can take up to 48 hours to populate in Cost Explorer the first time you use them
- Workaround: use Cost & Usage Report or check the actual billing dashboard for the experiment date

**"I'm worried about the cost"**
- Total experiment cost should be well under $1. The bigger risk is forgetting to disable provisioned concurrency. Set a calendar reminder for 24 hours after the experiment ends to verify it's off.

---

## Quick FYI on the broader post angle

Your eventual post (we'll draft Sunday) will likely structure as:

1. **Hook:** "I ran provisioned concurrency vs on-demand in my AWS account this week. After AWS started billing for INIT phases in Aug 2025, the math is different than most teams realize."
2. **The setup:** brief description of the experiment (1 paragraph)
3. **The data:** your table, possibly with a diagram
4. **The surprise:** whatever your actual data revealed that wasn't obvious
5. **The decision rule:** when to use provisioned, when not to, based on YOUR numbers
6. **The question:** "What's your provisioned concurrency strategy now? Anyone seen the same crossover point we did?"

This is a strong post because it has: real numbers, real account, recent regulatory context (the Aug 2025 billing change), original diagrams, a specific take. Exactly the senior-technical-creator format we identified in the research.

Get the data. Bring it to Sunday. We make it into the post.
