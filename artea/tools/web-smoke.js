// Prove a served web build actually plays, not merely that it renders a frame.
//
// Startup failures on web are quiet: a missing export dependency makes
// change_scene_to_packed receive null, so clicking through does nothing at all
// and the page looks like a slow load rather than a broken build. This drives
// the real thing - loads the page, clicks Offline Guest, waits for the hub to
// report itself built, then holds a movement key and checks the frame changed.
//
// It also measures the cold first load: the browser cache is disabled, every
// byte that crosses the network is counted, and the time from navigation until
// the hub reports itself built is recorded. Those two numbers are the baseline
// load-time work is measured against (docs/web-baseline.md).
//
//   node artea/tools/web-smoke.js [url] [--out DIR] [--keep-open] [--repeat]
//
// --repeat loads the page a second time with the cache on and reports what
// that repeat visit transferred.
//
// Chrome is driven over CDP. Node 22+ ships a global WebSocket, so this needs
// no npm packages at all: the only requirement is a Chrome that can be started
// with --remote-debugging-port, which the script does itself.

const { spawn, execSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const args = process.argv.slice(2);
const url = args.find((a) => !a.startsWith('--')) || 'http://localhost:8800/index.html';
const outDir = (() => {
	const i = args.indexOf('--out');
	return i === -1 ? fs.mkdtempSync(path.join(os.tmpdir(), 'artea-smoke-')) : args[i + 1];
})();
const keepOpen = args.includes('--keep-open');
const repeat = args.includes('--repeat');
const DEBUG_PORT = 9222;

// The Offline Guest button, in the 1280x800 viewport the script emulates. The
// current login screen puts it at y=726; deployments still running the older,
// shorter login panel have it at y=568. Tried in order until one is accepted.
const VIEWPORT = { width: 1280, height: 800 };
const GUEST_BUTTONS = [{ x: 300, y: 726 }, { x: 287, y: 568 }];

const CHROME_PATHS = [
	'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
	'/Applications/Chromium.app/Contents/MacOS/Chromium',
	'/usr/bin/google-chrome',
	'/usr/bin/chromium',
	'C:/Program Files/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const cdp = async (route, method = 'GET') =>
	(await fetch(`http://127.0.0.1:${DEBUG_PORT}${route}`, { method })).json();

async function chromeIsUp() {
	try {
		await cdp('/json/version');
		return true;
	} catch {
		return false;
	}
}

async function startChrome() {
	if (await chromeIsUp()) return null;
	const bin = CHROME_PATHS.find((p) => fs.existsSync(p));
	if (!bin) throw new Error('No Chrome or Chromium found. Install one, or start it yourself with --remote-debugging-port=' + DEBUG_PORT);
	const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'artea-chrome-'));
	const child = spawn(bin, [
		'--headless=new',
		`--remote-debugging-port=${DEBUG_PORT}`,
		`--user-data-dir=${profile}`,
		'--no-first-run',
		'--enable-unsafe-swiftshader',
		...(process.env.SMOKE_CACHE_BYTES ? [`--disk-cache-size=${process.env.SMOKE_CACHE_BYTES}`] : []),
	], { stdio: 'ignore', detached: true });
	for (let i = 0; i < 30; i += 1) {
		await sleep(500);
		if (await chromeIsUp()) return child;
	}
	throw new Error('Chrome did not open a debug port');
}

