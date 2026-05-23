/**
 * AWS Lambda Cost Experiment - Node.js Function
 * 
 * This function simulates realistic work with:
 * - Light CPU computation
 * - Simulated I/O delay
 * - Cold start detection
 */

export const handler = async (event) => {
    const start = Date.now();
    
    // Detect cold start
    const coldStart = !global.warm;
    global.warm = true;
    
    // Light CPU work - simulate computation
    let sum = 0;
    for (let i = 0; i < 100000; i++) {
        sum += Math.sqrt(i);
    }
    
    // Simulated I/O delay (50ms) - represents database query, API call, etc.
    await new Promise(resolve => setTimeout(resolve, 50));
    
    const duration = Date.now() - start;
    
    // Return detailed metrics
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            message: 'OK',
            sum: sum,
            duration_ms: duration,
            cold_start: coldStart,
            timestamp: new Date().toISOString(),
            runtime: 'nodejs22.x',
            memory_mb: parseInt(process.env.AWS_LAMBDA_FUNCTION_MEMORY_SIZE || '512'),
        }),
    };
};
