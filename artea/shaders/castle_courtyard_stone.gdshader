shader_type spatial;

// Colour only: the visible floor and its collider share one undisplaced top.
uniform bool paving = false;
uniform bool dressed_treads = false;
uniform vec3 court_center = vec3(-23.65, 67.97, 27.41);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = world_position.xz - court_center.xz;
	bool top = paving && abs(world_normal.y) > 0.8;
	vec2 uv = top ? p : vec2(abs(world_normal.x) > 0.5 ? world_position.z : world_position.x, world_position.y);
	vec2 size = top ? vec2(0.92, 0.46) : vec2(0.88, 0.40);
	vec2 brick = uv / size;
	brick.x += mod(floor(brick.y), 2.0) * 0.5;
	vec2 edge = min(fract(brick), 1.0 - fract(brick)) * size;
	float aa = max(length(fwidth(uv)), 0.002);
	float joint = 1.0 - smoothstep(0.004, 0.004 + aa, min(edge.x, edge.y));
	float variation = fract(sin(dot(floor(brick), vec2(127.1, 311.7))) * 43758.5453);
	// The reference tower has quiet stone walls and isolated raised patches.
	// Only walkable paving carries an all-over laid flagstone pattern.
	vec3 stone = vec3(0.506, 0.549, 0.569);
	if (top) {
		stone = mix(vec3(0.545, 0.573, 0.608), vec3(0.580, 0.607, 0.645), variation);
		stone = mix(stone, vec3(0.345, 0.376, 0.396), joint * 0.28);
	}
	// Stair dressing is a colour change on the physical top, never a second
	// coplanar mesh (which would shimmer or conceal the true foot contact).
	if (dressed_treads && world_normal.y > 0.8) {
		stone = vec3(0.569, 0.596, 0.635);
	}
	if (top) {
		// Eight pointed petals, cut into the stone rather than raised trim.
		float outline = 10.0;
		float interior = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398163;
			vec2 radial = vec2(cos(a), sin(a));
			vec2 q = vec2(dot(p, radial) - 1.22, dot(p, vec2(-radial.y, radial.x)));
			float petal = max(length(q - vec2(0.0, 0.94)), length(q + vec2(0.0, 0.94))) - 1.37;
			outline = min(outline, abs(petal));
			interior = max(interior, 1.0 - smoothstep(-aa, aa, petal));
		}
		float ring = abs(length(p) - 0.43);
		float inlay = 1.0 - smoothstep(0.014, 0.014 + aa, min(outline, ring));
		stone = mix(stone, vec3(0.60, 0.64, 0.66), interior * 0.25);
		stone = mix(stone, vec3(0.70, 0.72, 0.69), inlay * 0.65);
		// Flush border inside the side walls and rear stair threshold.
		float border = min(abs(abs(p.y) - 6.77), abs(world_position.x + 27.70));
		stone = mix(stone, vec3(0.70, 0.72, 0.69), 1.0 - smoothstep(0.08, 0.08 + aa, border));
	}
	// Match StandardMaterial's sRGB palette on Web/Compatibility and native
	// linear renderers (Godot spatial shader OUTPUT_IS_SRGB contract).
	ALBEDO = OUTPUT_IS_SRGB ? stone : pow((stone + vec3(0.055)) / 1.055, vec3(2.4));
	ROUGHNESS = 0.94;
}
