/** Serial native integration/regression checks; records actual engine errors. */
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const outputArg = process.argv.find(arg => arg.startsWith('--out='));
const out = resolve(root, outputArg ? outputArg.slice('--out='.length) : 'artifacts/mind_spark_islands_v11/tests');
mkdirSync(out, { recursive: true });
const godot = '/Users/davidsovann/Downloads/Godot.app/Contents/MacOS/Godot';
const tests = [
  'test_mind_spark_celestial_land',
  'test_mind_spark_zone02_route_clearance',
  'test_astral_castle_traversal',
  'test_astral_refinement_v16',
  'test_hope_viaduct_v17',
  'test_mind_spark_architecture_physics',
  'test_mind_spark_transit_network',
  'test_live_mind_spark_entry',
  'test_world_minimap',
  'test_art_castle_gallery_flow',
  'test_gallery_embedded_floating_world',
  'test_train_station_jump_traversal',
  'test_story_crown_railway',
  'test_mind_spark_island_texture_coverage',
  'test_mind_spark_world_one_story',
];

async function run(name, resource) {
  let log = '';
  let timedOut = false;
  let scriptFailure = false;
  const started = Date.now();
  // Spawn the test process directly so a failing assertion can be terminated
  // without orphaning a Godot child behind a command proxy.
  const child = spawn(godot, ['--headless', '--path', root, '--script', resource], { cwd: root });
  const timer = setTimeout(() => { timedOut = true; child.kill('SIGTERM'); }, 90000);
  for (const stream of [child.stdout, child.stderr]) {
    stream.on('data', chunk => {
      log += chunk.toString();
      if (log.includes('SCRIPT ERROR:') && !scriptFailure) {
        scriptFailure = true;
        // A GDScript assertion can otherwise leave SceneTree running forever.
        setTimeout(() => child.kill('SIGTERM'), 1000).unref();
      }
    });
  }
  const exit = await new Promise(resolveExit => child.on('close', (code, signal) => resolveExit({ code, signal })));
  clearTimeout(timer);
  writeFileSync(resolve(out, `${name}.log`), log);
  const result = { name, ...exit, timedOut, scriptFailure, seconds: (Date.now() - started) / 1000,
    passed: exit.code === 0 && !timedOut && !scriptFailure,
    evidence: log.split('\n').filter(line => /PASS|BASELINE_|SCRIPT ERROR|Assertion failed|ERROR:/.test(line)) };
  console.log(JSON.stringify(result));
  return result;
}

const results = [];
for (const name of tests) {
  results.push(await run(name, `res://scripts/${name}.gd`));
  writeFileSync(resolve(out, 'results.json'), JSON.stringify(results, null, 2) + '\n');
}
// Isolate old/new visual foundations when checking the known unrelated blocker.
if (results.some(result => !result.passed)) {
  results.push(await run('baseline_probe', 'res://artifacts/mind_spark_celestial_land/baseline_probe.gd'));
  writeFileSync(resolve(out, 'results.json'), JSON.stringify(results, null, 2) + '\n');
}
process.exitCode = results.some(result => !result.passed) ? 1 : 0;
