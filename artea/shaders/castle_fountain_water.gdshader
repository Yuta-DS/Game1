shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Clear water without screen/depth sampling or compute-only Web features.
uniform bool flowing_stream = false;
uniform bool spray = false;
uniform float flow_time = 0.0;
uniform float basin_radius = 1.365;
uniform float impact_radius = 1.22;
varying vec3 water_position;

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 h = fract(sin(vec4(dot(i, vec2(127.1, 311.7)),
		dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7)),
		dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7)),
		dot(i + vec2(1.0), vec2(127.1, 311.7)))) * 43758.5453);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void vertex() {
	water_position = VERTEX;
	if (!flowing_stream) {
		vec2 p = (UV - vec2(0.5)) * (2.0 * basin_radius);
		vec2 slope = vec2(0.0);
		float displacement = 0.0;
		for (int i = 0; i < 4; i++) {
			float a = float(i) * 1.570796 + 0.785398;
			vec2 q = p - vec2(cos(a), sin(a)) * impact_radius;
			float d = max(length(q), 0.001);
			float phase = d * 42.0 - flow_time * 8.0;
			float envelope = exp(-d * 4.5);
			displacement += sin(phase) * envelope * 0.0025;
			slope += q / d * (42.0 * cos(phase) - 4.5 * sin(phase)) * envelope * 0.0025;
		}
		float edge = smoothstep(0.0, 0.07, basin_radius - length(p));
		VERTEX.y += displacement * edge;
		NORMAL = normalize(vec3(-slope.x * edge, 1.0, -slope.y * edge));
	}
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	float foam = 0.0;
	float glint = 0.0;
	float opacity = 0.62;
	vec3 colour = vec3(0.12, 0.37, 0.40);
	if (flowing_stream) {
		float flow = noise21(vec2(water_position.y * 25.0 + flow_time * 7.2,
			water_position.x * 37.0 + water_position.z * 19.0 - flow_time * 1.6));
		glint = smoothstep(0.56, 0.86, flow) * 0.32;
		colour = mix(vec3(0.22, 0.48, 0.52), vec3(0.78, 0.90, 0.92), glint + fresnel * 0.55);
		opacity = (spray ? 0.50 : 0.58) + fresnel * 0.24;
	} else {
		vec2 p = (UV - vec2(0.5)) * (2.0 * basin_radius);
		float turbulence = noise21(p * 23.0 + vec2(flow_time * 0.55, -flow_time * 0.38));
		for (int i = 0; i < 4; i++) {
			float a = float(i) * 1.570796 + 0.785398;
			float d = length(p - vec2(cos(a), sin(a)) * impact_radius);
			float ring = pow(0.5 + 0.5 * sin(d * 54.0 - flow_time * 8.0), 8.0);
			foam += (1.0 - smoothstep(0.028, 0.13, d)) * (0.55 + 0.45 * turbulence);
			glint += ring * exp(-d * 7.0) * 0.24;
		}
		float depth = smoothstep(0.0, 0.28, basin_radius - length(p));
		colour = mix(vec3(0.32, 0.59, 0.60), vec3(0.10, 0.33, 0.38), depth);
		colour = mix(colour, vec3(0.74, 0.88, 0.89), clamp(foam * 0.82 + glint + fresnel * 0.42, 0.0, 1.0));
		opacity = mix(0.38, 0.66, depth) + min(foam, 1.0) * 0.20;
	}
	ALBEDO = OUTPUT_IS_SRGB ? colour : pow((colour + vec3(0.055)) / 1.055, vec3(2.4));
	ROUGHNESS = mix(0.10, 0.25, min(foam, 1.0));
	SPECULAR = 0.72;
	METALLIC = 0.0;
	ALPHA = clamp(opacity, 0.0, 0.94);
}
