shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/surf_geometry.gdshaderinc"
#include "res://shaders/ocean_style.gdshaderinc"

varying vec3 world_normal;
varying vec3 world_tangent;
varying vec3 world_binormal;
varying vec3 world_position;
varying float local_height;

void vertex() {
	float side = UV2.x;
	vec3 p = surf_volume_point(UV,side,wave_age);
	vec3 du = surf_volume_point(UV+vec2(.0005,0),side,wave_age)-surf_volume_point(UV-vec2(.0005,0),side,wave_age);
	vec3 dv = surf_volume_point(UV+vec2(0,.0005),side,wave_age)-surf_volume_point(UV-vec2(0,.0005),side,wave_age);
	vec3 n = normalize(cross(du,dv)) * (side > .5 ? -1.0 : 1.0);
	if (side > .001 && side < .999) {
		vec3 ds = surf_volume_point(UV,side+.001,wave_age)-surf_volume_point(UV,side-.001,wave_age);
		n = normalize(cross(ds,du));
	}
	VERTEX = p;
	NORMAL = n;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
	world_tangent = normalize(mat3(MODEL_MATRIX)*du);
	world_binormal = normalize(mat3(MODEL_MATRIX)*dv);
	world_position = (MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	local_height = p.y;
}

void fragment() {
	if (local_height < .003) { discard; }
	float coverage_fade = smoothstep(.003,.025,local_height);
	if (surf_hash(floor(FRAGCOORD.xy)) > coverage_fade) { discard; }
	vec2 flow = vec2(UV.x*wave_width,UV.y*2.7);
	float detail = (1.0-smoothstep(.08,.38,length(fwidth(flow))))*smoothstep(.025,.16,local_height);
	vec3 n = normalize(world_normal);
	// Filter detail by projected size, keeping distant waves calm and cheap.
	if (detail > .01) {
		vec2 gradient = ocean_flow_gradient(flow,sea_time);
		n = normalize(n-(world_tangent*gradient.x+world_binormal*gradient.y)*.014*detail);
	}
	vec3 view = normalize(CAMERA_POSITION_WORLD-world_position);
	if (dot(n,view)<0.0) { n=-n; }
	// Domain-warped clusters and small bubbles break up the previous flat bands.
	vec2 foam_samples = ocean_foam_samples(flow,sea_time,detail);
	float clusters = foam_samples.x;
	float pores = foam_samples.y;
	float peel = surf_peel(UV.x,wave_age);
	float breaking = smoothstep(.18,.34,peel);
	// Foam collects unevenly along the crown instead of outlining a tube.
	// Large patches remain legible at distance; small bubbles are filtered.
	float patchiness = surf_noise(vec2(UV.x*8.0+surf_profile_phase(wave_width),wave_age*.3));
	float crown_v = UV.y + (patchiness-.5)*.085;
	float crest = smoothstep(.59,.68,crown_v)*(1.0-smoothstep(.73,.83,crown_v));
	float lip = smoothstep(.90+patchiness*.07-clusters*.018,1.0,UV.y);
	float wash = smoothstep(.70,.91,peel)*smoothstep(.40,.75,UV.y);
	float face_height = clamp(local_height/max(wave_height,.01),0.0,1.0);
	float foam_patches = smoothstep(.22,.72,patchiness);
	float coverage = clamp(crest*.55+lip*.95+wash*.70,0.0,1.0)*breaking*(.35+.65*foam_patches);
	float foam = ocean_foam_coverage(foam_samples,coverage,detail);
	// A softer broken rim preserves the blue face and avoids a neon stripe.
	foam = max(foam,(crest*.48+lip*.72)*breaking*(.30+.70*foam_patches));
	foam *= smoothstep(.04,.18,face_height);
	vec3 water = ocean_reference_water(n,view,local_height,0.0,pores,vec3(-.45,.78,-.43),vec3(1,.83,.60),.85);
	float face = smoothstep(.10,.60,face_height)*(1.0-abs(world_normal.y));
	water = mix(water,vec3(.045,.40,.52),face*.42);
	float hollow = (1.0-smoothstep(.12,.55,UV2.x))*smoothstep(.45,.80,UV.y)*breaking;
	water *= 1.0-hollow*.28;
	water = mix(water,ocean_reference_whitewater(pores),clamp(foam,0.0,1.0));
	float haze = smoothstep(210.0,470.0,distance(CAMERA_POSITION_WORLD,world_position));
	ALBEDO = mix(water,vec3(.70,.84,.91),haze*.82);
	EMISSION = water*.10;
	NORMAL = normalize((VIEW_MATRIX*vec4(n,0)).xyz);
	ROUGHNESS = mix(.38,.86,foam);
	SPECULAR = .18;
}
