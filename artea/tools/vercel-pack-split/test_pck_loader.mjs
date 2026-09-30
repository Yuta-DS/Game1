import assert from "node:assert/strict";

const originalFetch = globalThis.fetch;
let firstPartAttempts = 0;
const requestedUrls = [];
const firstPartCacheModes = [];

const gzip = async (text) => {
	const source = new Blob([text]).stream();
	return new Uint8Array(await new Response(
		source.pipeThrough(new CompressionStream("gzip")),
	).arrayBuffer());
};
const firstPart = await gzip("abc");
const secondPart = await gzip("def");

globalThis.window = {
	location: { href: "https://example.test/?build=loader-test" },
	setTimeout,
	clearTimeout,
	fetch: async (input, init = {}) => {
		const url = String(input);
		requestedUrls.push(url);
		if (url.includes(".parts.json")) {
			return new Response(JSON.stringify({
				count: 2,
				bytes: 6,
				partBytes: 3,
				encoding: "gzip",
			}), {
				status: 200,
				headers: { "Content-Type": "application/json" },
			});
		}
		if (url.includes("part00.gz")) {
			firstPartAttempts += 1;
			firstPartCacheModes.push(init.cache);
			if (firstPartAttempts == 1) {
				return {
					ok: true,
					status: 200,
					headers: new Headers({ "Content-Length": "3" }),
					arrayBuffer: async () => { throw new Error("simulated stalled part"); },
				};
			}
			return new Response(firstPart, { status: 200 });
		}
		if (url.includes("part01.gz")) {
			// Some browser providers hide Content-Length. The manifest remains the
			// authoritative integrity source in that environment.
			return new Response(secondPart, { status: 200 });
		}
		throw new Error(`Unexpected fetch ${url}`);
	},
};

await import("./pck-loader.js");
const response = await window.fetch("https://example.test/index.pck");
const joined = new TextDecoder().decode(await response.arrayBuffer());

assert.equal(joined, "abcdef", "retried parts must reassemble without partial bytes");
assert.equal(firstPartAttempts, 2, "a failed part is retried exactly once before success");
assert.deepEqual(firstPartCacheModes, ["default", "reload"],
	"a retry bypasses the failed response while completed parts remain cacheable");
assert.equal(response.headers.get("Content-Length"), "6");
assert(requestedUrls.every((url) => url.includes("build=loader-test")),
	"every manifest and part request keeps the cache-busting build identity");
assert(requestedUrls.filter((url) => url.includes(".part0")).every((url) => url.endsWith(".gz?build=loader-test")),
	"gzip manifests must request compressed pack parts");

globalThis.fetch = originalFetch;
console.log("PCK_LOADER_TEST: PASS — gzip parts retried and six-byte pack reassembled exactly");
