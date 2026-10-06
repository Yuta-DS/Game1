shader_type spatial;
render_mode cull_disabled;

// A finish on the existing floor, never a second raised or displaced surface.
uniform vec3 roof_origin = vec3(0.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = world_position.xz - roof_origin.xz;
	vec2 brick = p / vec2(0.82, 0.39);
	brick.x += mod(floor(brick.y), 2.0) * 0.5;
	vec2 tile = floor(brick);
	vec2 edge = min(fract(brick), 1.0 - fract(brick)) * vec2(0.82, 0.39);
	float aa = max(length(fwidth(p)), 0.002);
	float joint = 1.0 - smoothstep(0.006, 0.006 + aa, min(edge.x, edge.y));
	float variation = fract(sin(dot(tile, vec2(127.1, 311.7))) * 43758.5453);
	vec3 limestone = mix(vec3(0.545, 0.573, 0.608), vec3(0.580, 0.607, 0.645), variation);
	limestone = mix(limestone, vec3(0.345, 0.376, 0.396), joint * 0.28);
	// Eight petal limestone inlay: small tesserae and a gently outlined flower,
	// with no displacement, decorative collision or raised duplicate floor.
	float petal = 8.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 radial = vec2(cos(a), sin(a));
		// Small inlaid petals frame the centred basin without a raised floor.
		vec2 q = p - radial * 1.98;
		vec2 local = vec2(dot(q, radial), dot(q, vec2(-radial.y, radial.x)));
		petal = min(petal, length(local / vec2(0.31, 0.14)));
	}
	float outline = 1.0 - smoothstep(1.04, 1.09, petal);
	float motif = 1.0 - smoothstep(0.87, 0.94, petal);
	limestone = mix(limestone, vec3(0.57, 0.65, 0.62), outline * 0.72);
	vec2 tessera = min(fract(p * 10.0), 1.0 - fract(p * 10.0));
	float mosaic_joint = 1.0 - smoothstep(0.025, 0.09, min(tessera.x, tessera.y));
	limestone = mix(limestone, vec3(0.80, 0.81, 0.71) - mosaic_joint * 0.065, motif);
	float centre = 1.0 - smoothstep(0.23, 0.27, length(p));
	limestone = mix(limestone, vec3(0.65, 0.58, 0.40), centre);
	// The legacy two-sided deck has mixed triangle winding. Identify its top
	// by height as well as orientation, keeping the underside plain stone.
	float top_face = smoothstep(0.5, 0.95, abs(world_normal.y))
		* step(roof_origin.y - 0.06, world_position.y);
	vec3 stone = mix(vec3(0.506, 0.549, 0.569), limestone, top_face);
	ALBEDO = OUTPUT_IS_SRGB ? stone : pow((stone + vec3(0.055)) / 1.055, vec3(2.4));
	ROUGHNESS = 0.92;
}
