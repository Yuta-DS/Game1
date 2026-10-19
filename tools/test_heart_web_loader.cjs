const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('artea/tools/vercel-pack-split/pck-loader.js', 'utf8');

async function check(name, path, files, expected, expectedRequests) {
  const requests = [];
  const window = { location: { href: 'http://localhost/heart.html' }, fetch: async input => {
    const path = new URL(String(input), window.location.href).pathname;
    requests.push(path);
    return new Response(files[path] ?? '', { status: path in files ? 200 : 404 });
  }};
  vm.runInNewContext(source, { window, URL, Response, ReadableStream });
  assert.equal(await (await window.fetch(path)).text(), expected);
  assert.deepEqual(requests, expectedRequests);
  console.log('PASS ' + name);
}

(async () => {
  await check('whole wasm has no missing-part probes', '/index.side.wasm',
    { '/index.side.wasm': 'wasm' }, 'wasm', ['/index.side.wasm']);
  for (const name of ['index.side.wasm', 'index.pck']) {
    const path = '/' + name;
    await check('split ' + name, path, {
      [path + '.parts.json']: JSON.stringify({ count: 2, bytes: 4 }),
      [path + '.part00']: 'ab', [path + '.part01']: 'cd'
    }, 'abcd', [ ...(name.endsWith('wasm') ? [path] : []),
      path + '.parts.json', path + '.part00', path + '.part01']);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
