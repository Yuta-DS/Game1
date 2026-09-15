shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float flame_time = 0.0;
uniform float phase = 0.0;
varying float height;

void vertex() {
	height = UV.y;
	float t = flame_time + phase + UV.x * 2.7;
	float bend = height * height;
	VERTEX.x += bend * (sin(t * 4.9 + height * 4.0) * 0.058 + sin(t * 9.1) * 0.016);
	VERTEX.z += bend * cos(t * 5.7 + height * 5.0) * 0.035;
	VERTEX.y += height * (sin(t * 7.3) * 0.036 + sin(t * 11.7) * 0.012);
}

void fragment() {
	float flicker = sin(flame_time * 8.0 + UV.x * 6.0 + height * 15.0) * 0.035;
	vec3 hot = vec3(1.0, 0.88, 0.38);
	vec3 amber = vec3(1.0, 0.38, 0.035);
	vec3 tip = vec3(0.85, 0.12, 0.012);
	vec3 colour = mix(hot, amber, smoothstep(0.1, 0.7, height + flicker));
	colour = mix(colour, tip, smoothstep(0.65, 1.0, height));
	ALBEDO = colour;
	EMISSION = colour * 0.65;
}
