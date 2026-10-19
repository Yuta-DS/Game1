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
const thirdPart = await gzip("ghi");
const sha256 = async (bytes) => Array.from(new Uint8Array(
	await globalThis.crypto.subtle.digest("SHA-256", bytes),
), (value) => value.toString(16).padStart(2, "0")).join("");
const expectedHashes = await Promise.all(
	[firstPart, secondPart, thirdPart].map(sha256),
);
const staleSecondPart = await gzip("xyz");
let secondPartAttempts = 0;
const secondPartCacheModes = [];

globalThis.window = {
	location: { href: "https://example.test/?build=loader-test" },
	setTimeout,
	clearTimeout,
	fetch: async (input, init = {}) => {
		const url = String(input);
		requestedUrls.push(url);
		if (url.includes(".parts.json")) {
			return new Response(JSON.stringify({
				count: 3,
				bytes: 9,
				partBytes: 3,
				encoding: "gzip",
				transferBytes: 7,
				sha256: "0".repeat(64),
				hashes: expectedHashes,
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
			secondPartAttempts += 1;
			secondPartCacheModes.push(init.cache);
			if (secondPartAttempts === 1) {
				return new Response(staleSecondPart, { status: 200 });
			}
			return new Response(secondPart, { status: 200 });
		}
		if (url.includes("part02.gz")) {
			return new Response(thirdPart, { status: 200 });
		}
		throw new Error(`Unexpected fetch ${url}`);
	},
};

await import("./pck-loader.js");
const response = await window.fetch("https://example.test/index.pck");
const joined = new TextDecoder().decode(await response.arrayBuffer());

assert.equal(joined, "abcdefghi", "retried parts must reassemble in exact order");
assert.equal(firstPartAttempts, 2, "a failed part is retried exactly once before success");
assert.deepEqual(firstPartCacheModes, ["default", "reload"],
	"a retry bypasses the failed response while completed parts remain cacheable");
assert.equal(secondPartAttempts, 2,
	"a same-sized stale part is rejected by its digest and fetched again");
assert.deepEqual(secondPartCacheModes, ["default", "reload"],
	"an integrity retry bypasses the stale immutable response");
assert.equal(response.headers.get("Content-Length"), "9");
assert(requestedUrls.every((url) => url.includes("build=loader-test")),
	"every manifest and part request keeps the explicit deployment identity");
assert(requestedUrls.filter((url) => url.includes(".part0")).every((url) =>
	url.endsWith(".gz?build=loader-test")),
	"gzip manifests request compressed pack parts with the deployment identity");
const retryIndex = requestedUrls.findLastIndex((url) => url.includes("part00.gz"));
assert(requestedUrls.findIndex((url) => url.includes("part01.gz")) < retryIndex
	&& requestedUrls.findIndex((url) => url.includes("part02.gz")) < retryIndex,
	"bounded prefetch must overlap later parts with an earlier part retry");

globalThis.fetch = originalFetch;
console.log("PCK_LOADER_TEST: PASS — explicit identity, prefetch, retry and exact reassembly");
