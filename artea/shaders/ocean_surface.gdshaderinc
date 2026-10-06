// Small-scale shading only: buoyancy continues to use the shared wave field.
#include "res://shaders/surf_profile.gdshaderinc"
float sea_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float sea_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sea_hash(cell), sea_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(sea_hash(cell + vec2(0.0, 1.0)), sea_hash(cell + vec2(1.0)), f.x), f.y);
}

// Filter fine ripples by their projected pixel size, avoiding horizon shimmer.
vec2 sea_ripple_slope(vec2 p) {
	vec2 slope = vec2(0.0);
	for (int i = 0; i < 2; i++) {
		float index = float(i);
		float angle = atan(wind_state.y,wind_state.x) + (index-.5)*0.12;
		vec2 k = vec2(cos(angle), sin(angle)) * (.85 + index * .65);
		float phase = dot(p, k) - sea_time * (1.7 + index * 0.53);
		float visibility = 1.0 - smoothstep(0.5, 2.4, fwidth(phase));
		slope += normalize(k) * cos(phase) * (0.014 - index * 0.004) * visibility;
	}
	return slope * (.35+.65*wind_state.z) * max_crest_height;
}

vec3 sea_sky_reflection(vec3 normal, vec3 view_direction) {
	vec3 reflected = reflect(-view_direction, normal);
	// A bright horizon and deeper upper sky bend across the rolling wave faces.
	return mix(vec3(0.60, 0.80, 0.86), vec3(0.14, 0.38, 0.58),
		smoothstep(-0.04, 0.55, reflected.y));
}

// Whitewater spreads across the existing ocean after the lip lands. Keeping
// this on the sea surface avoids a floating rectangular foam decal.
float sea_breaker_foam(vec2 p) {
	float result = 0.0;
	for (int i=0;i<6;i++) {
		vec4 patch = surf_patches[i], a = surf_axes[i];
		if (a.z < .01) { continue; }
		vec2 offset = p-patch.xy;
		vec2 q = vec2(dot(offset,vec2(a.x,-a.y)),dot(offset,vec2(a.y,a.x)));
		// Patch depth tracks the larger barrel: keep the wash attached to it.
		q.y /= max(patch.w/2.5,.001);
		if (abs(q.x)>patch.z || q.y < -2.0 || q.y > 5.0) { continue; }
		float width = 1.0-smoothstep(patch.z*.55,patch.z,abs(q.x));
		float u = q.x/max(patch.z*2.0,.01)+.5;
		float peel = surf_profile_peel(u,a.w,patch.z*2.0);
		float age = smoothstep(.62,.83,peel)*(1.0-smoothstep(.86,1.0,a.w));
		float front = .3+smoothstep(.66,.94,peel)*2.4+surf_profile_bend(u,patch.z*2.0);
		float band = exp(-pow((q.y-front)/(.42+age*.8),2.0));
		result = max(result,width*age*band*a.z);
	}
	return result;
}

vec2 sea_reference_foam(vec2 p, float detail) {
	// Every visible whitecap now belongs to an actual 3D curl. Do not paint
	// a second, unrelated set of flat white waves over the background carrier.
	float coverage = sea_breaker_foam(p);
	if (coverage < .001) { return vec2(0.0,.65); }
	vec2 across = vec2(-wind_state.y,wind_state.x);
	vec2 flow = vec2(dot(p,across),dot(p,wind_state.xy)*.6);
	// The same broken clusters and bubbles as the 3D curl; distant detail
	// reduces to one low-frequency sample, without adding geometry or spray.
	vec2 samples;
	if (detail > .01) {
		samples = ocean_foam_samples(flow,sea_time,detail);
	} else {
		samples = vec2(sea_noise(flow*.75-wind_state.xy*sea_time*.1),.65);
	}
	return vec2(ocean_foam_coverage(samples,coverage,detail),samples.y);
}

float sea_sun_reflection(vec3 normal, vec3 view_direction, vec3 light_direction, float foam) {
	vec3 half_direction = normalize(normalize(light_direction) + view_direction);
	float alignment = max(dot(normal, half_direction), 0.0);
	// Normal-driven glitter replaces the oversized, checker-like bright spots.
	float ribbon = pow(alignment, 90.0) * 0.20;
	float sparkle = pow(alignment, 420.0) * 0.72;
	return (ribbon + sparkle) * (1.0 - foam * 0.88);
}
