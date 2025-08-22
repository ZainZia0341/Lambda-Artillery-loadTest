// fixed-response-logger.js
const fs = require('fs');

let requestCounter = 0;
let allResponses = [];

module.exports = {
  // Use afterResponse hook to capture actual response times
  afterResponse: function(requestParams, response, context, ee, next) {
    requestCounter++;
    
    // Calculate response time from the context
    const startTime = context._startedAt || Date.now();
    const endTime = Date.now();
    const responseTime = endTime - startTime;
    
    const logEntry = {
      requestNumber: requestCounter,
      timestamp: new Date().toISOString(),
      url: requestParams.url,
      method: requestParams.method || 'POST',
      statusCode: response.statusCode,
      responseTime: responseTime,
      headers: response.headers || {},
      body: response.body,
      requestBody: requestParams.json || requestParams.body
    };
    
    // Store in memory
    allResponses.push(logEntry);
    
    // Write detailed log
    const logLine = `REQUEST #${requestCounter}\n` + 
                   JSON.stringify(logEntry, null, 2) + '\n' + 
                   '='.repeat(80) + '\n';
    fs.appendFileSync('./detailed-responses.log', logLine);
    
    // Write CSV summary
    const summaryLine = `${requestCounter},${responseTime},${logEntry.statusCode},${logEntry.timestamp}\n`;
    fs.appendFileSync('./response-times.csv', summaryLine);
    
    console.log(`✓ Request #${requestCounter} logged - Status: ${logEntry.statusCode}, Time: ${responseTime}ms`);
    console.log(`✓ Response preview: ${JSON.stringify(logEntry.body).substring(0, 200)}...`);
    
    // Log specific requests you're interested in
    if (requestCounter === 1 || requestCounter === 10 || requestCounter === 45) {
      console.log(`🎯 SPECIAL REQUEST #${requestCounter} - Response Time: ${responseTime}ms`);
      const specialLog = `SPECIAL REQUEST #${requestCounter} - Response Time: ${responseTime}ms\n` +
                        JSON.stringify(logEntry, null, 2) + '\n' + '🎯'.repeat(80) + '\n';
      fs.appendFileSync('./special-requests.log', specialLog);
    }
    
    return next();
  },
  
  // Keep the original logResponse for compatibility, but make it simpler
  logResponse: function(context, events, done) {
    // This is just for compatibility - the real work happens in afterResponse
    return done();
  }
};