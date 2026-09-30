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
	const PART_TIMEOUT_MS = 45000;
	// Mobile connections and large cold-cache Vercel responses can fail after a
	// part has already transferred most of its bytes. Three rapid retries were
	// too short to outlive a transient edge failure and forced the player to
	// restart the entire 445 MB download. Keep the attempts bounded, but spread
	// them out enough for the route to recover.
	const PART_ATTEMPTS = 6;
	const MAX_RETRY_DELAY_MS = 8000;

	const buildKey = new URL(window.location.href).searchParams.get("build");
	const partUrl = (requestUrl, index, extension = "") => {
		const url = new URL(
			`${requestUrl}.part${String(index).padStart(2, "0")}${extension}`,
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
	const manifestPartBytes = new Map();
	const manifestEncodings = new Map();

	const countParts = async (requestUrl) => {
		const manifestUrl = new URL(`${requestUrl}.parts.json`, window.location.href);
		if (buildKey) {
			manifestUrl.searchParams.set("build", buildKey);
		}
		try {
			const manifestResponse = await nativeFetch(manifestUrl, { cache: "no-store" });
			if (manifestResponse.ok) {
				const manifest = await manifestResponse.json();
				if (Number.isInteger(manifest.count) && manifest.count > 0) {
					// Keep the byte total: the streamed Response needs a
					// Content-Length, and streaming means it cannot be measured
					// from an assembled Blob any more.
					if (Number.isInteger(manifest.bytes)) {
						manifestBytes.set(requestUrl, manifest.bytes);
					}
					if (Number.isInteger(manifest.partBytes) && manifest.partBytes > 0) {
						manifestPartBytes.set(requestUrl, manifest.partBytes);
					}
					if (manifest.encoding === "gzip") {
						if (typeof DecompressionStream !== "function") {
							throw new Error("This browser cannot decompress the Web game pack");
						}
						manifestEncodings.set(requestUrl, manifest.encoding);
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

	const pause = (milliseconds) => new Promise((resolve) =>
		window.setTimeout(resolve, milliseconds),
	);

	const fetchPart = async (requestUrl, index) => {
		const encoding = manifestEncodings.get(requestUrl);
		const url = partUrl(requestUrl, index, encoding === "gzip" ? ".gz" : "");
		let lastError;
		for (let attempt = 1; attempt <= PART_ATTEMPTS; attempt += 1) {
			const abort = new AbortController();
			const timeout = window.setTimeout(() => abort.abort(), PART_TIMEOUT_MS);
			try {
				const response = await nativeFetch(url, {
					// The build query makes every release immutable. Let a reload reuse
					// parts that finished successfully, while a retry bypasses a failed
					// edge response and refreshes that one cache entry.
					cache: attempt === 1 ? "default" : "reload",
					signal: abort.signal,
				});
				if (!response.ok) {
					throw new Error(`${url} returned ${response.status}`);
				}
				let bytes;
				if (encoding === "gzip") {
					if (!response.body) {
						throw new Error(`${url} returned no response body`);
					}
					const decompressed = response.body.pipeThrough(
						new DecompressionStream("gzip"),
					);
					bytes = new Uint8Array(await new Response(decompressed).arrayBuffer());
				} else {
					bytes = new Uint8Array(await response.arrayBuffer());
				}
				const totalBytes = manifestBytes.get(requestUrl);
				const partBytes = manifestPartBytes.get(requestUrl);
				const expectedLength = Number.isInteger(totalBytes) && Number.isInteger(partBytes)
					? Math.min(partBytes, totalBytes - index * partBytes)
					: null;
				const lengthHeader = encoding === "gzip"
					? null : response.headers.get("Content-Length");
				const declaredLength = lengthHeader === null || lengthHeader === ""
					? null : Number(lengthHeader);
				const verifiedLength = Number.isInteger(expectedLength)
					? expectedLength : declaredLength;
				if (Number.isInteger(verifiedLength) && verifiedLength >= 0
						&& bytes.byteLength !== verifiedLength) {
					throw new Error(
						`${url} was truncated (${bytes.byteLength}/${verifiedLength} bytes)`,
					);
				}
				return bytes;
			} catch (error) {
				lastError = error;
				if (attempt < PART_ATTEMPTS) {
					const retryDelay = Math.min(
						MAX_RETRY_DELAY_MS,
						500 * (2 ** (attempt - 1)),
					);
					console.warn(
						`[ARTEA] retrying pack part ${index + 1}; attempt ${attempt + 1}/${PART_ATTEMPTS} in ${retryDelay}ms`,
					);
					await pause(retryDelay);
				}
			} finally {
				window.clearTimeout(timeout);
			}
		}
		throw new Error(
			`Failed to download pack part ${index + 1} after ${PART_ATTEMPTS} attempts: ${lastError}`,
		);
	};

	// Fetch one part at a time. Requesting all pack parts at once holds two
	// copies of the pack in memory at peak and mobile Safari drops the tab under
	// that pressure. An 8 MB part is buffered before it is enqueued so a stalled
	// or truncated request can be retried without leaking partial bytes into the
	// assembled PCK. Peak JS cost stays one part rather than the full pack.
	//
	// The previous version awaited response.arrayBuffer() for every part and
	// kept them all, then copied the lot into a Blob - so a 748 MB pack existed
	// twice in JS memory (~1.5 GB) before Godot mounted its own copy. Against
	// wasm32's 4 GB address space that was enough to hang or kill the tab.
	//
	// A ReadableStream hands each chunk straight to the consumer and drops it,
	// so peak cost is one part (8 MB) rather than the whole pack.
	const streamParts = (requestUrl, partCount) => new ReadableStream({
		async start(controller) {
			try {
				for (let index = 0; index < partCount; index += 1) {
					controller.enqueue(await fetchPart(requestUrl, index));
				}
				controller.close();
			} catch (error) {
				controller.error(error);
			}
		},
	});

	window.fetch = async (input, init) => {
		const requestUrl = typeof input === "string" ? input : input.url;
		const url = new URL(requestUrl, window.location.href);

		// The pack is not the only file that has to be split. Cloudflare Pages
		// rejects any single file over 25 MB, and index.side.wasm (the
		// GDExtension side module) is 42 MB, so it is split the same way and
		// rejoined here. Serving it pre-gzipped is not an option: Cloudflare
		// strips a manually set Content-Encoding, so the browser receives gzip
		// bytes where it expects a wasm module and refuses to instantiate it.
		const splittable = ["/index.pck", "/index.side.wasm"];
		if (!splittable.some((name) => url.pathname.endsWith(name))) {
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

		return new Response(streamParts(requestUrl, partCount), {
			status: 200,
			headers,
		});
	};
})();
