// Prove a served web build actually plays, not merely that it renders a frame.
//
// Startup failures on web are quiet: a missing export dependency makes
// change_scene_to_packed receive null, so clicking through does nothing at all
// and the page looks like a slow load rather than a broken build. This drives
// the real thing - loads the page, clicks Offline Guest, waits for the hub to
// report itself built, then holds a movement key and checks the frame changed.
//
//   node artea/tools/web-smoke.js [url] [--out DIR] [--keep-open]
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
const heartPreview = args.includes('--heart');
const DEBUG_PORT = 9337;

// The Offline Guest button, in the 1280x800 viewport the script emulates.
const VIEWPORT = { width: 1280, height: 800 };
const GUEST_BUTTON = { x: 300, y: 726 };

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
	const consoleLines = [];
	let crashed = false;

	ws.addEventListener('message', (ev) => {
		const m = JSON.parse(ev.data);
		if (m.id && pending.has(m.id)) {
			const { resolve, reject } = pending.get(m.id);
			pending.delete(m.id);
			return m.error ? reject(new Error(JSON.stringify(m.error))) : resolve(m.result);
		}
		if (m.method === 'Runtime.consoleAPICalled') {
			consoleLines.push((m.params.args || []).map((a) => a.value ?? a.description ?? a.type).join(' '));
			fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
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
	return { send, consoleLines, crashed: () => crashed, targetId: target.id };
}

(async () => {
	const t0 = Date.now();
	const stamp = () => `${((Date.now() - t0) / 1000).toFixed(1).padStart(6)}s `;
	const say = (msg) => console.log(stamp() + msg);

	fs.mkdirSync(outDir, { recursive: true });
	const browserProcess = await startChrome();
	const { send, consoleLines, crashed, targetId } = await connect();

	await send('Emulation.setDeviceMetricsOverride', { ...VIEWPORT, deviceScaleFactor: 1, mobile: false });
	await send('Runtime.enable');
	await send('Page.enable');
	await send('Page.bringToFront');
	await send('Emulation.setFocusEmulationEnabled', { enabled: true });

	const shot = async (name) => {
		const s = await send('Page.captureScreenshot', { format: 'png' });
		const buf = Buffer.from(s.data, 'base64');
		fs.writeFileSync(path.join(outDir, `${name}.png`), buf);
		return buf;
	};
	const waitForLog = async (re, label, timeoutMs) => {
		const until = Date.now() + timeoutMs;
		while (Date.now() < until) {
			if (crashed()) throw new Error('renderer crashed (out of memory is the usual cause)');
			if (consoleLines.some((l) => re.test(l))) {
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
		await send('Page.navigate', { url });
		await waitForLog(/engine started/, 'engine started', 180000);
		await sleep(4000);
		await shot('01-start-screen');
		const previewState = await send('Runtime.evaluate', { expression: 'String(window.ARTEA_HEART_PREVIEW)', returnByValue: true });
		say('preview flag: ' + previewState.result.value);

		if (heartPreview) {
			await waitForLog(/HEART CHAPTER READY/, 'Heart Melody chapter ready', 120000);
			await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
			await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
		} else {
			say('clicking Offline Guest');
			await click(GUEST_BUTTON.x, GUEST_BUTTON.y);
			await waitForLog(/GUEST access selected/, 'guest login accepted', 20000);
			await waitForLog(/ARTEA WORLD READY:/, 'world loading and shader warmup complete', 240000);
		}
		const webgl = await send('Runtime.evaluate', { expression: "!!document.createElement('canvas').getContext('webgl2')", returnByValue: true });
		if (webgl.result.value !== true) throw new Error('WebGL2 unavailable');
		say('WebGL2 available');
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
		const fatal = consoleLines.filter((l) => /new_scene" is null|No loader found|Failed to load scene|SCRIPT ERROR|Parse Error|EXCEPTION/.test(l));

		fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
		say('frame changed while moving: ' + moved);
		say('fatal resource errors: ' + fatal.length);
		fatal.slice(0, 5).forEach((l) => console.log('    ' + l.slice(0, 200)));

		const pass = moved && !crashed() && fatal.length === 0;
		console.log('\nscreenshots: ' + outDir);
		console.log('RESULT: ' + (pass ? 'PLAYABLE' : 'NOT PLAYABLE'));
		if (!keepOpen) await cdp(`/json/close/${targetId}`).catch(() => {});
		if (!keepOpen && browserProcess) browserProcess.kill();
		process.exit(pass ? 0 : 1);
	} catch (err) {
		fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
		console.log('\nFAILED: ' + err.message);
		console.log('console tail:');
		consoleLines.slice(-15).forEach((l) => console.log('    ' + l.slice(0, 200)));
		console.log('screenshots: ' + outDir);
		if (!keepOpen) await cdp(`/json/close/${targetId}`).catch(() => {});
		if (!keepOpen && browserProcess) browserProcess.kill();
		process.exit(2);
	}
})();
