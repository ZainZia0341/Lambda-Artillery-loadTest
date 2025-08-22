// lambda-request-logger.js
const fs = require('fs');

let requestCount = 0;
const startTime = Date.now();

// Create CSV file with headers
const csvFile = `./lambda-requests-${startTime}.csv`;
fs.writeFileSync(csvFile, 'RequestNumber,Timestamp,ResponseTime(ms),StatusCode,URL,RequestId\n');

module.exports = {
  logRequest: function(requestParams, response, context, ee, next) {
    requestCount++;
    
    // Get response time
    const responseTime = response.timings ? 
      response.timings.phases.total : 
      (Date.now() - (context.vars._requestStartTime || Date.now()));
    
    // Try to get AWS request ID from headers
    const requestId = response.headers?.['x-amzn-requestid'] || 'N/A';
    
    // Log to CSV
    const csvLine = [
      requestCount,
      new Date().toISOString(),
      responseTime,
      response.statusCode,
      requestParams.url,
      requestId
    ].join(',') + '\n';
    
    fs.appendFileSync(csvFile, csvLine);
    
    // Console output
    const indicator = responseTime > 3000 ? '🔴' : responseTime > 2000 ? '🟡' : '🟢';
    console.log(`${indicator} Request #${requestCount}: ${responseTime}ms - Status: ${response.statusCode} - RequestId: ${requestId}`);
    
    // Also save response for debugging if needed
    if (response.statusCode !== 200) {
      const errorFile = `./lambda-error-${requestCount}.json`;
      fs.writeFileSync(errorFile, JSON.stringify({
        request: requestParams,
        response: {
          status: response.statusCode,
          headers: response.headers,
          body: response.body
        }
      }, null, 2));
      console.log(`   ⚠️  Error details saved to: ${errorFile}`);
    }
    
    return next();
  }
};