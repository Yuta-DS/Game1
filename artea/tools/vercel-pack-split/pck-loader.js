// Vercel limits individual deployment files to 100 MB. Godot normally emits
// one large .pck, so the export script splits it and this fetch shim rejoins
// the parts in browser memory before the engine starts.
(() => {
	const nativeFetch = window.fetch.bind(window);
	// Fallback bound for older builds that do not provide a part manifest.
	// Bounding the
	// search keeps a hung probe from stalling startup forever: the previous
	// version walked parts with an unbounded `for (;;)` and awaited each HEAD in
	// turn, so one request that never settled meant the pack was never fetched
	// and the engine sat at the loading screen with no error.
	const MAX_PARTS = 128;

	const buildKey = new URL(window.location.href).searchParams.get("build");
	const partUrl = (requestUrl, index) => {
		const url = new URL(
			`${requestUrl}.part${String(index).padStart(2, "0")}`,
			window.location.href,
		);
		if (buildKey) {
			url.searchParams.set("build", buildKey);
		}
		return url.toString();
	};

	// Probe in parallel, then count the leading run of hits. Sequential probing
	// cost one round trip per part before the download could start.
	// Byte totals from each manifest, keyed by request URL.
	const manifestBytes = new Map();
	// Content-hashed part paths from each manifest (split-pack.sh), keyed by
	// request URL. Absent for the older count-only manifest.
	const manifestParts = new Map();

	const countParts = async (requestUrl) => {
		const manifestUrl = new URL(`${requestUrl}.parts.json`, window.location.href);
		if (buildKey) {
			manifestUrl.searchParams.set("build", buildKey);
		}
		try {
			// The manifest is the one file that must never come from a cache: it
			// is what points the build at its own export's parts.
			const manifestResponse = await nativeFetch(manifestUrl, { cache: "no-store" });
			if (manifestResponse.ok) {
				const manifest = await manifestResponse.json();
				if (Array.isArray(manifest.parts) && manifest.parts.length > 0) {
					manifestParts.set(requestUrl, manifest.parts.map((part) => part.name));
				}
				if (Number.isInteger(manifest.count) && manifest.count > 0) {
					// Keep the byte total: the streamed Response needs a
					// Content-Length, and streaming means it cannot be measured
					// from an assembled Blob any more.
					if (Number.isInteger(manifest.bytes)) {
						manifestBytes.set(requestUrl, manifest.bytes);
					}
					return manifest.count;
				}
			}
		} catch (_error) {
			// Fall through to bounded probing for backward-compatible builds.
		}
		const probes = Array.from({ length: MAX_PARTS }, (_, index) =>
			nativeFetch(partUrl(requestUrl, index), { method: "HEAD", cache: "no-store" })
				.then((response) => response.ok)
				.catch(() => false),
		);
		const present = await Promise.all(probes);
		const missing = present.indexOf(false);
		return missing === -1 ? MAX_PARTS : missing;
	};

	// Parts in flight at once (issue #34). One at a time left the connection
	// idle for a round trip between every part; a handful in parallel keeps it
	// busy. Bounded rather than all at once: every part that arrives ahead of
	// its turn is held in memory until the engine reaches it, and holding the
	// whole pack twice (~1.5 GB) is what used to hang or kill the tab against
	// wasm32's 4 GB address space. 4 x 8 MB parts is a 32 MB peak. ?parts=N
	// overrides it, for measuring (docs/web-baseline.md).
	const DEFAULT_CONCURRENCY = 4;
	const concurrency = (() => {
		const requested = Number.parseInt(
			new URL(window.location.href).searchParams.get("parts"), 10);
		return requested >= 1 && requested <= 16 ? requested : DEFAULT_CONCURRENCY;
	})();
	// A failed part is retried this many times, waiting longer each time,
	// before the player is asked. Hosts drop the odd request, and a 404 can be a
	// part not yet propagated through a CDN; both usually clear on their own.
	const RETRY_DELAYS_MS = [500, 1500, 4000];

	const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

	// One "couldn't download" overlay for every failing part. The download is
	// paused, not abandoned: the engine is still waiting on the stream, so
	// Retry carries on from the part that failed and never re-fetches the parts
	// already handed over. Nothing reaches the engine half-loaded.
	let retryOverlay = null;
	let retryWaiters = [];
	const askToRetry = (error) => new Promise((resolve) => {
		retryWaiters.push(resolve);
		console.error(`pck-loader: giving up for now on ${error.message}`);
		if (retryOverlay) return;
		retryOverlay = document.createElement("div");
		retryOverlay.id = "pck-loader-retry";
		retryOverlay.setAttribute("role", "alertdialog");
		retryOverlay.setAttribute("aria-label", "Download problem");
		retryOverlay.style.cssText = "position:fixed;inset:0;z-index:2147483647;display:flex;"
			+ "align-items:center;justify-content:center;background:rgba(0,0,0,0.6);"
			+ "font:16px/1.4 system-ui,sans-serif;color:#fff;";
		const box = document.createElement("div");
		box.style.cssText = "max-width:420px;margin:16px;padding:24px;border-radius:12px;"
			+ "background:#1e1b2e;text-align:center;box-shadow:0 8px 32px rgba(0,0,0,0.5);";
		const message = document.createElement("p");
		message.style.margin = "0 0 16px";
		message.textContent = "Part of the game couldn't be downloaded. "
			+ "Check your connection, then try again. Nothing already downloaded is lost.";
		const button = document.createElement("button");
		button.type = "button";
		button.textContent = "Retry";
		button.style.cssText = "font:inherit;padding:10px 28px;border:0;border-radius:8px;"
			+ "background:#f2c14e;color:#1e1b2e;cursor:pointer;";
		button.addEventListener("click", () => {
			retryOverlay.remove();
			retryOverlay = null;
			const waiting = retryWaiters;
			retryWaiters = [];
			waiting.forEach((resume) => resume());
		});
		box.append(message, button);
		retryOverlay.append(box);
		document.body.append(retryOverlay);
		button.focus();
	});

	// Area Packs the player is waiting on right now (issue #38). While any is,
	// every other Pack's background download holds its next part back, so the
	// player's load gets the connection.
	const foreground = new Set();
	const waitTurn = async (pack) => {
		while (pack && foreground.size > 0 && !foreground.has(pack)) {
			await sleep(250);
		}
	};

	// One whole part, retried until it arrives. Buffered rather than streamed
	// so a connection that drops halfway through a part costs only that part:
	// nothing from it has reached the engine yet, so it simply starts again.
	// `pack` names the area Pack being fetched, if any: one only prefetched in
	// the background gives up quietly instead of asking the player to retry,
	// and the loading screen fetches it again when the player goes there.
	const fetchPart = async (url, init, pack) => {
		for (let attempt = 0; ; attempt += 1) {
			try {
				const response = await nativeFetch(url, init);
				if (!response.ok) {
					throw new Error(`${url} returned ${response.status}`);
				}
				return new Uint8Array(await response.arrayBuffer());
			} catch (error) {
				if (attempt < RETRY_DELAYS_MS.length) {
					console.warn(`pck-loader: ${error.message}, retrying`);
					await sleep(RETRY_DELAYS_MS[attempt]);
				} else if (pack && !foreground.has(pack)) {
					throw error;
				} else {
					await askToRetry(error);
					attempt = -1;
				}
			}
		}
	};

	// Up to `concurrency` parts download at once, but the engine reads them
	// strictly in order: pull() hands over part N only once it has arrived and
	// then starts the next one, so the window slides along the pack.
	const streamParts = (requestUrl, partCount, pack) => {
		const hashed = manifestParts.get(requestUrl);
		// Hashed parts are named by content, so the browser's normal HTTP cache
		// is safe for them and the host marks them immutable: a repeat visit
		// re-downloads none. No ?build= key either, which would only stop
		// identical parts being reused across deploys. The older unhashed layout
		// keeps its no-store fetch.
		const fetchIndex = async (index) => {
			await waitTurn(pack);
			return fetchPart(
				hashed ? new URL(hashed[index], window.location.href).toString()
					: partUrl(requestUrl, index),
				hashed ? {} : { cache: "no-store" }, pack);
		};
		const inFlight = new Map();
		let nextToSend = 0;
		let nextToStart = 0;
		const topUp = () => {
			while (nextToStart < partCount && nextToStart < nextToSend + concurrency) {
				inFlight.set(nextToStart, fetchIndex(nextToStart));
				nextToStart += 1;
			}
		};
		return new ReadableStream({
			start() {
				topUp();
			},
			async pull(controller) {
				const bytes = await inFlight.get(nextToSend);
				inFlight.delete(nextToSend);
				nextToSend += 1;
				topUp();
				controller.enqueue(bytes);
				if (nextToSend >= partCount) {
					controller.close();
				}
			},
		});
	};

	window.fetch = async (input, init) => {
		const requestUrl = typeof input === "string" ? input : input.url;
		const url = new URL(requestUrl, window.location.href);

		// The pack is not the only file that has to be split. Cloudflare Pages
		// rejects any single file over 25 MB, and index.side.wasm (the
		// GDExtension side module) is 42 MB, so it is split the same way and
		// rejoined here. Serving it pre-gzipped is not an option: Cloudflare
		// strips a manually set Content-Encoding, so the browser receives gzip
		// bytes where it expects a wasm module and refuses to instantiate it.
		// Every .pck is split: index.pck (Core) and each area Pack the game
		// fetches when the player first enters that area (ADR-0001), so a Pack
		// gets the same parallel, retrying, resumable download as the first load.
		if (!url.pathname.endsWith(".pck") && !url.pathname.endsWith("/index.side.wasm")) {
			return nativeFetch(input, init);
		}

		const partCount = await countParts(requestUrl);
		if (partCount === 0) {
			return nativeFetch(input, init);
		}

		// `init` is deliberately not forwarded to the part requests. It applies to
		// the pack as a whole, and a Range header replayed against every part
		// would slice each one and corrupt the join.
		// `pack.size` used to come from the assembled Blob. Streaming removed the
		// Blob, so the size comes from the manifest instead; without this the
		// loader threw "pack is not defined" and nothing loaded at all.
		const headers = { "Content-Type": "application/octet-stream" };
		const totalBytes = manifestBytes.get(requestUrl);
		if (Number.isInteger(totalBytes)) {
			headers["Content-Length"] = String(totalBytes);
		}

		// arteaPack (set by arteaPacks below) names the area Pack, so its parts
		// can yield to the one the player is waiting on.
		return new Response(streamParts(requestUrl, partCount, init && init.arteaPack), {
			status: 200,
			headers,
		});
	};

	// Area Packs (ADR-0001, issue #35). The game asks for one by file name when
	// the player first heads into its area; the page downloads it through the
	// fetch above (parts, in parallel, retried, with the Retry overlay) and
	// writes it into the engine's file system with the engine's own copyToFS,
	// as Godot does for the files it loads at boot. The game polls `state` for
	// progress and mounts the file once `done`. Doing the download here rather
	// than through Godot's HTTPRequest matters: that reads a fixed chunk per
	// frame, and the loading screen runs at a few frames per second, so 137 MB
	// took ten minutes.
	//
	// Once the Hub is playable the game also hands over every Pack it has not
	// mounted, most likely next first (issue #38), and they download one after
	// another in the background. A Pack is downloaded once, whoever asks first:
	// entering an area whose Pack is already here skips the download, and one
	// still arriving shows its progress on the loading screen. Background
	// downloads stay in memory; copying one into the engine's file system is a
	// long main-thread block, so it waits for the loading screen.
	const buffers = new Map();  // file -> its bytes, until written for the engine
	const downloads = new Map();  // file -> the download's promise
	window.arteaPacks = {
		// Plain fields only: the game reads one as JSON every frame.
		state: {},
		prefetch: { queue: [], running: false, startedAt: null, doneAt: null },
		download(file) {
			const known = this.state[file];
			if (known && !known.error) {
				return downloads.get(file);
			}
			// Times are performance.now(), for seeing what the background held back.
			const state = { loaded: 0, total: 0, downloaded: false, done: false, error: "",
				startedAt: performance.now(), wantedAt: null, finishedAt: null };
			this.state[file] = state;
			const download = (async () => {
				const response = await window.fetch(new URL(file, window.location.href).toString(),
					{ arteaPack: file });
				if (!response.ok) {
					throw new Error(`${file} returned ${response.status}`);
				}
				// The size comes from the Pack's parts manifest, so the bytes go
				// straight into one buffer. copyToFS wraps that buffer rather than
				// copying it, so the Pack is held twice only while the file system
				// takes its own copy.
				state.total = Number(response.headers.get("Content-Length"));
				if (!(state.total > 0)) {
					throw new Error(`${file} has no parts manifest`);
				}
				const bytes = new Uint8Array(state.total);
				const reader = response.body.getReader();
				for (;;) {
					const { done, value } = await reader.read();
					if (done) break;
					bytes.set(value, state.loaded);
					state.loaded += value.byteLength;
				}
				buffers.set(file, bytes);
				state.downloaded = true;
				state.finishedAt = performance.now();
			})().catch((error) => {
				state.error = String(error && error.message ? error.message : error);
			});
			downloads.set(file, download);
			return download;
		},
		// The loading screen's request: this Pack now, written where the game
		// mounts it. Other Packs' background downloads hold back meanwhile.
		fetch(file, path) {
			foreground.add(file);
			(async () => {
				const download = this.download(file);
				this.state[file].wantedAt = performance.now();
				await download;
				const state = this.state[file];
				if (!state.error) {
					engine.copyToFS(path, buffers.get(file).buffer);
					buffers.delete(file);
					state.done = true;
				}
			})().finally(() => foreground.delete(file));
		},
		// Background downloads, one at a time, in the order given. A later call
		// (another return to the Hub) adds any Packs not queued yet.
		startPrefetch(files) {
			const prefetch = this.prefetch;
			prefetch.queue.push(...files.filter((file) => !prefetch.queue.includes(file)));
			if (prefetch.running) return;
			prefetch.running = true;
			prefetch.startedAt = prefetch.startedAt ?? performance.now();
			(async () => {
				for (let i = 0; i < prefetch.queue.length; i += 1) {
					await this.download(prefetch.queue[i]);
				}
				prefetch.running = false;
				prefetch.doneAt = performance.now();
			})();
		},
	};
})();
