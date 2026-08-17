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

	// Fetch one at a time. Requesting all pack parts at once
	// holds two copies of the pack in memory at peak and mobile Safari drops the
	// tab under that pressure.
	const fetchParts = async (requestUrl, partCount) => {
		const parts = [];
		for (let index = 0; index < partCount; index += 1) {
			const url = partUrl(requestUrl, index);
			const response = await nativeFetch(url, { cache: "no-store" });

			if (!response.ok) {
				throw new Error(`${url} returned ${response.status}`);
			}

			parts.push(await response.arrayBuffer());
		}
		return parts;
	};

	window.fetch = async (input, init) => {
		const requestUrl = typeof input === "string" ? input : input.url;
		const url = new URL(requestUrl, window.location.href);

		if (!url.pathname.endsWith("/index.pck")) {
			return nativeFetch(input, init);
		}

		const partCount = await countParts(requestUrl);
		if (partCount === 0) {
			return nativeFetch(input, init);
		}

		// `init` is deliberately not forwarded to the part requests. It applies to
		// the pack as a whole, and a Range header replayed against every part
		// would slice each one and corrupt the join.
		const parts = await fetchParts(requestUrl, partCount);
		const pack = new Blob(parts, { type: "application/octet-stream" });

		return new Response(pack, {
			status: 200,
			headers: {
				"Content-Length": String(pack.size),
				"Content-Type": "application/octet-stream",
			},
		});
	};
})();
