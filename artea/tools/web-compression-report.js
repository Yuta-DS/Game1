// One-off report: what gzip and brotli would save on the files a web build
// actually ships - the pack, and the engine's js/wasm/html.
//
//   node artea/tools/web-compression-report.js [build_dir]
//
// build_dir defaults to artea/builds/web. Output is a Markdown table, ready to
// paste into docs/web-baseline.md. Needs only Node: gzip and brotli both come
// from the built-in zlib module.
//
// Levels: gzip 6 is what servers apply on the fly. Brotli 11 is what you would
// precompress with, but at that quality a 700 MB pack takes the better part of
// an hour, so files over BROTLI_MAX_Q11_BYTES use quality 9 and the table says
// so. Files are streamed, never held in memory whole.

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { pipeline } = require('node:stream/promises');
const { Writable } = require('node:stream');

const buildDir = process.argv[2] || path.join(__dirname, '..', 'builds', 'web');
const BROTLI_MAX_Q11_BYTES = 64 * 1024 * 1024;

// What the browser downloads: the whole pack (served split, but the split adds
// no bytes), the engine, and the page. Part files and .import sidecars are
// either duplicates of the pack or never requested.
const shipped = (name) => /\.(pck|wasm|js|html)$/.test(name);

async function compressedSize(file, compressor) {
	let bytes = 0;
	const counter = new Writable({
		write(chunk, _encoding, done) {
			bytes += chunk.length;
			done();
		},
	});
	await pipeline(fs.createReadStream(file, { highWaterMark: 1 << 20 }), compressor, counter);
	return bytes;
}

const mb = (b) => (b / 1048576).toFixed(2);
const pct = (part, whole) => `${((1 - part / whole) * 100).toFixed(0)}%`;

(async () => {
	const files = fs.readdirSync(buildDir)
		.filter(shipped)
		.map((name) => ({ name, raw: fs.statSync(path.join(buildDir, name)).size }))
		.sort((a, b) => b.raw - a.raw);
	if (files.length === 0) {
		console.error(`No .pck/.wasm/.js/.html in ${buildDir} - run ./web rebuild first.`);
		process.exit(1);
	}

	const rows = [];
	const totals = { raw: 0, gzip: 0, brotli: 0 };
	for (const file of files) {
		const full = path.join(buildDir, file.name);
		const quality = file.raw > BROTLI_MAX_Q11_BYTES ? 9 : 11;
		process.stderr.write(`compressing ${file.name} (${mb(file.raw)} MiB, brotli q${quality})...\n`);
		const started = Date.now();
		const [gzip, brotli] = await Promise.all([
			compressedSize(full, zlib.createGzip({ level: 6 })),
			compressedSize(full, zlib.createBrotliCompress({
				params: {
					[zlib.constants.BROTLI_PARAM_QUALITY]: quality,
					[zlib.constants.BROTLI_PARAM_SIZE_HINT]: file.raw,
				},
			})),
		]);
		process.stderr.write(`  done in ${((Date.now() - started) / 1000).toFixed(0)} s\n`);
		rows.push({ ...file, gzip, brotli, quality });
		totals.raw += file.raw;
		totals.gzip += gzip;
		totals.brotli += brotli;
	}

	console.log(`Compression of ${path.resolve(buildDir)} (${new Date().toISOString().slice(0, 10)})\n`);
	console.log('| File | Raw MiB | gzip -6 MiB | saved | brotli MiB | saved |');
	console.log('|---|---:|---:|---:|---:|---:|');
	for (const r of rows) {
		console.log(`| ${r.name} | ${mb(r.raw)} | ${mb(r.gzip)} | ${pct(r.gzip, r.raw)} | ${mb(r.brotli)} (q${r.quality}) | ${pct(r.brotli, r.raw)} |`);
	}
	console.log(`| **Total** | **${mb(totals.raw)}** | **${mb(totals.gzip)}** | **${pct(totals.gzip, totals.raw)}** | **${mb(totals.brotli)}** | **${pct(totals.brotli, totals.raw)}** |`);
})().catch((err) => {
	console.error(err);
	process.exit(1);
});
