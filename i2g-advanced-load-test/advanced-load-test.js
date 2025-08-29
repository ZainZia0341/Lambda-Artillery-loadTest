// advanced-load-test.js - Advanced load testing with metrics
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

class LoadTestMetrics {
  constructor() {
    this.results = [];
    this.startTime = Date.now();
    this.successful = 0;
    this.failed = 0;
    this.inProgress = 0;
    this.responseTimes = [];
  }

  addResult(result) {
    this.results.push(result);
    if (result.success) {
      this.successful++;
      this.responseTimes.push(result.duration);
    } else {
      this.failed++;
    }
  }

  getStats() {
    const now = Date.now();
    const elapsedSeconds = (now - this.startTime) / 1000;
    const avgResponseTime = this.responseTimes.length > 0
      ? this.responseTimes.reduce((a, b) => a + b, 0) / this.responseTimes.length
      : 0;
    
    const sortedTimes = [...this.responseTimes].sort((a, b) => a - b);
    const p50 = sortedTimes[Math.floor(sortedTimes.length * 0.5)] || 0;
    const p95 = sortedTimes[Math.floor(sortedTimes.length * 0.95)] || 0;
    const p99 = sortedTimes[Math.floor(sortedTimes.length * 0.99)] || 0;

    return {
      elapsed: elapsedSeconds.toFixed(1),
      total: this.results.length,
      successful: this.successful,
      failed: this.failed,
      inProgress: this.inProgress,
      successRate: ((this.successful / (this.successful + this.failed)) * 100).toFixed(2),
      rps: (this.results.length / elapsedSeconds).toFixed(2),
      avgResponseTime: avgResponseTime.toFixed(0),
      p50: p50.toFixed(0),
      p95: p95.toFixed(0),
      p99: p99.toFixed(0)
    };
  }

  printStats() {
    const stats = this.getStats();
    console.clear();
    console.log('╔════════════════════════════════════════════════════╗');
    console.log('║           LOAD TEST REAL-TIME METRICS             ║');
    console.log('╠════════════════════════════════════════════════════╣');
    console.log(`║ Elapsed Time:     ${stats.elapsed.padEnd(32)}s ║`);
    console.log(`║ Total Requests:   ${stats.total.toString().padEnd(32)}  ║`);
    console.log(`║ Successful:       ${stats.successful.toString().padEnd(32)}  ║`);
    console.log(`║ Failed:           ${stats.failed.toString().padEnd(32)}  ║`);
    console.log(`║ In Progress:      ${stats.inProgress.toString().padEnd(32)}  ║`);
    console.log(`║ Success Rate:     ${(stats.successRate + '%').padEnd(32)}  ║`);
    console.log(`║ Requests/sec:     ${stats.rps.padEnd(32)}  ║`);
    console.log('╠════════════════════════════════════════════════════╣');
    console.log('║              RESPONSE TIME METRICS                ║');
    console.log('╠════════════════════════════════════════════════════╣');
    console.log(`║ Average:          ${(stats.avgResponseTime + 'ms').padEnd(32)} ║`);
    console.log(`║ P50 (Median):     ${(stats.p50 + 'ms').padEnd(32)} ║`);
    console.log(`║ P95:              ${(stats.p95 + 'ms').padEnd(32)} ║`);
    console.log(`║ P99:              ${(stats.p99 + 'ms').padEnd(32)} ║`);
    console.log('╚════════════════════════════════════════════════════╝');
  }

  saveReport(filename = 'load-test-report.json') {
    const report = {
      summary: this.getStats(),
      results: this.results,
      timestamp: new Date().toISOString()
    };
    fs.writeFileSync(filename, JSON.stringify(report, null, 2));
    console.log(`\nReport saved to ${filename}`);
  }
}

class LoadTestRunner {
  constructor(config = {}) {
    this.config = {
      concurrency: config.concurrency || 10,
      duration: config.duration || 60, // seconds
      rampUp: config.rampUp || 5, // seconds to reach full concurrency
      headless: config.headless !== false,
      timeout: config.timeout || 30000,
      ...config
    };
    this.metrics = new LoadTestMetrics();
    this.stopFlag = false;
    this.activeTests = new Set();
  }

