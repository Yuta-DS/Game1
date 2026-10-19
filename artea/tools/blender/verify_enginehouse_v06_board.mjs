import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const out=path.join(root,'assets3D/mind_spark/celestial_enginehouse_v06');
const report=JSON.parse(fs.readFileSync(path.join(out,'validation_report.json')));
if(!report.passed)throw Error('Unresolved model validation');
for(const [key,file] of [['blend','source/celestial_enginehouse_v06.blend'],['glb','celestial_enginehouse_v06.glb']]){
  if(createHash('sha256').update(fs.readFileSync(path.join(out,file))).digest('hex')!==report.sha256[key])throw Error('Stale '+key+' validation');
}
const require=createRequire('/Users/davidsovann/S2603/.anycreature-runtime/package.json');
const {chromium}=require('playwright');
const browser=await chromium.launch({headless:true,chromiumSandbox:true});
try{
  const page=await browser.newPage({viewport:{width:1740,height:1450}});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(pathToFileURL(path.join(out,'design_board.html')).href);
  await page.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
  const links=await page.locator('a').evaluateAll(aa=>aa.map(a=>a.getAttribute('href')));
  for(const link of links)if(!fs.existsSync(path.join(out,link)))throw Error('Missing local link '+link);
  await page.screenshot({path:path.join(out,'previews/00_design_board.png'),fullPage:true});
  await page.setViewportSize({width:390,height:844});
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
  if(errors.length||overflow)throw Error(JSON.stringify({errors,overflow}));
  const result={passed:true,images_loaded:2,local_links_checked:links.length,mobile_horizontal_overflow:false,
    page_errors:errors,model_validation_hashes_match:true};
  fs.writeFileSync(path.join(out,'board_validation.json'),JSON.stringify(result,null,2));
  console.log(JSON.stringify(result));
}finally{await browser.close();}
