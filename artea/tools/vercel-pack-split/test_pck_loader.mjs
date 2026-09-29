import assert from "node:assert/strict";

const originalFetch = globalThis.fetch;
let firstPartAttempts = 0;
const requestedUrls = [];

globalThis.window = {
	location: { href: "https://example.test/?build=loader-test" },
	setTimeout,
	clearTimeout,
	fetch: async (input) => {
		const url = String(input);
		requestedUrls.push(url);
		if (url.includes(".parts.json")) {
			return new Response(JSON.stringify({ count: 2, bytes: 6, partBytes: 3 }), {
				status: 200,
				headers: { "Content-Type": "application/json" },
			});
		}
		if (url.includes("part00")) {
			firstPartAttempts += 1;
			if (firstPartAttempts == 1) {
				return {
					ok: true,
					status: 200,
					headers: new Headers({ "Content-Length": "3" }),
					arrayBuffer: async () => { throw new Error("simulated stalled part"); },
				};
			}
			return new Response("abc", { status: 200, headers: { "Content-Length": "3" } });
		}
		if (url.includes("part01")) {
			return new Response("def", { status: 200, headers: { "Content-Length": "3" } });
		}
		throw new Error(`Unexpected fetch ${url}`);
	},
};

await import("./pck-loader.js");
const response = await window.fetch("https://example.test/index.pck");
const joined = new TextDecoder().decode(await response.arrayBuffer());

assert.equal(joined, "abcdef", "retried parts must reassemble without partial bytes");
assert.equal(firstPartAttempts, 2, "a failed part is retried exactly once before success");
assert.equal(response.headers.get("Content-Length"), "6");
assert(requestedUrls.every((url) => url.includes("build=loader-test")),
	"every manifest and part request keeps the cache-busting build identity");

globalThis.fetch = originalFetch;
console.log("PCK_LOADER_TEST: PASS — failed part retried and six-byte pack reassembled exactly");
