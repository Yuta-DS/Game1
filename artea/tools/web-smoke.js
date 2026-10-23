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
const storyProbe = new URL(url).searchParams.get('world_one_story') === '1';
const latencyMs = Number(option('--latency') ?? 0);
const mbps = Number(option('--mbps') ?? 0);
const failPart = option('--fail-part');
const failTimes = Number(option('--fail-times') ?? 2);
// Requests pck-loader.js makes for one part before showing its Retry overlay:
// the first try plus RETRY_DELAYS_MS.length retries.
const LOADER_ATTEMPTS = 4;
const qualityProbe = new URL(url).searchParams.get('world_one_quality') === '1';
const portalKeyAudit = new URL(url).searchParams.get('portal_key_audit') === '1';
const galaxyAudit = new URL(url).searchParams.get('galaxy_audit');
const galleryAudit = new URL(url).searchParams.get('gallery_audit') === '1';
const hubRockAudit = new URL(url).searchParams.get('hub_rock_audit') === '1';
const targetScene = storyProbe || qualityProbe || galaxyAudit || galleryAudit
	? 'art_gallery_3d_inprogress.tscn' : 'New_Hub_World.tscn';
const sceneReadyPattern = new RegExp(`\\[ARTEA\\] scene ready res://scenes/${targetScene.replace('.', '\\.')}`);
const DEBUG_PORT = 9222;

// The Offline Guest button, in the 1280x800 viewport the script emulates. The
// current login screen puts it at y=537; older deployments used y=568 or
// y=726. Tried in order until one is accepted.
const VIEWPORT = { width: 1280, height: 800 };
const GUEST_BUTTONS = [{ x: 287, y: 537 }, { x: 287, y: 568 }, { x: 300, y: 726 }];

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
			if (net.hubAt === null && sceneReadyPattern.test(line)) {
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
			const runtimeError = consoleLines.find((line) => /Uncaught RuntimeError:/.test(line));
			if (runtimeError) throw new Error(runtimeError);
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
				await waitForLog(/GUEST access selected/, 'guest login accepted', 60000);
				break;
			} catch (err) {
				if (index === GUEST_BUTTONS.length - 1 || /Uncaught RuntimeError:/.test(err.message)) throw err;
			}
		}
		if (portalKeyAudit) {
			if (!qualityProbe) throw new Error('portal_key_audit requires world_one_quality=1');
			for (const portalName of ['MindSparkWorldGate', 'EntryWorldGate', 'ReturnToArtCastleWorldGate']) {
				await waitForLog(new RegExp(`WORLD_ONE_PORTAL_READY: ${portalName}`),
					`${portalName} ready for browser Q`, 180000);
				await click(VIEWPORT.width / 2, VIEWPORT.height / 2);
				await key('keyDown', 'KeyQ', 81);
				await sleep(180);
				await key('keyUp', 'KeyQ', 81);
			}
		}
		await waitForLog(sceneReadyPattern, 'destination scene built', 120000);
		if (storyProbe) {
			await waitForLog(/WORLD_ONE_WEB_STORY: /, 'World One story probe completed', 180000);
			const reportLine = consoleLines.find((line) => line.startsWith('WORLD_ONE_WEB_STORY: '));
			const report = JSON.parse(reportLine.slice('WORLD_ONE_WEB_STORY: '.length));
			if (!report.ok) throw new Error('World One story probe failed: ' + JSON.stringify(report.errors));
		}
		if (qualityProbe) {
			await waitForLog(/WORLD_ONE_WEB_QUALITY: /, 'World One quality probe completed', 180000);
			const reportLine = consoleLines.find((line) => line.startsWith('WORLD_ONE_WEB_QUALITY: '));
			const report = JSON.parse(reportLine.slice('WORLD_ONE_WEB_QUALITY: '.length));
			if (!report.ok) throw new Error('World One quality probe failed: ' + JSON.stringify(report.errors));
			if (report.gate_traveler !== 'production_player') {
				throw new Error('World One gates were not crossed by the production player');
			}
		}
		if (galaxyAudit) {
			await waitForLog(/GALAXY_WEB_AUDIT: /, 'Galaxy ground audit completed', 180000);
			const reportLine = consoleLines.find((line) => line.startsWith('GALAXY_WEB_AUDIT: '));
			const report = JSON.parse(reportLine.slice('GALAXY_WEB_AUDIT: '.length));
			if (!report.ok || report.view !== galaxyAudit) {
				throw new Error('Galaxy ground audit failed: ' + JSON.stringify(report));
			}
		}
		if (galleryAudit) {
			await waitForLog(/GALLERY_WEB_AUDIT: /, 'gallery artwork audit completed', 180000);
			const reportLine = consoleLines.find((line) => line.startsWith('GALLERY_WEB_AUDIT: '));
			const report = JSON.parse(reportLine.slice('GALLERY_WEB_AUDIT: '.length));
			if (!report.ok) throw new Error('Gallery artwork audit failed: ' + JSON.stringify(report));
		}
		if (hubRockAudit) {
			await waitForLog(/HUB_ROCK_AUDIT: /, 'hub rock removal audit completed', 180000);
			const reportLine = consoleLines.find((line) => line.startsWith('HUB_ROCK_AUDIT: '));
			const report = JSON.parse(reportLine.slice('HUB_ROCK_AUDIT: '.length));
			if (!report.ok) throw new Error('Hub rock removal audit failed: ' + JSON.stringify(report));
		}
		await sleep(8000);
		const before = await shot(galaxyAudit ? `02-galaxy-${galaxyAudit}`
			: galleryAudit ? '02-gallery-audit' : hubRockAudit ? '02-hub-rock-audit' : '02-in-hub');

		// A frozen game returns byte-identical frames, so movement is the check
		// that separates "rendered once" from "playable". Galaxy audit mode
		// already walks a real CharacterBody3D and uses a fixed review camera.
		const identical = (a, b) => a.length === b.length && a.equals(b);
		let moved = true;
		if (!galaxyAudit && !hubRockAudit) {
			say('holding W to test movement');
			await click(VIEWPORT.width / 2, VIEWPORT.height / 2);
			await key('keyDown', 'KeyW', 87);
			await sleep(2500);
			const during = await shot('03-moving');
			await key('keyUp', 'KeyW', 87);
			await sleep(1500);
			const after = await shot('04-after-move');
			moved = !identical(before, during) || !identical(during, after);
		}
		const fatal = consoleLines.filter((l) => /new_scene" is null|No loader found|Failed to load scene|Uncaught RuntimeError:/.test(l));

		fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
		reportMetrics();
		say(galaxyAudit ? 'real player walk verified by Galaxy audit'
			: hubRockAudit ? 'fixed hub rock removal view verified' : 'frame changed while moving: ' + moved);
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
