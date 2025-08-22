// enhanced-response-logger.js
const fs = require('fs');

// Global counter for request numbering
let requestCounter = 0;
let allResponses = [];

module.exports = {
  logResponse: function(context, events, done) {
    requestCounter++;
    const response = context.vars.fullResponse;
    
    if (response) {
      const responseTime = context._lastResponseTime || 'N/A';
      
      const logEntry = {
        requestNumber: requestCounter,
        timestamp: new Date().toISOString(),
        url: context._target + '/staging/invoke-claude',
        statusCode: response.statusCode || 'N/A',
        responseTime: responseTime,
        headers: response.headers || {},
        body: response.body || response
      };
      
      // Store in memory for later analysis
      allResponses.push(logEntry);
      
      // Write detailed log
      const logLine = `REQUEST #${requestCounter}\n` + 
                     JSON.stringify(logEntry, null, 2) + '\n' + 
                     '='.repeat(80) + '\n';
      fs.appendFileSync('./detailed-responses.log', logLine);
      
      // Write summary line for easy parsing
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
    }
    
    return done();
  },
  
  // Optional: Add a cleanup function to save final summary
  cleanup: function() {
    if (allResponses.length > 0) {
      const summary = {
        totalRequests: allResponses.length,
        averageResponseTime: allResponses.reduce((sum, r) => sum + (r.responseTime || 0), 0) / allResponses.length,
        minResponseTime: Math.min(...allResponses.map(r => r.responseTime || 0)),
        maxResponseTime: Math.max(...allResponses.map(r => r.responseTime || 0)),
        requestDetails: {
          first: allResponses[0] || null,
          tenth: allResponses[9] || null,
          fortyfifth: allResponses[44] || null
        }
      };
      
      fs.writeFileSync('./test-summary.json', JSON.stringify(summary, null, 2));
      console.log('📊 Test summary saved to test-summary.json');
    }
  }
};