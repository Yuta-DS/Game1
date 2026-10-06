const GEMINI_MODEL = "gemini-3.5-flash-lite";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const MAX_MESSAGE_LENGTH = 280;
const MAX_OUTPUT_TOKENS = 200;

// Milo stays a warm, clearly-AI companion. He never claims to be human or
// divine, never diagnoses, and defers real support to a trusted person - the
// game's own crisis-keyword matcher (MiloReflectionEngine) already intercepts
// urgent messages before they ever reach this endpoint.
const SYSTEM_PROMPT = `You are Milo, a warm and gently encouraging cat companion character in the game Artéa.

You are an AI-powered game character, not a real person, spirit, or deity. If a player directly asks whether you are an AI, say so plainly rather than deny or deflect it.

Speak in first person as Milo: kind, curious, a little playful, like a caring friend. Keep replies short - one to three sentences.

You are not a therapist, counsellor, or medical professional, and nothing you say is medical or mental-health advice. Never diagnose a feeling or claim to know what the player is experiencing - respond only to what they actually wrote. If a player seems to want real support beyond a friendly chat, gently suggest talking to a trusted adult or a real support service, without being repetitive about it every single reply.

Stay warm and in character, but do not invent game lore, promise rewards, or claim abilities you do not have.`;

function corsHeaders() {
	return {
		"Access-Control-Allow-Origin": "*",
		"Access-Control-Allow-Methods": "POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type",
	};
}

function jsonResponse(body, status = 200) {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "Content-Type": "application/json", ...corsHeaders() },
	});
}

export default {
	async fetch(request, env) {
		if (request.method === "OPTIONS") {
			return new Response(null, { headers: corsHeaders() });
		}
		if (request.method !== "POST") {
			return jsonResponse({ error: "Use POST" }, 405);
		}
		if (!env.GEMINI_API_KEY) {
			return jsonResponse({ error: "Server not configured" }, 500);
		}

		let payload;
		try {
			payload = await request.json();
		} catch {
			return jsonResponse({ error: "Invalid JSON body" }, 400);
		}

		const message = String(payload?.message ?? "").slice(0, MAX_MESSAGE_LENGTH).trim();
		if (!message) {
			return jsonResponse({ error: "Missing message" }, 400);
		}

		const geminiRequest = {
			contents: [{ role: "user", parts: [{ text: message }] }],
			systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
			generationConfig: {
				temperature: 0.9,
				maxOutputTokens: MAX_OUTPUT_TOKENS,
			},
		};

		let geminiResponse;
		try {
			geminiResponse = await fetch(GEMINI_URL, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					"x-goog-api-key": env.GEMINI_API_KEY,
				},
				body: JSON.stringify(geminiRequest),
			});
		} catch {
			return jsonResponse({ error: "Upstream request failed" }, 502);
		}

		if (!geminiResponse.ok) {
			return jsonResponse({ error: `Upstream error ${geminiResponse.status}` }, 502);
		}

		const data = await geminiResponse.json();
		const reply = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
		if (!reply) {
			return jsonResponse({ error: "No reply generated" }, 502);
		}

		return jsonResponse({ reply });
	},
};
