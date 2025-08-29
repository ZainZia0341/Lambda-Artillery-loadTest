// playwright-load-test.js
const { chromium } = require('playwright');

async function runSingleTest(testId) {
  const browser = await chromium.launch({ 
    headless: true // Set to false to see the browser
  });
  
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    const startTime = Date.now();
    
    // Navigate to the starting point
    await page.goto('https://i2g.training/?simkey=geoff-db-test', {
      waitUntil: 'networkidle'
    });

    // Click Get Started button
    await page.waitForSelector('button:has-text("Get Started")', { timeout: 10000 });
    await page.click('button:has-text("Get Started")');

    // --- Enter random value (with extra key/blur to trigger any listeners) ---
    const ta = page.locator('textarea.gwt-TextArea.input-box');
    await ta.waitFor({ state: 'visible', timeout: 10000 });

    const randomValue = Math.floor(Math.random() * 100) + 1;
    await ta.click();
    await ta.fill(String(randomValue));

    // If the app relies on keyup/change, ensure an extra key + backspace
    await ta.type(' ');
    await page.keyboard.press('Backspace');

    // --- Wait until the Next button is actually enabled, then click ---
    const next = page.locator('button:has-text("Next"):not([disabled])');
    await next.waitFor({ state: 'visible', timeout: 30000 });

    // (Optional: tiny poll to avoid “not stable” due to animations)
    for (let i = 0; i < 20; i++) {
      if (await next.isEnabled()) break;
      await page.waitForTimeout(250);
    }
    await next.click();

    // Setup request monitoring for the loadSim endpoint
    const loadSimPromise = page.waitForResponse(
      response => response.url().includes('/com.insightxp.i2g.I2g/loadSim') && response.status() === 200
    );

    // Click Replay button
    await page.waitForSelector('button:has-text("Replay")', { timeout: 10000 });
    await page.click('button:has-text("Replay")');

    // Wait for the loadSim request
    const response = await loadSimPromise;
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    console.log(`[Test ${testId}] ✓ Completed in ${duration}ms with value: ${randomValue}`);
    
    return { success: true, duration, value: randomValue };
  } catch (error) {
    console.error(`[Test ${testId}] ✗ Failed:`, error.message);
    return { success: false, error: error.message };
  } finally {
    await browser.close();
  }
}

async function runConcurrentTests(concurrency = 5, totalTests = 20) {
  console.log(`Starting load test: ${totalTests} total tests with ${concurrency} concurrent users`);
  const startTime = Date.now();
  
  const results = [];
  let completed = 0;
  
  // Create batches
  for (let i = 0; i < totalTests; i += concurrency) {
    const batch = [];
    const batchSize = Math.min(concurrency, totalTests - i);
    
    for (let j = 0; j < batchSize; j++) {
      batch.push(runSingleTest(i + j + 1));
    }
    
    // Wait for batch to complete
    const batchResults = await Promise.all(batch);
    results.push(...batchResults);
    completed += batchSize;
    
    console.log(`Progress: ${completed}/${totalTests} tests completed`);
  }
  
  // Calculate statistics
  const endTime = Date.now();
  const totalDuration = endTime - startTime;
  const successful = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;
  const avgDuration = results
    .filter(r => r.success)
    .reduce((sum, r) => sum + r.duration, 0) / successful;
  
  console.log('\n=== Load Test Results ===');
  console.log(`Total Duration: ${totalDuration}ms`);
  console.log(`Total Tests: ${totalTests}`);
  console.log(`Successful: ${successful}`);
  console.log(`Failed: ${failed}`);
  console.log(`Average Test Duration: ${avgDuration.toFixed(2)}ms`);
  console.log(`Requests per second: ${(totalTests / (totalDuration / 1000)).toFixed(2)}`);
}

// Run with command line arguments or defaults
const concurrency = parseInt(process.argv[2]) || 5;
const totalTests = parseInt(process.argv[3]) || 20;

runConcurrentTests(concurrency, totalTests).catch(console.error);