const {chromium}=require('./visual/node_modules/playwright');
const fs=require('node:fs');
(async()=>{
 const E='/home/node/.no-mistakes/evidence/01M467Y2KVPY0ZYM8V5V6DQB86';
 const browser=await chromium.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 try{
  const context=await browser.newContext({viewport:{width:1440,height:1100},offline:true});
  const page=await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`file://${E}/native-pi101-calm-export.html`);
  await page.waitForTimeout(800);
  await page.screenshot({path:`${E}/native-pi101-calm-export.png`,fullPage:true});
  console.log('Rendered native Pi 1.0.1 export:');
  console.log(await page.locator('body').innerText());
  console.log('Clickable export controls:',await page.locator('button').allTextContents());
  if(errors.length)throw new Error(errors.join('\n'));
  const text=await page.locator('body').innerText();
  if(!text.includes('The real grep, find and watcher checks are complete.'))throw new Error('Export lost the final conversation');
  if(!text.includes('grep') || !text.includes('find') || !text.includes('fm_watch_arm_pi'))throw new Error('Export lost a stock tool renderer');
  if(text.includes('Tool not found'))throw new Error('Export renderer lookup failed');
  await page.goto(`file://${E}/pi-retry-repeated.html`);
  await page.waitForTimeout(800);
  await page.screenshot({path:`${E}/pi-retry-repeated.png`,fullPage:true});
  console.log('Rendered retry transcript:');
  const retry=await page.locator('body').innerText();console.log(retry);
  const replies=await page.locator('main .assistant-text').allTextContents();
  if(replies.filter(s=>s.trim()==='The example task needs a decision.').length!==1)throw new Error('An exact-repeat retry appears more than once in the conversation');
  console.log('Conversation assistant replies:',JSON.stringify(replies));
  if(!retry.includes('The new user answer.'))throw new Error('Next user answer disappeared');
  await context.close();
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
