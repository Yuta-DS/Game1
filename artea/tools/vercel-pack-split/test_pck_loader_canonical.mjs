import assert from "node:assert/strict";

const originalFetch = globalThis.fetch;
const requestedUrls = [];
const partName = "parts/index.pck.canonical.part00";

globalThis.window = {
	location: { href: "https://example.test/" },
	fetch: async (input) => {
		const url = String(input);
		requestedUrls.push(url);
		if (url.includes(".parts.json")) {
			return new Response(JSON.stringify({
				count: 1,
				bytes: 3,
				parts: [{ name: partName, size: 3 }],
			}), { status: 200 });
		}
		if (url.endsWith(partName)) return new Response("abc", { status: 200 });
		throw new Error(`Unexpected fetch ${url}`);
	},
};

await import("./pck-loader.js");
const response = await window.fetch("https://example.test/index.pck");
assert.equal(new TextDecoder().decode(await response.arrayBuffer()), "abc");
assert.deepEqual(requestedUrls, [
	"https://example.test/index.pck.parts.json",
	`https://example.test/${partName}`,
], "a canonical visit uses the fresh manifest and its immutable part path");

globalThis.fetch = originalFetch;
console.log("PCK_LOADER_CANONICAL_TEST: PASS — manifest-selected immutable part");
