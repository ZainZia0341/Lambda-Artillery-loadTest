// lambda-logger-with-responses.js
const fs = require('fs');
const path = require('path');

let requestCount = 0;
const testRunId = Date.now();

// Create directories for this test run
const testDir = `./lambda-test-${testRunId}`;
const responsesDir = path.join(testDir, 'responses');
const errorsDir = path.join(testDir, 'errors');

// Create directories
[testDir, responsesDir, errorsDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Create CSV file with headers
const csvFile = path.join(testDir, 'request-summary.csv');
fs.writeFileSync(csvFile, 'RequestNumber,Timestamp,ResponseTime(ms),StatusCode,URL,RequestId,ResponseFile\n');

// Create a summary JSON file
const summaryFile = path.join(testDir, 'test-summary.json');
const testSummary = {
  testRunId: testRunId,
  startTime: new Date().toISOString(),
  requests: []
};

module.exports = {
  logRequest: function(requestParams, response, context, ee, next) {
    requestCount++;
    const timestamp = new Date().toISOString();
    
    // Get response time
    const responseTime = response.timings ? 
      response.timings.phases.total : 
      (Date.now() - (context.vars._requestStartTime || Date.now()));
    
    // Get AWS request ID from headers
    const requestId = response.headers?.['x-amzn-requestid'] || 'N/A';
    const traceId = response.headers?.['x-amzn-trace-id'] || 'N/A';
    
    // Parse response body
    let responseBody;
    try {
      responseBody = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
    } catch (e) {
      responseBody = response.body;
    }
    
    // Save individual response
    const responseFileName = `response-${requestCount}.json`;
    const responseFilePath = path.join(responsesDir, responseFileName);
    
    const fullResponseData = {
      requestNumber: requestCount,
      timestamp: timestamp,
      responseTime: responseTime,
      statusCode: response.statusCode,
      headers: {
        request: requestParams.headers || {},
        response: response.headers || {}
      },
      request: {
        url: requestParams.url,
        method: requestParams.method || 'POST',
        body: requestParams.json || requestParams.body
      },
      response: responseBody,
      aws: {
        requestId: requestId,
        traceId: traceId
      }
    };
    
    // Save full response data
    fs.writeFileSync(responseFilePath, JSON.stringify(fullResponseData, null, 2));
    
    // Log to CSV
    const csvLine = [
      requestCount,
      timestamp,
      responseTime,
      response.statusCode,
      requestParams.url,
      requestId,
      responseFileName
    ].join(',') + '\n';
    
    fs.appendFileSync(csvFile, csvLine);
    
    // Update summary
    testSummary.requests.push({
      number: requestCount,
      timestamp: timestamp,
      responseTime: responseTime,
      statusCode: response.statusCode,
      responseFile: responseFileName
    });
    
    // Console output
    const indicator = responseTime > 3000 ? '🔴' : responseTime > 2000 ? '🟡' : '🟢';
    console.log(`${indicator} Request #${requestCount}: ${responseTime}ms - Status: ${response.statusCode}`);
    
    // Show response preview
    if (responseBody && responseBody.evaluation) {
      console.log(`   📝 Response preview: "${responseBody.evaluation.substring(0, 100)}..."`);
    }
    
    // Save errors separately
    if (response.statusCode !== 200) {
      const errorFile = path.join(errorsDir, `error-${requestCount}.json`);
      fs.writeFileSync(errorFile, JSON.stringify(fullResponseData, null, 2));
      console.log(`   ⚠️  Error saved to: ${errorFile}`);
    }
    
    // Save updated summary
    testSummary.endTime = new Date().toISOString();
    testSummary.totalRequests = requestCount;
    testSummary.successCount = testSummary.requests.filter(r => r.statusCode === 200).length;
    testSummary.errorCount = testSummary.requests.filter(r => r.statusCode !== 200).length;
    fs.writeFileSync(summaryFile, JSON.stringify(testSummary, null, 2));
    
    return next();
  }
};