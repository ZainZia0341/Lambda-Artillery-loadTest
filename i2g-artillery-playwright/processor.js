// processor.js
module.exports = { completeUserFlow };

async function completeUserFlow(page, context, events, test) {
  page.setDefaultTimeout(60000);

  await page.goto('https://i2g.training/?simkey=geoff-db-test', { waitUntil: 'domcontentloaded' });

  // Get Started
  const getStarted = page.getByRole('button', { name: /get started/i });
  await getStarted.waitFor({ state: 'visible' });
  await getStarted.click();

  // Type into textarea (fire key events)
  const ta = page.locator('textarea.gwt-TextArea.input-box');
  await ta.waitFor({ state: 'visible' });
  const randomValue = Math.floor(Math.random() * 100) + 1;
  await ta.click();
  await ta.fill(String(randomValue));
  // If the app relies on keyup/change, ensure an extra key + blur:
  await ta.type(' ');            // triggers key events
  await page.keyboard.press('Backspace');
  await ta.evaluate(el => el.dispatchEvent(new Event('change', { bubbles: true })));

  // Wait for Next to become enabled (no :has-text() inside the page function)
  const nextBtn = page.getByRole('button', { name: /^Next$/ });
  await nextBtn.waitFor({ state: 'visible' });
  const nextHandle = await nextBtn.elementHandle();
  await page.waitForFunction(el => el && !el.disabled, nextHandle, { timeout: 45000 });
  await nextBtn.click();

  // Arm the network wait BEFORE clicking Replay to avoid races
  const waitLoadSim = page.waitForResponse(
    res => res.url().includes('/com.insightxp.i2g.I2g/loadSim') && res.status() === 200,
    { timeout: 20000 }
  );

  const replayBtn = page.getByRole('button', { name: /^Replay$/ });
  await replayBtn.waitFor({ state: 'visible' });
  await replayBtn.click();

  const response = await waitLoadSim;
  console.log('loadSim response status:', response.status());

  console.log(`User completed flow with value: ${randomValue}`);
}
