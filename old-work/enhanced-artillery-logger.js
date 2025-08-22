// enhanced-artillery-logger.js
const fs = require('fs');
const path = require('path');

// Initialize counters and storage
let requestCounter = 0;
let allResponses = [];
let startTime = Date.now();

// Create logs directory if it doesn't exist
const logsDir = './artillery-logs';
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Initialize CSV files with headers
const csvPath = path.join(logsDir, `test-run-${startTime}.csv`);
fs.writeFileSync(csvPath, 'RequestNumber,Timestamp,ResponseTime(ms),StatusCode,BodySize(bytes),Error,RequestStartTime,RequestEndTime\n');

// Initialize detailed JSON log
const jsonLogPath = path.join(logsDir, `detailed-responses-${startTime}.json`);
fs.writeFileSync(jsonLogPath, '[\n');

module.exports = {
  // beforeRequest hook to mark exact start time
  beforeRequest: function(requestParams, context, ee, next) {
    // Store the exact start time in the context
    context.vars._requestStartTime = Date.now();
    context.vars._requestStartHrTime = process.hrtime();
    return next();
  },

  // afterResponse hook to capture all response details
  afterResponse: function(requestParams, response, context, ee, next) {
    requestCounter++;
    
    // Calculate precise response time
    const endTime = Date.now();
    const endHrTime = process.hrtime(context.vars._requestStartHrTime);
    const responseTimeMs = Math.round((endHrTime[0] * 1000) + (endHrTime[1] / 1000000));
    
    // Parse response body safely
    let parsedBody = null;
    let bodySize = 0;
    try {
      if (typeof response.body === 'string') {
        parsedBody = JSON.parse(response.body);
        bodySize = Buffer.byteLength(response.body, 'utf8');
      } else {
        parsedBody = response.body;
        bodySize = JSON.stringify(response.body).length;
      }
    } catch (e) {
      parsedBody = response.body;
      bodySize = response.body ? response.body.length : 0;
    }
    
    // Create detailed log entry
    const logEntry = {
      requestNumber: requestCounter,
      timestamp: new Date().toISOString(),
      requestStartTime: new Date(context.vars._requestStartTime).toISOString(),
      requestEndTime: new Date(endTime).toISOString(),
      responseTimeMs: responseTimeMs,
      url: requestParams.url,
      method: requestParams.method || 'POST',
      statusCode: response.statusCode,
      headers: {
        request: requestParams.headers || {},
        response: response.headers || {}
      },
      bodySize: bodySize,
      requestBody: requestParams.json || requestParams.body,
      responseBody: parsedBody,
      metrics: {
        latency: response.timings ? response.timings.phases : null,
        totalTime: responseTimeMs
      }
    };
    
    // Store in memory for later analysis
    allResponses.push(logEntry);
    
    // Append to CSV
    const csvLine = `${requestCounter},${logEntry.timestamp},${responseTimeMs},${response.statusCode},${bodySize},,${logEntry.requestStartTime},${logEntry.requestEndTime}\n`;
    fs.appendFileSync(csvPath, csvLine);
    
    // Append to JSON log (with comma handling)
    const jsonLine = (requestCounter > 1 ? ',\n' : '') + JSON.stringify(logEntry, null, 2);
    fs.appendFileSync(jsonLogPath, jsonLine);
    
    // Console output for real-time monitoring
    console.log(`✓ Request #${requestCounter} completed`);
    console.log(`  └─ Status: ${response.statusCode} | Time: ${responseTimeMs}ms | Size: ${bodySize} bytes`);
    
    // Emit custom metrics for Artillery to capture
    ee.emit('counter', 'custom.requests.completed', 1);
    ee.emit('histogram', 'custom.response_time_individual', responseTimeMs);
    ee.emit('histogram', `custom.response_time_by_status.${response.statusCode}`, responseTimeMs);
    
    // Store individual request data in context for potential use
    context.vars[`request_${requestCounter}_time`] = responseTimeMs;
    context.vars[`request_${requestCounter}_status`] = response.statusCode;
    
    return next();
  },

  // afterScenario hook to capture scenario-level metrics
  afterScenario: function(context, ee, next) {
    const scenarioEndTime = Date.now();
    const scenarioDuration = scenarioEndTime - (context.vars._scenarioStartTime || scenarioEndTime);
    
    console.log(`📊 Scenario completed - Duration: ${scenarioDuration}ms`);
    
    return next();
  },

  // Custom function that can be called from scenarios
  logDetailedResponse: function(context, events, done) {
    // This function can access all stored request data
    const requestTimes = [];
    for (let i = 1; i <= requestCounter; i++) {
      if (context.vars[`request_${i}_time`]) {
        requestTimes.push(context.vars[`request_${i}_time`]);
      }
    }
    
    if (requestTimes.length > 0) {
      const avgTime = requestTimes.reduce((a, b) => a + b, 0) / requestTimes.length;
      console.log(`📈 Average response time for this VU: ${avgTime.toFixed(2)}ms`);
    }
    
    return done();
  },

  // Called when Artillery finishes
  cleanup: function(done) {
    // Close JSON array
    fs.appendFileSync(jsonLogPath, '\n]');
    
    // Generate summary report
    const summaryPath = path.join(logsDir, `summary-${startTime}.txt`);
    let summary = `Artillery Test Summary\n`;
    summary += `=====================\n\n`;
    summary += `Total Requests: ${requestCounter}\n`;
    summary += `Test Duration: ${((Date.now() - startTime) / 1000).toFixed(2)}s\n\n`;
    
    if (allResponses.length > 0) {
      // Calculate statistics
      const responseTimes = allResponses.map(r => r.responseTimeMs);
      const statusCodes = allResponses.map(r => r.statusCode);
      
      // Response time stats
      responseTimes.sort((a, b) => a - b);
      const min = Math.min(...responseTimes);
      const max = Math.max(...responseTimes);
      const avg = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
      const median = responseTimes[Math.floor(responseTimes.length / 2)];
      const p95 = responseTimes[Math.floor(responseTimes.length * 0.95)];
      const p99 = responseTimes[Math.floor(responseTimes.length * 0.99)];
      
      summary += `Response Time Statistics:\n`;
      summary += `  Min: ${min}ms\n`;
      summary += `  Max: ${max}ms\n`;
      summary += `  Avg: ${avg.toFixed(2)}ms\n`;
      summary += `  Median: ${median}ms\n`;
      summary += `  P95: ${p95}ms\n`;
      summary += `  P99: ${p99}ms\n\n`;
      
      // Status code distribution
      const statusDistribution = {};
      statusCodes.forEach(code => {
        statusDistribution[code] = (statusDistribution[code] || 0) + 1;
      });
      
      summary += `Status Code Distribution:\n`;
      Object.entries(statusDistribution).forEach(([code, count]) => {
        summary += `  ${code}: ${count} (${((count/requestCounter)*100).toFixed(2)}%)\n`;
      });
      
      // Individual request details
      summary += `\nIndividual Request Times:\n`;
      summary += `Request# | Time(ms) | Status\n`;
      summary += `---------|----------|-------\n`;
      allResponses.forEach((resp, idx) => {
        summary += `${String(idx + 1).padStart(8)} | ${String(resp.responseTimeMs).padStart(8)} | ${resp.statusCode}\n`;
      });
    }
    
    fs.writeFileSync(summaryPath, summary);
    
    console.log(`\n📁 Test results saved to: ${logsDir}/`);
    console.log(`  - Detailed JSON: ${path.basename(jsonLogPath)}`);
    console.log(`  - CSV data: ${path.basename(csvPath)}`);
    console.log(`  - Summary: ${path.basename(summaryPath)}`);
    
    return done();
  }
};