shader_type spatial;
render_mode cull_back;
#include "res://shaders/surf_geometry.gdshaderinc"
varying float visibility;
varying float random_seed;

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float duration = .55+INSTANCE_CUSTOM.z*.55;
	float life = fract(sea_time/duration+INSTANCE_CUSTOM.y);
	float seconds = life*duration;
	float born_age = wave_age-seconds/wave_period;
	float u = .10+.80*seed;
	vec3 lip = surf_point_at(vec2(u,mix(.67,.99,step(.45,INSTANCE_CUSTOM.w))),born_age);
	float peel = surf_peel(u,born_age);
	visibility = smoothstep(.24,.38,peel)*(1.0-smoothstep(.76,.91,peel));
	visibility *= smoothstep(.02,.13,life)*(1.0-smoothstep(.55,1.0,life));
	visibility *= smoothstep(.1,.4,lip.y)*step(0.0,born_age);
	float density = .25+.75*wind_strength;
	visibility *= 1.0-smoothstep(density-.06,density+.06,seed);
	vec3 velocity = vec3((INSTANCE_CUSTOM.w-.5)*.45,.50+INSTANCE_CUSTOM.z*.9,.30+seed*.4);
	velocity *= .35+.65*wind_strength;
	vec3 point = lip+velocity*seconds+vec3(0,-1.1,0)*seconds*seconds;
	visibility *= smoothstep(-.01,.06,point.y);
	float size = (.005+.017*INSTANCE_CUSTOM.z*INSTANCE_CUSTOM.z)*(1.0+life*.55);
	// Ellipsoidal droplets, not camera-facing cards.
	vec3 stretch = vec3(1.0,.75+INSTANCE_CUSTOM.z,.8);
	VERTEX = point+VERTEX*stretch*size*visibility;
	NORMAL = normalize(NORMAL/stretch);
	random_seed = seed;
}

void fragment() {
	if (visibility < .02) { discard; }
	ALBEDO = vec3(.88,.95,1.0);
	EMISSION = ALBEDO*.20;
	ROUGHNESS = .85;
	SPECULAR = .08;
}
