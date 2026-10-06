// Shared by the Blender water shell and deterministic crest spray.
#include "res://shaders/surf_profile.gdshaderinc"
uniform float wave_width = 12.0;
uniform float wave_height = 0.9;
uniform float wave_depth_scale = 1.0;
uniform float wave_age = 0.45;
uniform float wave_period = 15.0;
uniform float sea_time = 0.0;
uniform float wind_strength = 0.5;

float surf_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(.1031,.1030,.0973));
	q += dot(q,q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float surf_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(surf_hash(i),surf_hash(i+vec2(1,0)),f.x),
		mix(surf_hash(i+vec2(0,1)),surf_hash(i+vec2(1)),f.x),f.y);
}

float surf_peel(float u, float age) {
	return surf_profile_peel(u,age,wave_width);
}

vec3 surf_volume_point(vec2 uv, float side, float age) {
	float u = clamp(uv.x,0.0,1.0), v = clamp(uv.y,0.0,1.0);
	float peel = surf_peel(u,age);
	float rise = smoothstep(0.0,.18,age);
	// Establish the curl sooner and hold its silhouette before the wash-down.
	float curl = smoothstep(.10,.34,peel);
	float fall = smoothstep(.66,.90,peel);
	float fade = 1.0-smoothstep(.84,1.0,age);
	// Rounded shoulders merge into the sea instead of ending in vertical cuts.
	float taper = smoothstep(0.0,.19,u)*(1.0-smoothstep(.81,1.0,u));
	float phase = surf_profile_phase(wave_width);
	// Broad humps, not high-frequency vertex noise: resolved by the existing
	// 56 crest segments even on the longest waves. Peak stays below the cap.
	float lateral = .82 + .12*sin(u*8.0+phase) + .05*sin(u*19.0+phase*.7);
	vec2 barrel;
	if (v < .35) {
		float s = v/.35;
		// Separate shoreward and seaward feet enclose a solid water body.
		float front = -.60+1.40*(1.0-s)*(1.0-s);
		float back = -.78-1.12*(1.0-s)*(1.0-s);
		barrel = vec2(mix(front,back,side),.47*s*s);
	} else {
		float theta = 3.14159265-(v-.35)/.65*(3.14159265-.20+fall*1.50);
		barrel = vec2(mix(.60,.78,side)*cos(theta),.47+mix(.38,.52,side)*sin(theta));
		barrel += vec2(sin(theta),-cos(theta))*.085*sin(side*3.14159265)*smoothstep(.96,1.0,v);
	}
	vec2 swell = vec2(mix(.8,-1.9,side)*(1.0-v)-.20*v,sin(v*1.5707963)*.50);
	vec2 shape = mix(swell,barrel,curl*taper);
	shape.y *= 1.0-fall*.92;
	shape.x += fall*v*.65;
	float lip = smoothstep(.72,1.0,v);
	float ragged = surf_noise(vec2(u*8.0+phase,age*.8))-.5;
	shape.y = (shape.y + lip*ragged*.035)
		*wave_height*rise*fade*taper*lateral;
	shape.x += ragged*lip*.06;
	// Each event has a different gently wandering crest, held stable as it
	// travels. The advancing wash uses this same bend and peeling phase.
	shape.x += surf_profile_bend(u,wave_width)*sin(v*1.5707963);
	return vec3((u-.5)*wave_width,shape.y-.028,shape.x*wave_depth_scale);
}

vec3 surf_point_at(vec2 uv, float age) {
	return surf_volume_point(uv,1.0,age);
}
