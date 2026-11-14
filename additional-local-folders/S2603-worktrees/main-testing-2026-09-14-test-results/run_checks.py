import subprocess, pathlib, json, re
root=pathlib.Path('/Users/davidsovann/S2603-worktrees/main-testing-2026-09-14')
out=pathlib.Path(__file__).parent
engine='/Applications/Godot.app/Contents/MacOS/Godot'
tests=['startup','test_art_castle_gallery_flow','test_world_minimap','test_gallery_embedded_floating_world','test_train_station_jump_traversal','test_story_crown_railway','test_mesh_cutter','test_cutter_cap_loops','test_frustum_cutter','test_lens_collision','test_viewfinder_lens','test_lens_safety','test_lens_photo_card','test_lens_controller','test_lens_journey','test_lens_persistence','test_hub_lens']
results=[]
for name in tests:
    args=[engine,'--headless','--path',str(root/'artea'),'--log-file',str(out/(name+'.engine.log'))]
    args+=['--quit-after','180'] if name=='startup' else ['--script','res://scripts/'+name+'.gd']
    with (out/(name+'.log')).open('w') as f:
        try:
            r=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=90)
            code=r.returncode
        except subprocess.TimeoutExpired:
            code=124
    log=(out/(name+'.log')).read_text(errors='replace')
    errors=[x for x in log.splitlines() if re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:|FAILED|all checks passed|PASS',x)]
    result={'test':name,'exit_code':code,'clean':code==0 and not re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:|FAILED',log),'evidence':errors[:20]}
    results.append(result)
    (out/'results.json').write_text(json.dumps(results,indent=2))
    print(json.dumps(result),flush=True)