async function connect() {
	// PUT, not GET: recent Chrome refuses /json/new over GET.
	const target = await cdp('/json/new?about:blank', 'PUT');
	const ws = new WebSocket(target.webSocketDebuggerUrl);
	let id = 0;
	const pending = new Map();
	const consoleLines = [];
	let crashed = false;
	// Bytes that crossed the wire (after any Content-Encoding), per request.
	// dataReceived counts as the body streams in; loadingFinished then gives the
	// exact total including headers. A request that ends in loadingFailed never
	// gets a loadingFinished, so without dataReceived its bytes would vanish.
	const net = {
		perRequest: new Map(), urls: new Map(), failures: [], cached: new Set(),
		requests: 0, failed: 0, hubAt: null, bytesAtHub: null, requestsAtHub: null, engineAt: null,
		// Each source is tallied on its own and the largest wins: adding them
		// into one slot would count every streamed part twice.
		tally(id) {
			if (!this.perRequest.has(id)) this.perRequest.set(id, { streamed: 0, finished: 0, length: 0 });
			return this.perRequest.get(id);
		},
		of(id) {
			const t = this.perRequest.get(id);
			// Content-Length is only a floor when a body actually streamed in (the
			// aborted-part case). A revalidated 304 is reported as the cached 200
			// with its original Content-Length but moves no body bytes at all.
			return t.streamed > 0
				? Math.max(t.streamed, t.finished, t.length)
				: Math.max(t.streamed, t.finished);
		},
		get bytes() {
			let total = 0;
			for (const id of this.perRequest.keys()) total += this.of(id);
			return total;
		},
	};

	ws.addEventListener('message', (ev) => {
		const m = JSON.parse(ev.data);
		if (m.id && pending.has(m.id)) {
			const { resolve, reject } = pending.get(m.id);
			pending.delete(m.id);
			return m.error ? reject(new Error(JSON.stringify(m.error))) : resolve(m.result);
		}
		if (m.method === 'Network.requestWillBeSent') net.urls.set(m.params.requestId, m.params.request.url);
		// pck-loader.js hands each part's body to a stream, and Chrome reports
		// many of those requests as net::ERR_ABORTED before its dataReceived
		// events catch up, undercounting by ~1%. Content-Length is the exact
		// on-the-wire body size (after Content-Encoding), so it is the floor.
		if (m.method === 'Network.responseReceived') {
			const response = m.params.response;
			const id = m.params.requestId;
			net.tally(id).status = response.status;
			// A cache hit still carries its original Content-Length, but nothing
			// crossed the wire; only real transfers get the floor.
			if (response.fromDiskCache || response.fromMemoryCache || response.fromPrefetchCache) {
				net.cached.add(id);
			} else {
				const headers = response.headers || {};
				const lengthKey = Object.keys(headers).find((k) => k.toLowerCase() === 'content-length');
				const length = lengthKey ? Number(headers[lengthKey]) : NaN;
				if (Number.isFinite(length) && response.status !== 304) net.tally(id).length = length;
			}
		}
		if (m.method === 'Network.requestServedFromCache') net.cached.add(m.params.requestId);
		if (m.method === 'Network.dataReceived') {
			const id = m.params.requestId;
			net.tally(id).streamed += m.params.encodedDataLength;
		}
		if (m.method === 'Network.loadingFinished') {
			const id = m.params.requestId;
			net.tally(id).finished = m.params.encodedDataLength;
			net.requests += 1;
		}
		if (m.method === 'Network.loadingFailed') {
			// ERR_ABORTED is the streamed-part hand-off above, not a failure.
			if (m.params.errorText !== 'net::ERR_ABORTED') net.failed += 1;
			net.failures.push(`${m.params.errorText} ${net.urls.get(m.params.requestId) || m.params.requestId}`);
		}
		if (m.method === 'Runtime.consoleAPICalled') {
			const line = (m.params.args || []).map((a) => a.value ?? a.description ?? a.type).join(' ');
			consoleLines.push(line);
			// Stamp the hub the moment its log arrives, not at the next 1 s poll.
			// The pack is fully downloaded by the time the engine starts, and
			// every build logs this, including deployments older than the hub log.
			if (net.engineAt === null && /engine started/.test(line)) net.engineAt = Date.now();
			if (net.hubAt === null && /Successfully spawned|galaxy world=true/.test(line)) {
				net.hubAt = Date.now();
				net.bytesAtHub = net.bytes;
				net.requestsAtHub = net.requests;
			}
		}
		if (m.method === 'Runtime.exceptionThrown') {
			consoleLines.push('EXCEPTION ' + (m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text));
		}
		if (m.method === 'Inspector.targetCrashed') crashed = true;
	});
	await new Promise((r) => ws.addEventListener('open', r));

	const send = (method, params = {}) => new Promise((resolve, reject) => {
		const msgId = (id += 1);
		pending.set(msgId, { resolve, reject });
		ws.send(JSON.stringify({ id: msgId, method, params }));
	});
	return { send, consoleLines, crashed: () => crashed, targetId: target.id, net };
}

