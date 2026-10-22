// Prove a served web build actually plays, not merely that it renders a frame.
//
// Startup failures on web are quiet: a missing export dependency makes
// change_scene_to_packed receive null, so clicking through does nothing at all
// and the page looks like a slow load rather than a broken build. This drives
// the real thing - loads the page, clicks Offline Guest, waits for the hub to
// report itself built, then holds a movement key and checks the frame changed.
// Then it goes into the Crown of Life story before the background download
// can reach it (the loading screen must download its Pack), waits in the Hub
// for the rest to finish downloading while comparing frame pacing, and enters
// the Art Castle and each Kingdom, which must need no download by then. After
// each area it checks the Hub loads again.
//
// It also measures the cold first load: the browser cache is disabled, every
// byte that crosses the network is counted, and the time from navigation until
// the hub reports itself built is recorded. Those two numbers are the baseline
// load-time work is measured against (docs/web-baseline.md).
//
//   node artea/tools/web-smoke.js [url] [--out DIR] [--keep-open] [--repeat]
//       [--latency MS] [--mbps N] [--fail-part NN] [--fail-times K]
//       [--startup-only] (login, hub entry and movement; skips later worlds)
//       [--music-circle] (instruments, seated piano, maze, fountain and Milo)
//       [--heart-journey] (staged garden UI, voice lifecycle, fountain and gate)
//       [--heart-audio-only] (focused garden fountain audio and Hub round trip)
//       [--heart-river-only] (actual organ, harp, Call Bells and Bell Grove gate)
//       [--profile-frames] (opt-in release telemetry and reversible A/B samples)
//       [--profile-hub] (with --profile-frames: Hub diagnostics only)
//
// --repeat loads the page a second time with the cache on and reports what
// that repeat visit transferred.
//
// --latency and --mbps shape the network like DevTools throttling: MS of added
// round trip per request, and an N Mbit/s cap on the whole download. Used to
// tune pck-loader.js's parallel part fetches (issue #34) - a local server has
// neither, so without them parallel fetching has nothing to win.
//
// --fail-part makes the pack part numbered NN (e.g. 05) answer 404 for its
// first K requests (--fail-times, default 2). Up to the loader's retries it
// should recover on its own; beyond them its Retry overlay must appear, and
// this lets the part through and presses Retry. Either way the game must still
// reach the hub, and no other part may be fetched twice.
//
// Chrome is driven over CDP. Node 22+ ships a global WebSocket, so this needs
// no npm packages at all: the only requirement is a Chrome that can be started
// with --remote-debugging-port, which the script does itself.

