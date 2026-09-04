// Reuse the hardened AnyCreature offline showroom without changing the plugin.
// No upload pack, license changes, author signature, or provenance rewriting.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const out = path.dirname(fileURLToPath(import.meta.url));
const assets = '/Users/davidsovann/.codex/plugins/cache/personal/anycreature/1.2.0+codex.local.20260828/toolkit/harness/assets';
let page = fs.readFileSync(path.join(assets,'showroom.html'),'utf8');
function replace(from,to) {
  if (!page.includes(from)) throw new Error('Showroom template changed: '+from);
  page=page.replace(from,to);
}
replace('const clips=g.animations||[];', `const names=['Milo_Redesign_Idle','Milo_Redesign_Welcome','Milo_Redesign_Listen','Milo_Walking'];
  const clips=names.map(name=>(g.animations||[]).find(c=>c.name===name)).filter(Boolean);`);
replace('if(o.isMesh){ o.castShadow=true; o.receiveShadow=true; }', `if(o.isMesh){ o.castShadow=true; o.receiveShadow=true;
      o.visible=!/^(EyelidHalf|EyelidClosed|MouthOpen|Tongue)/.test(o.name); }`);
replace("const play=()=>{ mixer.stopAllAction();", `const play=()=>{ mixer.stopAllAction();
    document.getElementById('clip-label').textContent=order[ix].replaceAll('_',' ');`);
replace('if(clips.length){ mixer.clipAction(clips[0]).play(); }', `if(clips.length){ mixer.clipAction(clips[0]).play();
    document.getElementById('clip-label').textContent=clips[0].name.replaceAll('_',' '); }`);
replace('edges.forEach(l=>{l.visible=on;});', 'edges.forEach(l=>{l.visible=false;});');
replace('title="Hard-edge clay"', 'title="Clay material"');
replace('padding:0 32px 16vh', 'padding:0 32px 5vh');
replace('<div class="hint">drag to orbit · wheel to zoom</div>', `<div class="hint">drag to orbit · wheel to zoom · top button cycles 4 clips<br><span id="clip-label">Loading Milo…</span><br>Review only · no runtime terrain IK in this viewer</div>`);
page=page.replaceAll('__TITLE__','Milo · Counsellor')
 .replaceAll('__BYLINE__','Local redesign · AnyCreature + Blender · not deployed')
 .replace('__BUNDLE__',fs.readFileSync(path.join(assets,'three-bundle.js'),'utf8'))
 .replace('__B64__',fs.readFileSync(path.join(out,'milo_redesign.glb')).toString('base64'));
fs.writeFileSync(path.join(out,'milo_viewer.html'),page);
console.log('Offline viewer generated; embedded model, scripts and CSP; no network dependencies.');
