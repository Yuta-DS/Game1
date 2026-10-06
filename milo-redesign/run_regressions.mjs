// Generate isolated copies of existing tests with only the model construction
// replaced. The assertions and the live game sources are not edited.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const out=path.dirname(fileURLToPath(import.meta.url)), project=path.join(out,'../artea');
const helper=`
func _redesign_instance(source: PackedScene) -> CharacterBody3D:
\tvar doc := GLTFDocument.new()
\tvar state := GLTFState.new()
\tassert(doc.append_from_file("${out}/milo_redesign.glb", state) == OK)
\tvar model := doc.generate_scene(state)
\tvar milo := source.instantiate() as CharacterBody3D
\tvar skin := milo.get_node("Model")
\tvar original := skin.get_node("Model")
\tskin.remove_child(original)
\toriginal.free()
\tmodel.name = "Model"
\tskin.add_child(model)
\treturn milo
`;
const results=[];
for(const [name,constant] of [['natural_animation','MILO_SCENE'],['companion_follow','MILO_SCENE'],['speech_animation','MiloNPCScene']]) {
 const source=fs.readFileSync(path.join(project,'scripts/test_milo_'+name+'.gd'),'utf8');
 const needle=constant+'.instantiate() as CharacterBody3D';
 if(!source.includes(needle)) throw Error('Test construction changed: '+name);
 const target=path.join(out,'regression_'+name+'.gd');
 fs.writeFileSync(target,source.replace(needle,'_redesign_instance('+constant+')')+'\n'+helper);
 const run=spawnSync('rtk',['proxy','/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',project,'--script',target],{encoding:'utf8',timeout:60000});
 const log=(run.stdout||'')+(run.stderr||'');
 fs.writeFileSync(path.join(out,'regression_'+name+'.log'),log);
 const passed=run.status===0 && /TEST: PASS/.test(log);
 results.push({name,passed,exit_code:run.status,source_sha256:crypto.createHash('sha256').update(source).digest('hex')});
 console.log(name, passed?'PASS':'FAIL',log.split('\n').filter(l=>/TEST:|FAIL|ERROR/.test(l)).join('\n'));
}
fs.writeFileSync(path.join(out,'regressions.json'),JSON.stringify({passed:results.every(r=>r.passed),tests:results},null,2));
if(results.some(r=>!r.passed)) process.exitCode=1;
