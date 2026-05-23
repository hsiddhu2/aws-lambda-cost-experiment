"""
AWS Lambda Cost Experiment - Python Function

This function simulates realistic work with:
- Light CPU computation
- Simulated I/O delay
- Cold start detection
"""

import json
import math
import time
import os

# Global variable to track warm starts
is_warm = False


def lambda_handler(event, context):
    """
    Lambda handler function that performs light computation and tracks cold starts.
    
    Args:
        event: Lambda event object
        context: Lambda context object
        
    Returns:
        dict: Response with status code and metrics
    """
    global is_warm
    
    start_time = time.time()
    
    # Detect cold start
    cold_start = not is_warm
    is_warm = True
    
    # Light CPU work - simulate computation
    total = 0
    for i in range(100000):
        total += math.sqrt(i)
    
    # Simulated I/O delay (50ms) - represents database query, API call, etc.
    time.sleep(0.05)
    
    duration_ms = int((time.time() - start_time) * 1000)
    
    # Return detailed metrics
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
        },
        'body': json.dumps({
            'message': 'OK',
            'sum': total,
            'duration_ms': duration_ms,
            'cold_start': cold_start,
            'timestamp': time.strftime('%Y-%m-%dT%H:%M:%S'),
            'runtime': 'python3.13',
            'memory_mb': int(os.environ.get('AWS_LAMBDA_FUNCTION_MEMORY_SIZE', '512')),
        })
    }
