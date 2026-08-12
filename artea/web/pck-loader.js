// Vercel limits individual deployment files to 100 MB. Godot normally emits
// one large .pck, so the export script splits it and this fetch shim rejoins
// the parts in browser memory before the engine starts.
(() => {
	const nativeFetch = window.fetch.bind(window);

	window.fetch = async (input, init) => {
		const requestUrl = typeof input === "string" ? input : input.url;
		const url = new URL(requestUrl, window.location.href);

		if (!url.pathname.endsWith("/index.pck")) {
			return nativeFetch(input, init);
		}

		const partUrls = [];
		for (let index = 0; ; index += 1) {
			const suffix = String(index).padStart(2, "0");
			const partUrl = `${requestUrl}.part${suffix}`;
			const partResponse = await nativeFetch(partUrl, { method: "HEAD" });

			if (!partResponse.ok) {
				if (index === 0) {
					return nativeFetch(input, init);
				}
				break;
			}

			partUrls.push(partUrl);
		}

		const partResponses = await Promise.all(
			partUrls.map((partUrl) => nativeFetch(partUrl, init)),
		);
		const parts = await Promise.all(
			partResponses.map((partResponse) => partResponse.arrayBuffer()),
		);
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
