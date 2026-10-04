import { chromium } from './browser/node_modules/playwright/index.mjs';
import { readFile, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const evidence = '/home/node/.no-mistakes/evidence/01M4255Z93913VQ2VRJNN7CD28';
const browser = await chromium.launch({headless: true});
const summaries = [];
try {
  for (const version of ['101', '100']) {
    const file = `${evidence}/pi-${version}-calm-export.html`;
    const page = await browser.newPage({viewport: {width: 1440, height: 1100}});
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    // Only render the generated local export; prohibit outside requests.
    await page.route('http://**/*', route => route.abort());
    await page.route('https://**/*', route => route.abort());
    await page.goto(pathToFileURL(file).href);
    await page.getByText('The saved tool examples are complete.', {exact: true}).waitFor();
    const data = await page.locator('#session-data').evaluate(element => JSON.parse(atob(element.textContent.trim())));
    const expected = {
      call_grep: ['grep', 'sample.txt:1:CALM_LIVE_GREP'],
      call_find: ['find', 'CALM_LIVE_FIND.txt'],
      call_fm_watch_arm_pi: ['fm_watch_arm_pi', 'watcher: saved fixture arm result'],
    };
    const rendered = {};
    for (const [id, [name, result]] of Object.entries(expected)) {
      const row = data.renderedTools[id];
      assert.ok(row?.callHtml, `${version}: ${name} custom call HTML disappeared`);
      assert.ok(row?.resultHtmlExpanded, `${version}: ${name} custom result HTML disappeared`);
      const visible = await page.evaluate(({row}) => {
        const call = document.createElement('div'); call.innerHTML = row.callHtml;
        const result = document.createElement('div'); result.innerHTML = row.resultHtmlExpanded;
        return {call: call.textContent.trim(), result: result.textContent.trim()};
      }, {row});
      assert.ok(visible.call.includes(name), `${version}: custom call HTML lost tool name`);
      assert.ok(visible.result.includes(result), `${version}: custom result HTML lost tool output`);
      rendered[id] = visible;
    }
    const toolsButton = page.locator('[data-action="toggle-tools"]');
    if (await toolsButton.getAttribute('aria-pressed') !== 'true') await toolsButton.click();
    for (const [, [, result]] of Object.entries(expected)) {
      assert.ok(await page.getByText(result, {exact: true}).first().isVisible(), `${version}: ${result} missing from visible export`);
    }
    assert.deepEqual(errors, [], `${version}: HTML viewer JS errors`);
    const screenshot = `${evidence}/pi-${version}-calm-export.png`;
    await page.screenshot({path: screenshot, fullPage: true});
    const summary = {version, browser: browser.version(), file, screenshot, renderedTools: rendered, errors};
    summaries.push(summary);
    await writeFile(`${evidence}/pi-${version}-rendered-output.json`, JSON.stringify(summary, null, 2)+'\n');
    await page.close();
  }
  console.log(JSON.stringify(summaries, null, 2));
} finally {
  await browser.close();
}
