// view-lambda-responses.js
const fs = require('fs');
const path = require('path');

// Find the most recent test directory
const testDirs = fs.readdirSync('.').filter(f => f.startsWith('lambda-test-') && fs.statSync(f).isDirectory());
if (testDirs.length === 0) {
  console.log('No test results found!');
  process.exit(1);
}

// Sort by timestamp (newest first)
testDirs.sort((a, b) => {
  const timeA = parseInt(a.split('-')[2]);
  const timeB = parseInt(b.split('-')[2]);
  return timeB - timeA;
});

const latestTestDir = testDirs[0];
console.log(`\n📁 Viewing results from: ${latestTestDir}`);
console.log('═'.repeat(60));

// Load summary
const summaryPath = path.join(latestTestDir, 'test-summary.json');
const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf8'));

console.log(`\n📊 Test Summary:`);
console.log(`├─ Test Run ID: ${summary.testRunId}`);
console.log(`├─ Start Time: ${summary.startTime}`);
console.log(`├─ End Time: ${summary.endTime}`);
console.log(`├─ Total Requests: ${summary.totalRequests}`);
console.log(`├─ Successful: ${summary.successCount}`);
console.log(`└─ Errors: ${summary.errorCount}`);

// Load CSV for quick overview
console.log(`\n📈 Request Overview:`);
console.log('═'.repeat(80));
const csvPath = path.join(latestTestDir, 'request-summary.csv');
const csvContent = fs.readFileSync(csvPath, 'utf8');
const lines = csvContent.trim().split('\n');

// Display CSV header and first few requests
console.log('Req# | Response Time | Status | AWS Request ID');
console.log('-----|---------------|--------|---------------');

lines.slice(1, 6).forEach(line => {
  const [num, timestamp, time, status, url, requestId] = line.split(',');
  console.log(`${num.padStart(4)} | ${time.padStart(12)}ms | ${status.padStart(6)} | ${requestId}`);
});

if (lines.length > 6) {
  console.log(`... and ${lines.length - 6} more requests`);
}

// Show response time statistics
const responseTimes = lines.slice(1).map(line => parseInt(line.split(',')[2])).sort((a, b) => a - b);
console.log(`\n⏱️  Response Time Statistics:`);
console.log(`├─ Min: ${Math.min(...responseTimes)}ms`);
console.log(`├─ Max: ${Math.max(...responseTimes)}ms`);
console.log(`├─ Avg: ${(responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length).toFixed(0)}ms`);
console.log(`└─ P95: ${responseTimes[Math.floor(responseTimes.length * 0.95)]}ms`);

// Display sample responses
console.log(`\n📝 Sample Responses:`);
console.log('═'.repeat(80));

const responsesDir = path.join(latestTestDir, 'responses');
const responseFiles = fs.readdirSync(responsesDir).slice(0, 3);

responseFiles.forEach(file => {
  const responseData = JSON.parse(fs.readFileSync(path.join(responsesDir, file), 'utf8'));
  console.log(`\n🔹 ${file}:`);
  console.log(`Time: ${responseData.responseTime}ms | Status: ${responseData.statusCode}`);
  
  if (responseData.response && responseData.response.evaluation) {
    console.log(`Response: "${responseData.response.evaluation.substring(0, 150)}..."`);
  }
});

console.log(`\n💡 To view a specific response, open: ${latestTestDir}/responses/response-X.json`);
console.log(`💡 To view all data in a spreadsheet, open: ${latestTestDir}/request-summary.csv`);

// Show any errors
const errorsDir = path.join(latestTestDir, 'errors');
if (fs.existsSync(errorsDir)) {
  const errorFiles = fs.readdirSync(errorsDir);
  if (errorFiles.length > 0) {
    console.log(`\n⚠️  Errors found: ${errorFiles.length}`);
    console.log(`View error details in: ${errorsDir}/`);
  }
}