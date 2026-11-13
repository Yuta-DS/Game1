import assert from "node:assert/strict";

const originalFetch = globalThis.fetch;
const requests = [];
let firstAttempts = 0;

globalThis.window = {
	location: { href: "https://example.test/?build=loader-test" },
	fetch: async (input) => {
		const url = String(input);
		requests.push(url);
		if (url.includes("content.pck.parts.json")) {
			return new Response(JSON.stringify({
				count: 3,
				bytes: 9,
				parts: [0, 1, 2].map((index) => ({
					name: `parts/content.pck.hash.part0${index}`,
					size: 3,
				})),
			}), { status: 200 });
		}
		if (url.endsWith("part00")) {
			firstAttempts += 1;
			if (firstAttempts === 1) throw new Error("temporary network failure");
			return new Response("abc", { status: 200 });
		}
		if (url.endsWith("part01")) return new Response("def", { status: 200 });
		if (url.endsWith("part02")) return new Response("ghi", { status: 200 });
		throw new Error(`Unexpected fetch ${url}`);
	},
};

await import("./pck-loader.js");
const response = await window.fetch("https://example.test/content.pck");
assert.equal(new TextDecoder().decode(await response.arrayBuffer()), "abcdefghi");
assert.equal(response.headers.get("Content-Length"), "9");
assert.equal(firstAttempts, 2, "a failed content-pack part is retried");
assert(requests.some((url) => url.includes("content.pck.parts.json?build=loader-test")));
assert(requests.filter((url) => url.includes(".part0")).every((url) =>
	url.startsWith("https://example.test/parts/content.pck.hash.part0")),
	"hashed part URLs are taken from the content manifest");

globalThis.fetch = originalFetch;
console.log("PCK_LOADER_TEST: PASS — deferred content, retry, exact reassembly");
