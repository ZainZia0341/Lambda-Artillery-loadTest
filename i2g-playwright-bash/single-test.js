// single-test.js - Single test execution for bash script
const { chromium } = require('playwright');

async function runTest() {
  const instanceId = process.argv[2] || 'unknown';
  const browser = await chromium.launch({ 
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'] // For running in containers
  });
  
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    const startTime = Date.now();
    
    // Navigate to the starting point
    await page.goto('https://i2g.training/?simkey=geoff-db-test', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    // Click Get Started button
    await page.waitForSelector('button:has-text("Get Started")', { timeout: 10000 });
    await page.click('button:has-text("Get Started")');


    
    // Enter random value
    // await page.waitForSelector('textarea.gwt-TextArea.input-box', { timeout: 10000 });
    // const randomValue = Math.floor(Math.random() * 100) + 1;
    // await page.fill('textarea.gwt-TextArea.input-box', randomValue.toString());




    // --- Enter random value (with extra key/blur to trigger any listeners) ---
    const ta = page.locator('textarea.gwt-TextArea.input-box');
    await ta.waitFor({ state: 'visible', timeout: 10000 });

    const randomValue = Math.floor(Math.random() * 100) + 1;
    await ta.click();
    await ta.fill(String(randomValue));

    // If the app relies on keyup/change, ensure an extra key + backspace
    await ta.type(' ');
    await page.keyboard.press('Backspace');



    // Click Next button
    await page.waitForSelector('button:has-text("Next")', { timeout: 10000 });
    await page.click('button:has-text("Next")');

    // Setup request monitoring
    const loadSimPromise = page.waitForResponse(
      response => response.url().includes('/com.insightxp.i2g.I2g/loadSim') && response.status() === 200,
      { timeout: 15000 }
    );

    // Click Replay button
    await page.waitForSelector('button:has-text("Replay")', { timeout: 10000 });
    await page.click('button:has-text("Replay")');

    // Wait for the loadSim request
    await loadSimPromise;
    
    const duration = Date.now() - startTime;
    console.log(`[${new Date().toISOString()}] Instance ${instanceId}: Test completed in ${duration}ms with value ${randomValue}`);
    
    await browser.close();
    process.exit(0);
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Instance ${instanceId}: Test failed - ${error.message}`);
    await browser.close();
    process.exit(1);
  }
}

runTest();