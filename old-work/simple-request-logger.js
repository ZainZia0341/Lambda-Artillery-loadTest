// simple-request-logger.js
const fs = require('fs');

let requestCount = 0;
const startTime = Date.now();

// Create CSV file with headers
const csvFile = `./request-metrics-${startTime}.csv`;
fs.writeFileSync(csvFile, 'RequestNumber,Timestamp,ResponseTime(ms),StatusCode,URL\n');

module.exports = {
  logRequest: function(requestParams, response, context, ee, next) {
    requestCount++;
    
    // Get response time from Artillery context
    const responseTime = response.timings ? 
      response.timings.phases.firstByte : 
      (Date.now() - (context.vars._requestStartTime || Date.now()));
    
    // Log to CSV
    const csvLine = [
      requestCount,
      new Date().toISOString(),
      responseTime,
      response.statusCode,
      requestParams.url
    ].join(',') + '\n';
    
    fs.appendFileSync(csvFile, csvLine);
    
    // Console output
    console.log(`Request #${requestCount}: ${responseTime}ms - Status: ${response.statusCode}`);
    
    return next();
  }
};