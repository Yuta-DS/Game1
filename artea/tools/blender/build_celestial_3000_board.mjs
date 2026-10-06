// Package the actual renders and measured data; no generated replacement imagery.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const scriptDir=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(scriptDir,'../..');
const out=path.join(root,'assets3D/mind_spark/celestial_terrace_3000');
const manifest=JSON.parse(fs.readFileSync(path.join(out,'parts_manifest.json'),'utf8'));
const report=JSON.parse(fs.readFileSync(path.join(out,'validation_report.json'),'utf8'));
const architecture=JSON.parse(fs.readFileSync(path.join(out,'architecture_audit.json'),'utf8'));
if(manifest.part_count!==3000)throw new Error('Wrong part count');
if(!report.passed||!architecture.passed)throw new Error('Unresolved geometry or connection audit');
if(architecture.source_sha256!==report.sha256.blend)throw new Error('Stale architecture audit');
for(const [key,file] of [['blend','source/celestial_terrace_3000.blend'],['glb','celestial_terrace_3000.glb']]){
 const hash=createHash('sha256').update(fs.readFileSync(path.join(out,file))).digest('hex');
 if(hash!==report.sha256[key])throw new Error('Stale validation report for '+key);
}
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
let html=fs.readFileSync(path.join(scriptDir,'celestial_3000_board.template.html'),'utf8');
const data=manifest.parts.map(p=>({i:p.id,n:p.name,f:p.family,t:p.triangles}));
const csvRows=fs.readFileSync(path.join(out,'parts_catalogue.csv'),'utf8').trim().split(/\r?\n/).length-1;
const uniqueNames=new Set(data.map(p=>p.n)).size;
const positiveDimensions=manifest.parts.every(p=>p.dimensions_m.every(d=>d>0));
if(csvRows!==3000||uniqueNames!==3000||!positiveDimensions)throw new Error('Invalid component data');
html=html.replace('%%TRIANGLES%%',manifest.triangles.toLocaleString())
 .replace('%%VERIFICATION%%',report.passed?`${report.checks.length} source/export checks passed.`:'Geometry verification has unresolved findings; see the report.')
 .replace('%%ARCHITECTURE%%',`${architecture.checks.length} geometry-based connection and component checks passed; not structural engineering certification.`)
 .replace('%%FAMILIES%%',Object.entries(manifest.allocation).map(([k,v])=>`<div class="family"><span>${escape(k.replaceAll('_',' '))}</span><strong>${v}</strong></div>`).join(''))
 .replace('%%OPTIONS%%',Object.keys(manifest.allocation).map(k=>`<option value="${escape(k)}">${escape(k.replaceAll('_',' '))}</option>`).join(''))
 .replace('%%DATA%%',JSON.stringify(data).replaceAll('<','\\u003c'));
const board=path.join(out,'asset_board.html');fs.writeFileSync(board,html);
if(process.argv.includes('--screenshot')){
 const require=createRequire('/Users/davidsovann/S2603/.anycreature-runtime/package.json');
 const {chromium}=require('playwright');
 const browser=await chromium.launch({headless:true,chromiumSandbox:true});
 const page=await browser.newPage({viewport:{width:1880,height:1280},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',error=>errors.push(String(error)));
 await page.goto('file://'+board);await page.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
 await page.locator('#board').screenshot({path:path.join(out,'previews/00_presentation_board.png')});
 await page.locator('summary').click();await page.locator('#search').fill('flywheel');
 const result=await page.locator('#results').textContent();
 if(!result.includes('3,000 total')||!await page.locator('#rows tr').count())throw new Error('Inventory search failed');
 await page.setViewportSize({width:390,height:844});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 if(overflow)throw new Error('Mobile board overflow');
 if(errors.length)throw new Error(errors.join('\n'));
 fs.writeFileSync(path.join(out,'board_validation.json'),JSON.stringify({passed:true,images_loaded:4,inventory_rows:data.length,csv_rows:csvRows,unique_part_names:uniqueNames,positive_dimensions:positiveDimensions,source_hashes_match:true,architecture_checks:architecture.checks.length,architecture_source_hash_matches:true,search_result:result,mobile_width:390,horizontal_overflow:false,page_errors:errors},null,2));
 await browser.close();
}
console.log(JSON.stringify({board,part_count:data.length,checks_passed:report.passed}));
