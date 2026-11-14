// Shared native/Web wave field. CPU buoyancy mirrors this in ocean_waves.gd.
uniform float sea_time = 0.0;
uniform vec4 wave_shape[9]; // wave vector xy, amplitude, angular speed
uniform vec4 wave_motion[9]; // phase, packet scale, packet speed, packet phase
uniform vec2 harbour_center = vec2(0.0);
uniform float harbour_clear_radius = 0.0;
uniform vec3 wind_state = vec3(0.0, -1.0, 0.5); // travel direction X/Z, strength
uniform float max_crest_height = 1.5;
uniform float carrier_swell_gain = 0.12;
#include "res://shaders/surf_shelter.gdshaderinc"

// Authored shallow-to-deep wave zones, shared exactly with CPU buoyancy.
vec3 sea_depth(vec2 p) {
	float u = clamp((p.y-harbour_center.y-25.0)/150.0,0.0,1.0);
	return vec3(.75+11.25*u*u*(3.0-2.0*u),0.0,11.25*6.0*u*(1.0-u)/150.0);
}

vec3 sea_crest_limit(vec2 p) {
	vec3 depth = sea_depth(p);
	float gust = .25+.75*wind_state.z;
	float scale = clamp(max_crest_height,0.0,1.5)/1.5;
	return vec3((.5+(depth.x-.75)/11.25*gust)*scale,depth.yz*gust*scale/11.25);
}

// Art-directed seismic trace profile, not an earthquake simulation.
vec2 sea_seismic_profile(float phase) {
	return vec2((cos(phase) + 0.35 * cos(2.0 * phase) + 0.12 * cos(3.0 * phase)) / 1.47,
		-(sin(phase) + 0.70 * sin(2.0 * phase) + 0.36 * sin(3.0 * phase)) / 1.47);
}

vec2 sea_seismic_packet(float phase) {
	float pulse = 0.5 + 0.5 * sin(phase);
	return vec2(0.06 + 0.94 * pow(pulse, 4.0), 1.88 * pow(pulse, 3.0) * cos(phase));
}

// Height, analytic X/Z slopes, and a broken crest signal.
vec4 sea_wave_field(vec2 p) {
	if (max_crest_height <= 0.0) {
		return vec4(0.0);
	}
	vec2 gust_vector = wind_state.xy * 0.0278;
	float gust_phase = dot(p, gust_vector) - sea_time * 0.16;
	float gust = 0.72 + 0.28 * sin(gust_phase);
	vec2 gust_gradient = 0.28 * cos(gust_phase) * gust_vector;
	vec4 result = vec4(0.0);
	for (int i = 0; i < 9; i++) {
		vec4 w = wave_shape[i];
		vec4 m = wave_motion[i];
		float alignment = 0.5 + 0.5 * dot(w.xy / max(length(w.xy), 0.00001), wind_state.xy);
		float wind_gain = 4.0 * wind_state.z * (0.35 + 0.65 * alignment * alignment);
		vec2 packet_vector = w.xy * 0.18 + vec2(-w.y, w.x) * m.y * 0.5;
		float packet = dot(p, packet_vector) + sea_time * (-w.w * 0.21 + m.z * 0.22) + m.w;
		vec2 packet_shape = sea_seismic_packet(packet);
		float envelope = packet_shape.x;
		float phase = dot(p, w.xy) - sea_time * w.w + m.x + 0.65 * sin(packet);
		vec2 waveform = sea_seismic_profile(phase);
		float profile = waveform.x;
		vec2 phase_gradient = w.xy + 0.65 * cos(packet) * packet_vector;
		vec2 envelope_gradient = packet_shape.y * packet_vector;
		float height = w.z * envelope * profile;
		vec2 slope = w.z * (envelope_gradient * profile
			+ envelope * waveform.y * phase_gradient);
		result.x += height * gust * wind_gain;
		result.yz += (slope * gust + height * gust_gradient) * wind_gain;
		float crest_weight = i < 3 ? 0.82 : 1.0;
		result.w = max(result.w, max(profile, 0.0) * envelope * crest_weight * step(0.001, w.z)
			* min(1.0, wind_gain * gust));
	}
	vec3 cap = sea_crest_limit(p);
	float limit_scale = result.x >= 0.0 ? 1.0 : .45;
	float limit = cap.x*limit_scale;
	float raw_height = result.x;
	float e = exp(-2.0 * abs(result.x) / limit);
	float derivative = 4.0 * e / ((1.0 + e) * (1.0 + e));
	float saturation = sign(result.x)*(1.0-e)/(1.0+e);
	result.x = limit*saturation;
	result.yz = result.yz*derivative + cap.yz*limit_scale*(saturation-derivative*raw_height/limit);
	// Shelter the berth and tide pools; blend smoothly into open-water swells.
	if (harbour_clear_radius > 0.1) {
		vec2 offset = p - harbour_center;
		float distance_to_port = length(offset);
		float inner = harbour_clear_radius * 1.25;
		float span = harbour_clear_radius * 2.0;
		float u = clamp((distance_to_port - inner) / span, 0.0, 1.0);
		float blend = u * u * (3.0 - 2.0 * u);
		float gain = mix(0.13, 1.0, blend);
		vec2 gain_gradient = 0.87 * 6.0 * u * (1.0 - u) / span
			* offset / max(distance_to_port, 0.001);
		result.yz = result.yz * gain + result.x * gain_gradient;
		result.x *= gain;
		result.w *= mix(0.32, 1.0, blend);
	}
	// Keep displacement and buoyancy identical; only the actual Blender
	// curls rise prominently from this low-amplitude continuous water base.
	return sea_surf_shelter(p, result*carrier_swell_gain);
}
