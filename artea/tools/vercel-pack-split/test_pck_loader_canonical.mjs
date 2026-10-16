import assert from "node:assert/strict";

const originalFetch = globalThis.fetch;
const requestedUrls = [];
const abcHash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";

globalThis.window = {
	location: { href: "https://example.test/" },
	setTimeout,
	clearTimeout,
	fetch: async (input) => {
		const url = String(input);
		requestedUrls.push(url);
		if (url.includes(".parts.json")) {
			return new Response(JSON.stringify({
				count: 1,
				bytes: 3,
				partBytes: 3,
				transferBytes: 2,
				sha256: abcHash,
				hashes: [abcHash],
			}), { status: 200 });
		}
		if (url.includes("part00")) {
			return new Response("abc", { status: 200 });
		}
		throw new Error(`Unexpected fetch ${url}`);
	},
};

await import("./pck-loader.js");
const response = await window.fetch("https://example.test/index.pck");
assert.equal(new TextDecoder().decode(await response.arrayBuffer()), "abc");
assert.equal(requestedUrls[0], "https://example.test/index.pck.parts.json",
	"the authoritative manifest stays fresh on a canonical visit");
assert.equal(
	requestedUrls[1],
	`https://example.test/index.pck.part00?build=pack-${abcHash}`,
	"the part URL receives the manifest-derived immutable identity",
);

globalThis.fetch = originalFetch;
console.log("PCK_LOADER_CANONICAL_TEST: PASS — manifest-derived immutable identity");