(async () => {
	const t0 = Date.now();
	const stamp = () => `${((Date.now() - t0) / 1000).toFixed(1).padStart(6)}s `;
	const say = (msg) => console.log(stamp() + msg);

	fs.mkdirSync(outDir, { recursive: true });
	// A Chrome this script started is closed again at the end. It used to be
	// left running detached, and every later run silently reused it - with its
	// old flags and cache - instead of getting the fresh profile it expects.
	const ownChrome = await startChrome();
	const closeOwnChrome = async () => {
		if (keepOpen || !ownChrome) return;
		try { process.kill(ownChrome.pid); } catch { /* already gone */ }
	};
	const { send, consoleLines, crashed, targetId, net } = await connect();

	await send('Emulation.setDeviceMetricsOverride', { ...VIEWPORT, deviceScaleFactor: 1, mobile: false });
	await send('Runtime.enable');
	await send('Page.enable');
	await send('Network.enable');
	// Cold load every run, even against a Chrome the user started themselves.
	// --repeat needs the cache on so the second visit can use it; the first
	// load is still cold because startChrome() uses a fresh profile.
	if (!repeat) await send('Network.setCacheDisabled', { cacheDisabled: true });
	let navigatedAt = null;

	// Plain KEY=value lines so CI and later tickets can grep the numbers.
	const reportMetrics = () => {
		const mb = (b) => (b / 1048576).toFixed(1);
		const reached = net.hubAt !== null;
		const hubSeconds = reached ? ((net.hubAt - navigatedAt) / 1000).toFixed(1) : null;
		console.log(`\nfirst load (${repeat ? 'cold, fresh profile' : 'cache disabled'}):`);
		console.log(`  bytes transferred to hub: ${reached ? `${net.bytesAtHub} (${mb(net.bytesAtHub)} MiB, ${net.requestsAtHub} requests)` : 'hub not reached'}`);
		const engineSeconds = net.engineAt !== null ? ((net.engineAt - navigatedAt) / 1000).toFixed(1) : null;
		console.log(`  time to engine started:   ${engineSeconds !== null ? `${engineSeconds} s` : 'not started'}`);
		console.log(`  time to hub:              ${reached ? `${hubSeconds} s` : 'hub not reached'}`);
		console.log(`  bytes transferred total:  ${net.bytes} (${mb(net.bytes)} MiB, ${net.requests} requests, ${net.failed} failed)`);
		console.log(`METRIC bytes_to_hub=${reached ? net.bytesAtHub : -1}`);
		console.log(`METRIC time_to_engine_s=${engineSeconds ?? -1}`);
		console.log(`METRIC time_to_hub_s=${reached ? hubSeconds : -1}`);
		console.log(`METRIC bytes_total=${net.bytes}`);
		// Per-request bytes, largest first: where the download actually goes.
		const rows = [...net.perRequest.keys()].map((id) => [net.of(id), net.urls.get(id) || id]).sort((a, c) => c[0] - a[0]);
		fs.writeFileSync(path.join(outDir, 'requests.log'), rows.map(([b, u]) => `${b}\t${u}`).join('\n'));
		if (net.failures.length) {
			fs.writeFileSync(path.join(outDir, 'failed-requests.log'), net.failures.join('\n'));
		}
	};

	const shot = async (name) => {
		const s = await send('Page.captureScreenshot', { format: 'png' });
		const buf = Buffer.from(s.data, 'base64');
		fs.writeFileSync(path.join(outDir, `${name}.png`), buf);
		return buf;
	};
	// `from` skips lines logged before it, so a second visit waits for its own
	// "engine started" rather than matching the first visit's.
	const waitForLog = async (re, label, timeoutMs, from = 0) => {
		const until = Date.now() + timeoutMs;
		while (Date.now() < until) {
			if (crashed()) throw new Error('renderer crashed (out of memory is the usual cause)');
			if (consoleLines.slice(from).some((l) => re.test(l))) {
				say('OK  ' + label);
				return;
			}
			await sleep(1000);
		}
		throw new Error(`timed out waiting for ${label}`);
	};
	const click = async (x, y) => {
		for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
			await send('Input.dispatchMouseEvent', {
				type, x, y, button: 'left', buttons: type === 'mousePressed' ? 1 : 0, clickCount: 1,
			});
			await sleep(60);
		}
	};
	const key = (type, code, keyCode) => send('Input.dispatchKeyEvent', {
		type, code, key: code.replace('Key', '').toLowerCase(),
		windowsVirtualKeyCode: keyCode, nativeVirtualKeyCode: keyCode,
	});

	try {
		say('loading ' + url);
		navigatedAt = Date.now();
		await send('Page.navigate', { url });
		// Generous: a deployed cold load pulls the whole pack over the internet.
		await waitForLog(/engine started/, 'engine started', 900000);
		await sleep(4000);
		await shot('01-start-screen');

		for (const [index, button] of GUEST_BUTTONS.entries()) {
			say(`clicking Offline Guest at (${button.x}, ${button.y})`);
			await click(button.x, button.y);
			try {
				await waitForLog(/GUEST access selected|galaxy world=true/, 'guest login accepted', 60000);
				break;
			} catch (err) {
				if (index === GUEST_BUTTONS.length - 1) throw err;
			}
		}
		await waitForLog(/Successfully spawned|galaxy world=true/, 'hub scene built', 120000);
		await sleep(8000);
		const before = await shot('02-in-hub');

		// A frozen game returns byte-identical frames, so movement is the check
		// that separates "rendered once" from "playable".
		say('holding W to test movement');
		await click(VIEWPORT.width / 2, VIEWPORT.height / 2);
		await key('keyDown', 'KeyW', 87);
		await sleep(2500);
		const during = await shot('03-moving');
		await key('keyUp', 'KeyW', 87);
		await sleep(1500);
		const after = await shot('04-after-move');

		const identical = (a, b) => a.length === b.length && a.equals(b);
		const moved = !identical(before, during) || !identical(during, after);
		const fatal = consoleLines.filter((l) => /new_scene" is null|No loader found|Failed to load scene/.test(l));

		fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
		reportMetrics();
		say('frame changed while moving: ' + moved);
		say('fatal resource errors: ' + fatal.length);
		fatal.slice(0, 5).forEach((l) => console.log('    ' + l.slice(0, 200)));

		const pass = moved && !crashed() && fatal.length === 0;

		if (repeat) {
			// Same page again with the cache on: with content-hashed parts served
			// immutable, only what must be revalidated should come back over the
			// wire (docs/web-baseline.md, issue #33).
			const seenRequests = new Set(net.perRequest.keys());
			const fromLine = consoleLines.length;
			const started = Date.now();
			say('second visit, cache on');
			await send('Page.navigate', { url });
			await waitForLog(/engine started/, 'engine started again', 900000, fromLine);
			await sleep(3000);
			const visit = [...net.perRequest.keys()].filter((id) => !seenRequests.has(id))
				.map((id) => [net.of(id), net.urls.get(id) || id]).sort((a, c) => c[0] - a[0]);
			const bytes = visit.reduce((sum, [b]) => sum + b, 0);
			console.log('\nsecond visit (cache on):');
			const fromCache = [...net.perRequest.keys()].filter((id) => !seenRequests.has(id) && net.cached.has(id)).length
				+ [...net.cached].filter((id) => !seenRequests.has(id) && !net.perRequest.has(id)).length;
			console.log(`  bytes transferred:        ${bytes} (${(bytes / 1048576).toFixed(2)} MiB, ${visit.length} requests, ${fromCache} served from cache)`);
			console.log(`  time to engine started:   ${((Date.now() - started - 3000) / 1000).toFixed(1)} s`);
			// Per-request detail for the repeat visit: what was revalidated, what
			// came over again, and from which byte source each count was taken.
			fs.writeFileSync(path.join(outDir, 'repeat-requests.log'), [...net.perRequest.keys()]
				.filter((id) => !seenRequests.has(id))
				.map((id) => {
					const t = net.perRequest.get(id);
					return [net.of(id), `status=${t.status} streamed=${t.streamed} finished=${t.finished} length=${t.length}`, net.urls.get(id) || id].join('\t');
				}).join('\n'));
			console.log('  largest:');
			visit.slice(0, 6).forEach(([b, u]) => console.log(`    ${String(b).padStart(10)}  ${u}`));
			console.log(`METRIC repeat_bytes=${bytes}`);
		}

		console.log('\nscreenshots: ' + outDir);
		console.log('RESULT: ' + (pass ? 'PLAYABLE' : 'NOT PLAYABLE'));
		if (!keepOpen) await cdp(`/json/close/${targetId}`).catch(() => {});
		await closeOwnChrome();
		process.exit(pass ? 0 : 1);
	} catch (err) {
		fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
		if (navigatedAt !== null) reportMetrics();
		await shot('99-failure').catch(() => {});
		console.log('\nFAILED: ' + err.message);
		console.log('console tail:');
		consoleLines.slice(-15).forEach((l) => console.log('    ' + l.slice(0, 200)));
		console.log('screenshots: ' + outDir);
		if (!keepOpen) await cdp(`/json/close/${targetId}`).catch(() => {});
		await closeOwnChrome();
		process.exit(2);
	}
})();