const { spawn, execSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const args = process.argv.slice(2);
const VALUE_OPTIONS = ['--out', '--latency', '--mbps', '--fail-part', '--fail-times'];
const option = (name) => {
	const i = args.indexOf(name);
	return i === -1 ? null : args[i + 1];
};
const url = args.find((a, i) => !a.startsWith('--') && !VALUE_OPTIONS.includes(args[i - 1]))
	|| 'http://localhost:8800/index.html';
const outDir = option('--out') ?? fs.mkdtempSync(path.join(os.tmpdir(), 'artea-smoke-'));
const keepOpen = args.includes('--keep-open');
const repeat = args.includes('--repeat');
const latencyMs = Number(option('--latency') ?? 0);
const mbps = Number(option('--mbps') ?? 0);
const failPart = option('--fail-part');
const failTimes = Number(option('--fail-times') ?? 2);
// Requests pck-loader.js makes for one part before showing its Retry overlay:
// the first try plus RETRY_DELAYS_MS.length retries.
const LOADER_ATTEMPTS = 4;
const DEBUG_PORT = Number(process.env.ARTEA_SMOKE_DEBUG_PORT || 9222);

// The Offline Guest button, in the 1280x800 viewport the script emulates. The
// current login screen (with "Forgot password?" under it) puts it at y=610;
// older login panels had it at y=726 and y=568. Tried in order until one is
// accepted.
const VIEWPORT = { width: 1280, height: 800 };
const GUEST_BUTTONS = [{ x: 300, y: 610 }, { x: 300, y: 726 }, { x: 287, y: 568 }];

const CHROME_PATHS = [
	'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
	'/Applications/Chromium.app/Contents/MacOS/Chromium',
	'/usr/bin/google-chrome',
	'/usr/bin/chromium',
	'C:/Program Files/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
	'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
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
	], { stdio: 'ignore', detached: true, windowsHide: true });
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
	const listeners = new Map();
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
			const { resolve, reject, timer } = pending.get(m.id);
			clearTimeout(timer);
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
			fs.appendFileSync(path.join(outDir, 'console-live.log'), line + '\n');
			// Stamp the hub the moment its log arrives, not at the next 1 s poll.
			// The pack is fully downloaded by the time the engine starts, and
			// every build logs this, including deployments older than the hub log.
			if (net.engineAt === null && /engine started/.test(line)) net.engineAt = Date.now();
			if (net.hubAt === null && /Successfully spawned/.test(line)) {
				net.hubAt = Date.now();
				net.bytesAtHub = net.bytes;
				net.requestsAtHub = net.requests;
			}
		}
		if (m.method === 'Runtime.exceptionThrown') {
			const line = 'EXCEPTION ' + (m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text);
			consoleLines.push(line);
			fs.appendFileSync(path.join(outDir, 'console-live.log'), line + '\n');
		}
		if (m.method === 'Inspector.targetCrashed') crashed = true;
		if (listeners.has(m.method)) listeners.get(m.method)(m.params);
	});
	await new Promise((r) => ws.addEventListener('open', r));

	const send = (method, params = {}) => new Promise((resolve, reject) => {
		const msgId = (id += 1);
		const timer = setTimeout(() => { pending.delete(msgId); reject(new Error('Browser stopped responding to ' + method)); }, 180000);
		pending.set(msgId, { resolve, reject, timer });
		ws.send(JSON.stringify({ id: msgId, method, params }));
	});
	const on = (method, handler) => listeners.set(method, handler);
	return { send, on, consoleLines, crashed: () => crashed, targetId: target.id, net };
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
		// Chromium's Windows launcher may exit before its browser process.
		// Close the owned browser over its browser-level CDP connection so
		// repeated tours do not leave headless browser trees consuming memory.
		try {
			const version = await cdp('/json/version');
			await new Promise((resolve) => {
				const browser = new WebSocket(version.webSocketDebuggerUrl);
				const timer = setTimeout(() => { browser.close(); resolve(); }, 2000);
				browser.addEventListener('open', () => browser.send(JSON.stringify({ id: 1, method: 'Browser.close' })));
				browser.addEventListener('close', () => { clearTimeout(timer); resolve(); });
				browser.addEventListener('error', () => { clearTimeout(timer); resolve(); });
			});
		} catch { /* browser may already have exited with its last tab */ }
		try { process.kill(ownChrome.pid); } catch { /* already gone */ }
	};
	const { send, on, consoleLines, crashed, targetId, net } = await connect();

	await send('Emulation.setDeviceMetricsOverride', { ...VIEWPORT, deviceScaleFactor: 1, mobile: false });
	await send('Runtime.enable');
	await send('Page.enable');
	await send('Page.bringToFront');
	await send('Emulation.setFocusEmulationEnabled', { enabled: true });
	await send('Network.enable');
	// Cold load every run, even against a Chrome the user started themselves.
	// --repeat needs the cache on so the second visit can use it; the first
	// load is still cold because startChrome() uses a fresh profile.
	if (!repeat) await send('Network.setCacheDisabled', { cacheDisabled: true });
	if (latencyMs || mbps) {
		await send('Network.emulateNetworkConditions', {
			offline: false,
			latency: latencyMs,
			downloadThroughput: mbps ? (mbps * 1e6) / 8 : -1,
			uploadThroughput: -1,
		});
	}
	let failuresLeft = failPart === null ? 0 : failTimes;
	if (failPart !== null) {
		on('Fetch.requestPaused', ({ requestId }) => {
			if (failuresLeft > 0) {
				failuresLeft -= 1;
				send('Fetch.fulfillRequest', { requestId, responseCode: 404, body: '' }).catch(() => {});
			} else {
				send('Fetch.continueRequest', { requestId }).catch(() => {});
			}
		});
		await send('Fetch.enable', { patterns: [{ urlPattern: `*part${failPart}*` }] });
	}
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
		// Parts requested more than once. Only a part that actually failed may
		// be fetched again; anything else means a retry restarted good parts.
		const partRequests = new Map();
		for (const u of net.urls.values()) {
			const name = new URL(u).pathname.split('/').pop();
			if (/part\d\d/.test(name)) partRequests.set(name, (partRequests.get(name) || 0) + 1);
		}
		const refetched = [...partRequests].filter(([, n]) => n > 1);
		const retries = consoleLines.filter((l) => /pck-loader: .*retrying/.test(l)).length;
		console.log(`  parts refetched:          ${refetched.length ? refetched.map(([n, c]) => `${n} x${c}`).join(', ') : 'none'}`);
		console.log(`METRIC part_retries=${retries}`);
		console.log(`METRIC parts_refetched=${refetched.length}`);
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
		if (failPart !== null && failTimes >= LOADER_ATTEMPTS) {
			// More failures than the loader retries: its Retry overlay must come
			// up and hold the download. Then let the part through and press it.
			const overlayUp = async () => (await send('Runtime.evaluate', {
				expression: "!!document.getElementById('pck-loader-retry')", returnByValue: true,
			})).result.value;
			const until = Date.now() + 180000;
			while (!(await overlayUp())) {
				if (Date.now() > until) throw new Error('Retry overlay never appeared');
				await sleep(500);
			}
			say('OK  Retry overlay shown');
			await shot('00-retry-overlay');
			failuresLeft = 0;
			await send('Runtime.evaluate', {
				expression: "document.querySelector('#pck-loader-retry button').click()",
			});
			say('pressed Retry');
		}
		// Generous: a deployed cold load pulls the whole pack over the internet.
		await waitForLog(/engine started/, 'engine started', 900000);
		await sleep(4000);
		await shot('01-start-screen');
		const previewState = await send('Runtime.evaluate', { expression: 'String(window.ARTEA_HEART_PREVIEW)', returnByValue: true });
		say('preview flag: ' + previewState.result.value);

		for (const [index, button] of GUEST_BUTTONS.entries()) {
			say(`clicking Offline Guest at (${button.x}, ${button.y})`);
			await click(button.x, button.y);
			try {
				await waitForLog(/GUEST access selected/, 'guest login accepted', 20000);
				break;
			} catch (err) {
				if (index === GUEST_BUTTONS.length - 1) throw err;
			}
		}
		await waitForLog(/Successfully spawned/, 'hub scene built', 120000);
		await waitForLog(/\[ARTEA\] loading screen done: res:\/\/scenes\/New_Hub_World.tscn/, 'hub controls ready', 240000);
		if (args.includes('--startup-only')) {
			const before = await shot('02-in-hub');
			await click(VIEWPORT.width / 2, VIEWPORT.height / 2);
			await key('keyDown', 'KeyW', 87);
			await sleep(2500);
			await key('keyUp', 'KeyW', 87);
			const after = await shot('03-after-move');
			const fatal = consoleLines.filter((line) => /SCRIPT ERROR|Parse Error|EXCEPTION|SceneLoader: could not open/.test(line));
			fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
			reportMetrics();
			if (crashed() || before.equals(after) || fatal.length) {
				throw new Error('Startup/movement check failed: ' + fatal.slice(0, 3).join('; '));
			}
			console.log('RESULT: STARTUP AND HUB PLAYABLE');
			if (!keepOpen) await cdp(`/json/close/${targetId}`).catch(() => {});
			await closeOwnChrome();
			process.exit(0);
		}
		const evaluate = async (expression) => (await send('Runtime.evaluate', { expression, returnByValue: true })).result.value;
		// Every frame's timestamp from here on, to compare the Hub's frame pacing
		// while the other areas' Packs download in the background with after.
		await evaluate('window.__frames = []; (function tick(t) { window.__frames.push(t); requestAnimationFrame(tick); })(performance.now()); true');

		// Every area outside Core, entered the way a player goes there and left
		// again for the Hub (issues #35-#38). window.arteaGo (Global.gd) takes the
		// route a teleporter or the journey takes: SceneLoader, the loading
		// screen, and the Pack downloads.
		const HUB = 'res://scenes/New_Hub_World.tscn';
		const goTo = async (label, scene) => {
			const from = consoleLines.length;
			const bytesBefore = net.bytes;
			const started = Date.now();
			say(`going to ${label}`);
			await evaluate(`window.arteaGo(${JSON.stringify(scene)})`);
			try {
				// The loading screen logs when it hands the scene over, after
				// the Pack download, the build and the shader warmup.
				const done = `[ARTEA] loading screen done: ${scene}`;
				await waitForLog({ test: (line) => line.includes(done) }, `${label} loaded`, 600000, from);
			} catch (err) {
				say('FAIL ' + err.message);
				return null;
			}
			return { bytes: net.bytes - bytesBefore, seconds: ((Date.now() - started) / 1000).toFixed(1) };
		};
		const areas = [];

		// Issue #38 fallback: straight into the area the background download
		// reaches last, before it can. The loading screen downloads its Pack
		// itself, with progress, while the background downloads hold back.
		const STORY = ['the Crown of Life story', 'res://scenes/viewfinder/crown_of_life_story.tscn'];
		const story = args.includes('--profile-hub') || args.includes('--heart-river-only') ? null : await goTo(...STORY);
		areas.push([STORY[0], story, story ? await goTo('the Hub', HUB) : null, 'not prefetched yet']);

		// Standing in the Hub while the rest downloads, then a while after.
		const prefetchFrom = await evaluate('performance.now()');
		const prefetchUntil = Date.now() + 600000;
		while (!(await evaluate('window.arteaPacks.prefetch.doneAt !== null'))) {
			if (Date.now() > prefetchUntil) throw new Error('the background download never finished');
			await sleep(500);
		}
		const prefetch = await evaluate('JSON.stringify(window.arteaPacks.prefetch)');
		await sleep(8000);
		const frames = await evaluate('JSON.stringify(window.__frames)');
		const { queue, startedAt, doneAt } = JSON.parse(prefetch);
		say(`background download finished: ${queue.join(', ')}`);
		// When each Pack started, was asked for by the loading screen, and
		// finished, from the start of the background download: a Pack the
		// player asked for should finish ahead of the background ones.
		const at = (t) => (t === null ? '-' : `${((t - startedAt) / 1000).toFixed(1)} s`);
		const packState = JSON.parse(await evaluate('JSON.stringify(window.arteaPacks.state)'));
		console.log('  Pack                                                    started   wanted  finished');
		for (const [file, s] of Object.entries(packState).sort((a, b) => a[1].startedAt - b[1].startedAt)) {
			console.log(`  ${file.padEnd(54)} ${at(s.startedAt).padStart(8)} ${at(s.wantedAt).padStart(8)} ${at(s.finishedAt).padStart(9)}`);
		}
		const pacing = (from, to) => {
			const stamps = JSON.parse(frames).filter((t) => t >= from && t <= to);
			const gaps = stamps.slice(1).map((t, i) => t - stamps[i]).sort((a, b) => a - b);
			if (gaps.length < 10) return null;
			const at = (q) => gaps[Math.min(gaps.length - 1, Math.floor(q * gaps.length))];
			return { frames: gaps.length, median: at(0.5), p95: at(0.95) };
		};
		const during = pacing(prefetchFrom + 1000, doneAt);
		const after = pacing(doneAt + 1000, doneAt + 8000);

		const before = await shot('02-in-hub');

		// A frozen game returns byte-identical frames, so movement is the check
		// that separates "rendered once" from "playable".
		const identical = (a, b) => a.length === b.length && a.equals(b);
		const movesWithW = async (start, duringName, afterName) => {
			say('holding W to test movement');
			await click(VIEWPORT.width / 2, VIEWPORT.height / 2);
			await key('keyDown', 'KeyW', 87);
			await sleep(2500);
			const duringShot = await shot(duringName);
			await key('keyUp', 'KeyW', 87);
			await sleep(1500);
			const afterShot = await shot(afterName);
			return !identical(start, duringShot) || !identical(duringShot, afterShot);
		};
		const moved = await movesWithW(before, '03-moving', '04-after-move');
		if (args.includes('--heart-audio-only') || args.includes('--heart-river-only')) {
			// Mount the valley pack through its real loader before the transient
			// fixture dynamically loads that scene.
			if (!await goTo('Heart Melody valley', 'res://scenes/heart_melody/heart_melody_world.tscn')) throw new Error('Garden pack failed');
			for (const name of ['heart_journey_web_qa.gd', 'heart_journey_web_qa.tscn']) {
				const source = fs.readFileSync(path.join(__dirname, 'qa', name), 'utf8').replace('res://tools/qa/heart_journey_web_qa.gd', '/tmp/heart_journey_web_qa.gd');
				await evaluate(`engine.copyToFS(${JSON.stringify('/tmp/' + name)}, new TextEncoder().encode(${JSON.stringify(source)}).buffer)`);
			}
			if (!moved || !await goTo('the garden audio test', '/tmp/heart_journey_web_qa.tscn')) throw new Error('Garden audio scene failed');
			await waitForLog(/JOURNEY QA ready/, 'garden audio fixture', 20000);
			const stages = args.includes('--heart-river-only') ? ['gate', 'instrument', 'river-organ', 'river-harp', 'river-bells'] : ['fountain'];
			for (const stage of stages) {
				const from = consoleLines.length;
				await evaluate(`window.arteaJourneyQA(${JSON.stringify(stage)})`);
				await waitForLog(new RegExp('JOURNEY QA stage ' + stage), stage, 15000, from);
				await sleep(700);
				await shot('journey-' + stage);
			}
			if (!await goTo('the Hub', HUB)) throw new Error('Garden audio return failed');
			const errors = consoleLines.filter(line => /SCRIPT ERROR|Parse Error|Failed to load scene|JOURNEY QA (?:FAILURE|flower answer did not|clearing did not|gate failed|menu did not|missing control|fountain not|garden background)/.test(line));
			fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
			if (errors.length) throw new Error(errors.join('\n'));
			await cdp(`/json/close/${targetId}`).catch(() => {});
			await closeOwnChrome();
			console.log(args.includes('--heart-river-only') ? 'RESULT: RIVER SONG ROUTE PLAYABLE' : 'RESULT: GARDEN AUDIO PLAYABLE');
			process.exit(0);
		}
		const profiles = [];
		const profile = async (label, options = {}, seconds = 6) => {
			if (!args.includes('--profile-frames')) return;
			const from = consoleLines.length;
			await evaluate(`window.arteaFrameProfile(${JSON.stringify(label)}, ${seconds}, ${JSON.stringify(JSON.stringify(options))})`);
			if (options.portrait || options.sea_view) { await sleep(2000); await shot(label); }
			await waitForLog({ test: line => line.includes('FRAME PROFILE ') && line.includes(JSON.stringify(label)) }, label, 70000, from);
			const line = consoleLines.slice(from).find(line => line.includes('FRAME PROFILE ') && line.includes(JSON.stringify(label)));
			const result = JSON.parse(line.slice(line.indexOf('FRAME PROFILE ') + 14));
			profiles.push(result);
			fs.writeFileSync(path.join(outDir, 'frame-profiles.json'), JSON.stringify(profiles, null, 2));
			say(`${label}: median ${result.frames.p50.toFixed(1)} ms; p95 ${result.frames.p95.toFixed(1)}; max ${result.frames.max.toFixed(1)}; draws ${result.draws.p50}`);
		};
		if (args.includes('--profile-frames')) {
			for (const name of ['frame_profile_bootstrap.gd', 'frame_profile_bootstrap.tscn', 'frame_profile_sampler.gd']) {
				const source = fs.readFileSync(path.join(__dirname, 'qa', name), 'utf8').replace('res://tools/qa/frame_profile_bootstrap.gd', '/tmp/frame_profile_bootstrap.gd');
				await evaluate(`engine.copyToFS(${JSON.stringify('/tmp/' + name)}, new TextEncoder().encode(${JSON.stringify(source)}).buffer)`);
			}
			if (!await goTo('frame sampler bootstrap', '/tmp/frame_profile_bootstrap.tscn')) throw new Error('Frame sampler bootstrap failed');
			await waitForLog(/FRAME SAMPLER READY/, 'frame sampler ready', 10000);
			await goTo('the Hub', HUB);
			const renderer = await evaluate(`(() => { const canvas = document.querySelector('canvas'); const gl = canvas.getContext('webgl2'); const ext = gl.getExtension('WEBGL_debug_renderer_info'); return {renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER), vendor: ext ? gl.getParameter(ext.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR), width: canvas.width, height: canvas.height, attributes: gl.getContextAttributes()}; })()`);
			fs.writeFileSync(path.join(outDir, 'renderer.json'), JSON.stringify(renderer, null, 2));
			for (const [suffix, options] of [['idle', {}], ['milo-portrait', {portrait:true}], ['render-off', {render_off:true}], ['scripts-off', {scripts_off:true}], ['no-scatter', {no_scatter:true}], ['no-shadows', {no_shadows:true}]]) await profile('hub-' + suffix, options);
			await profile('hub-sea-east', {sea_view:'east'});
			await profile('hub-sea-south', {sea_view:'south'});
			await profile('hub-ocean-near', {shore_audio:'near'});
			await profile('hub-ocean-inland', {shore_audio:'inland'});
			if (args.includes('--profile-hub')) {
				const samples = [['no-msaa', {msaa_3d:0}], ['no-lights', {no_lights:true}], ['animations-off', {animations_off:true}], ['hide-milo', {hide_names:['Milo_Animations2']}]];
				for (const [suffix, options] of samples) await profile('hub-' + suffix, options);
				fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
				if (!keepOpen) await cdp(`/json/close/${targetId}`).catch(() => {});
				await closeOwnChrome();
				console.log('RESULT: FRAME PROFILE COMPLETE');
				process.exit(0);
			}
		}

		// Prefetched by now, so these should download (next to) nothing on the
		// way in.
		const castle = await goTo('the Art Castle', 'res://scenes/art_gallery_3d_inprogress.tscn');
		let castlePlayable = false;
		if (castle) {
			await sleep(3000);
			castlePlayable = await movesWithW(await shot('05-art-castle'), '06-castle-moving', '07-castle-after-move');
			const samples = [['idle', {}], ['orbit', {orbit:true}], ['render-off', {render_off:true}], ['scripts-off', {scripts_off:true}], ['no-floating', {hide_names:['ArtCastleFloatingWorld']}], ['melody-idle', {at:'melody'}], ['melody-orbit', {at:'melody',orbit:true}], ['melody-render-off', {at:'melody',render_off:true}], ['melody-scripts-off', {at:'melody',scripts_off:true}]];
			for (const [suffix, options] of samples) await profile('castle-' + suffix, options);
		}
		let musicCirclePlayable = !args.includes('--music-circle');
		if (castle && args.includes('--music-circle')) {
			// tools/** is intentionally excluded from production. Copy only the
			// opt-in controller into this browser's transient virtual filesystem;
			// it instantiates and operates the unmodified exported gallery.
			for (const name of ['music_circle_web_qa.gd', 'music_circle_web_qa.tscn']) {
				const source = fs.readFileSync(path.join(__dirname, 'qa', name), 'utf8')
					.replace('res://tools/qa/music_circle_web_qa.gd', '/tmp/music_circle_web_qa.gd');
				await evaluate(`engine.copyToFS(${JSON.stringify('/tmp/' + name)}, new TextEncoder().encode(${JSON.stringify(source)}).buffer)`);
			}
			const fixture = await goTo('the music-circle test', '/tmp/music_circle_web_qa.tscn');
			if (!fixture) throw new Error('Could not open the real music-circle test scene');
			const tap = async (code, keyCode, keyValue) => {
				for (const type of ['keyDown', 'keyUp']) {
					await send('Input.dispatchKeyEvent', { type, code, key: keyValue, windowsVirtualKeyCode: keyCode, nativeVirtualKeyCode: keyCode });
					await sleep(code === 'F8' ? 450 : 180);
				}
			};
			for (const kind of ['xylophone', 'drums', 'bells', 'guitar', 'piano', 'gallery_piano']) {
				await waitForLog(new RegExp('MUSIC QA near ' + kind), kind + ' proximity', 20000);
				await tap('KeyQ', 81, 'q');
				await waitForLog(new RegExp('MUSIC QA open ' + kind), kind + ' controls', 20000);
				let from = consoleLines.length;
				await tap('KeyA', 65, 'a');
				await waitForLog(new RegExp('MUSIC QA note ' + kind + ' ' + (kind.endsWith('piano') ? 60 : 0)), kind + ' keyboard sound', 10000, from);
				if (kind === 'xylophone' || kind === 'piano') {
					from = consoleLines.length;
					await tap('KeyJ', 74, 'j');
					await waitForLog(new RegExp('MUSIC QA note ' + kind + ' ' + (kind.endsWith('piano') ? 71 : 6)), kind + ' J note without journal', 10000, from);
				}
				const line = consoleLines.findLast((line) => line.includes('MUSIC QA pad ' + kind));
				const coords = line.match(/MUSIC QA pad \w+ ([\d.\-]+) ([\d.\-]+)/);
				if (!coords) throw new Error('No clickable pad position for ' + kind);
				from = consoleLines.length;
				await click(Number(coords[1]), Number(coords[2]));
				await waitForLog(new RegExp('MUSIC QA note ' + kind + ' ' + (kind.endsWith('piano') ? 60 : 0)), kind + ' clicked sound', 10000, from);
				await shot('music-circle-' + kind);
				if (kind === 'piano') {
					await tap('Tab', 9, 'Tab');
					await waitForLog(/BENCH QA keyboard view/, 'bench keyboard view', 10000);
					await sleep(900);
					await shot('piano-keyboard-view');
				}
				await tap('Escape', 27, 'Escape');
				await waitForLog(new RegExp('MUSIC QA closed ' + kind), kind + ' exit restores movement', 10000);
				if (kind !== 'gallery_piano') await tap('F8', 119, 'F8');
			}
			await tap('F9', 120, 'F9');
			await waitForLog(/MAZE QA path playable/, 'maze solution and solid walls', 30000);
			await waitForLog(/MAZE QA music active/, 'fountain music playback', 10000);
			await waitForLog(/MAZE QA guide station/, 'Milo directions in the maze court', 10000);
			await waitForLog(/MAZE QA overview ready/, 'maze overview', 10000);
			await shot('maze-overview');
			await waitForLog(/MAZE QA fountain ready/, 'fountain clearing', 10000);
			await shot('maze-fountain');
			await tap('KeyQ', 81, 'q');
			await waitForLog(/MAZE QA return works/, 'maze return to entrance', 10000);
			musicCirclePlayable = true;
		}
		if (castle && args.includes('--heart-journey')) {
			for (const name of ['heart_journey_web_qa.gd', 'heart_journey_web_qa.tscn']) {
				const source = fs.readFileSync(path.join(__dirname, 'qa', name), 'utf8').replace('res://tools/qa/heart_journey_web_qa.gd', '/tmp/heart_journey_web_qa.gd');
				await evaluate(`engine.copyToFS(${JSON.stringify('/tmp/' + name)}, new TextEncoder().encode(${JSON.stringify(source)}).buffer)`);
			}
			if (!await goTo('the Melody journey test', '/tmp/heart_journey_web_qa.tscn')) throw new Error('Journey fixture failed');
			await waitForLog(/JOURNEY QA ready/, 'garden presentation fixture', 20000);
			for (const stage of ['intro', 'transcript', 'harvest', 'journal', 'fountain', 'gate', 'instrument', 'river-organ', 'river-harp', 'river-bells', 'bridge-chimes', 'warning-crossing']) {
				const from = consoleLines.length;
				await evaluate(`window.arteaJourneyQA(${JSON.stringify(stage)})`);
				await waitForLog(new RegExp('JOURNEY QA stage ' + stage), stage + ' presentation', 10000, from);
				await sleep(stage === 'gate' ? 300 : 700);
				await shot('journey-' + stage);
				if (stage === 'transcript') {
					await waitForLog(/JOURNEY QA transcript page advanced/, 'transcript follows recorded playback', 60000, from);
					await shot('journey-transcript-next');
					await waitForLog(/JOURNEY QA voice ended and transcript hidden/, 'voice ends and transcript disappears', 60000, from);
				}
			}
		}
		areas.push(['the Art Castle', castle, castle ? await goTo('the Hub', HUB) : null, 'prefetched']);
		const KINGDOMS = [
			['Mind Spark', 'res://scenes/popThoughtsMenu.tscn'],
			['Heart Melody', 'res://scenes/music_minigame.tscn'],
			['Heart Melody valley', 'res://scenes/heart_melody/heart_melody_world.tscn'],
			["Creator's Light", 'res://scenes/drawing_tool.tscn'],
		];
		for (const [index, [label, scene]] of KINGDOMS.entries()) {
			const entered = await goTo(label, scene);
			if (entered) {
				await sleep(3000);
				await profile(label + '-idle');
				await profile(label + '-orbit', {orbit:true});
				await shot(`${String(8 + index).padStart(2, '0')}-${label.replace(/[^A-Za-z]+/g, '-').toLowerCase()}`);
			}
			areas.push([label, entered, entered ? await goTo('the Hub', HUB) : null, 'prefetched']);
		}

		const fatal = consoleLines.filter((l) => /new_scene" is null|No loader found|Failed to load scene|SceneLoader: could not open|SCRIPT ERROR|Parse Error|MUSIC QA FAILURE|OCEAN QA FAILURE|JOURNEY QA (?:FAILURE|flower answer did not|clearing did not|gate failed|fountain not|menu did not|missing control)/.test(l));

		fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
		reportMetrics();
		say('frame changed while moving: ' + moved);
		say('fatal resource errors: ' + fatal.length);
		fatal.slice(0, 5).forEach((l) => console.log('    ' + l.slice(0, 200)));

		console.log('\nareas (entered from the Hub, then back):');
		const MiB = 1048576;
		for (const [label, entered, back, when] of areas) {
			console.log(`  ${label.padEnd(24)} ${when.padEnd(19)} ${entered ? `entered in ${entered.seconds} s, ${(entered.bytes / MiB).toFixed(1)} MiB downloaded` : 'NOT ENTERED'}`
				+ `; back to the Hub: ${back ? 'yes' : 'NO'}`);
			const metric = label.replace(/^the /, '').replace(/[^A-Za-z]+/g, '_').toLowerCase();
			console.log(`METRIC bytes_${metric}=${entered ? entered.bytes : -1}`);
		}
		console.log(`  Art Castle playable (moves): ${castlePlayable ? 'yes' : 'NO'}`);
		const show = (p) => (p ? `median ${p.median.toFixed(1)} ms, p95 ${p.p95.toFixed(1)} ms over ${p.frames} frames` : 'too few frames to say');
		console.log('\nHub frame pacing (standing still):');
		console.log(`  during background download: ${show(during)}`);
		console.log(`  after it finished:          ${show(after)}`);
		console.log(`METRIC hub_frame_median_ms_prefetch=${during ? during.median.toFixed(1) : -1}`);
		console.log(`METRIC hub_frame_median_ms_idle=${after ? after.median.toFixed(1) : -1}`);

		// Prefetched areas: no download wait (a few hundred KB of manifests and
		// revalidation at most). The story went first, so it had to download.
		const noWait = areas.filter(([, , , when]) => when === 'prefetched')
			.every(([, entered]) => entered && entered.bytes < MiB);
		const fellBack = story !== null && story.bytes > MiB;
		// Not visibly slower: the median frame within 25% of the idle Hub's, or
		// still at 60 fps. A Hub idling at 80 fps that holds 60 while prefetching
		// has not visibly dropped; one sliding from 60 to 45 has.
		const smooth = !during || !after || during.median <= Math.max(after.median * 1.25, 1000 / 60 + 0.5);
		say(`prefetched areas entered without downloading: ${noWait}; story fell back to downloading: ${fellBack}; hub pacing held: ${smooth}`);
		const pass = moved && castlePlayable && musicCirclePlayable && areas.every(([, entered, back]) => entered && back)
			&& noWait && fellBack && smooth && !crashed() && fatal.length === 0;

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