  async runSingleTest(userId) {
    const testId = `user_${userId}_${Date.now()}`;
    this.activeTests.add(testId);
    this.metrics.inProgress++;

    const browser = await chromium.launch({ 
      headless: this.config.headless,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    try {
      const context = await browser.newContext({
        // Add custom headers if needed
        extraHTTPHeaders: {
          'X-Test-ID': testId
        }
      });
      
      const page = await context.newPage();
      const startTime = Date.now();
      
      // Set up network monitoring
      const requests = [];
      page.on('request', request => {
        if (request.url().includes('/loadSim')) {
          requests.push({
            url: request.url(),
            method: request.method(),
            timestamp: Date.now()
          });
        }
      });

      // Navigate to the starting point
      await page.goto('https://i2g.training/?simkey=geoff-db-test', {
        waitUntil: 'networkidle',
        timeout: this.config.timeout
      });

      // Click Get Started button
      await page.waitForSelector('button:has-text("Get Started")', { 
        timeout: this.config.timeout 
      });
      await page.click('button:has-text("Get Started")');

        // After clicking "Get Started"...
        const ta = page.locator('textarea.gwt-TextArea.input-box');
        await ta.waitFor({ state: 'visible', timeout: this.config.timeout });

        const randomValue = Math.floor(Math.random() * 100) + 1;
        await ta.click();
        await ta.fill(String(randomValue));
        // trigger keyup/change listeners
        await ta.type(' ');
        await page.keyboard.press('Backspace');

        // Wait for enabled Next & click
        const next = page.locator('button:has-text("Next"):not([disabled])');
        await next.waitFor({ state: 'visible', timeout: this.config.timeout });
        await next.click();

      // Setup response monitoring for loadSim
      const loadSimPromise = page.waitForResponse(
        response => response.url().includes('/com.insightxp.i2g.I2g/loadSim'),
        { timeout: this.config.timeout }
      );

      // Click Replay button
      await page.waitForSelector('button:has-text("Replay")', { 
        timeout: this.config.timeout 
      });
      await page.click('button:has-text("Replay")');

      // Wait for the loadSim response
      const response = await loadSimPromise;
      const responseStatus = response.status();
      
      const duration = Date.now() - startTime;
      
      this.metrics.addResult({
        testId,
        userId,
        success: responseStatus === 200,
        duration,
        value: randomValue,
        statusCode: responseStatus,
        timestamp: new Date().toISOString(),
        requests: requests.length
      });

    } catch (error) {
      this.metrics.addResult({
        testId,
        userId,
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      });
    } finally {
      await browser.close();
      this.activeTests.delete(testId);
      this.metrics.inProgress--;
    }
  }

  async runVirtualUser(userId) {
    while (!this.stopFlag) {
      await this.runSingleTest(userId);
      // Small delay between iterations
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }

  async start() {
    console.log(`Starting load test with ${this.config.concurrency} virtual users`);
    console.log(`Test duration: ${this.config.duration} seconds`);
    console.log(`Ramp-up period: ${this.config.rampUp} seconds\n`);

    const users = [];
    const rampUpDelay = (this.config.rampUp * 1000) / this.config.concurrency;

    // Start monitoring
    const monitorInterval = setInterval(() => {
      this.metrics.printStats();
    }, 1000);

    // Gradually start virtual users (ramp-up)
    for (let i = 0; i < this.config.concurrency; i++) {
      users.push(this.runVirtualUser(i + 1));
      if (i < this.config.concurrency - 1) {
        await new Promise(resolve => setTimeout(resolve, rampUpDelay));
      }
    }

    // Run for specified duration
    await new Promise(resolve => setTimeout(resolve, this.config.duration * 1000));

    // Stop all users
    console.log('\n\nStopping virtual users...');
    this.stopFlag = true;

    // Wait for all users to complete their current test
    await Promise.all(users);

    // Wait for any remaining active tests
    while (this.activeTests.size > 0) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    // Stop monitoring
    clearInterval(monitorInterval);

    // Print final stats
    this.metrics.printStats();
    
    // Save report
    this.metrics.saveReport();
  }
}

// Command line interface
async function main() {
  const args = process.argv.slice(2);
  
  const config = {
    concurrency: parseInt(args[0]) || 10,
    duration: parseInt(args[1]) || 60,
    rampUp: parseInt(args[2]) || 5,
    headless: args[3] !== 'false'
  };

  console.log('Load Test Configuration:');
  console.log(JSON.stringify(config, null, 2));
  console.log('\n');

  const runner = new LoadTestRunner(config);
  
  try {
    await runner.start();
  } catch (error) {
    console.error('Load test failed:', error);
    process.exit(1);
  }
}

// Run the test
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { LoadTestRunner, LoadTestMetrics };