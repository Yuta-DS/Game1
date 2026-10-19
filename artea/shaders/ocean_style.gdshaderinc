// One village-compatible palette for swells, solid curls and both renderers.
// Blue/turquoise water and cool white foam shared with the reference curl.
float ocean_detail_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
	q += dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}

// Value and analytic derivatives share four hash samples. This avoids three
// separate noise evaluations when adding flowing highlights over the sea.
vec3 ocean_detail_noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	vec2 u = f*f*(3.0-2.0*f), du = 6.0*f*(1.0-f);
	float a = ocean_detail_hash(cell), b = ocean_detail_hash(cell+vec2(1,0));
	float c = ocean_detail_hash(cell+vec2(0,1)), d = ocean_detail_hash(cell+vec2(1));
	return vec3(mix(mix(a,b,u.x),mix(c,d,u.x),u.y),
		mix(b-a,d-c,u.y)*du.x,mix(c-a,d-b,u.x)*du.y);
}

vec2 ocean_flow_gradient(vec2 p, float clock) {
	vec2 drift = vec2(.10,-.65)*clock;
	vec3 broad = ocean_detail_noise(p*vec2(10.1,4.5)+drift);
	vec2 broad_gradient = broad.yz*vec2(10.1,4.5);
	vec3 fine = ocean_detail_noise(p*vec2(27.2,12.8)+drift*1.7+broad.x);
	float pixel = max(length(dFdx(p)),length(dFdy(p)));
	float broad_visible = 1.0-smoothstep(.20,.65,pixel*10.1);
	float fine_visible = 1.0-smoothstep(.20,.65,pixel*27.2);
	vec2 gradient = broad_gradient*.65*broad_visible + .35*fine_visible*(fine.yz*vec2(27.2,12.8)+(fine.y+fine.z)*broad_gradient);
	return clamp(gradient,vec2(-12.0),vec2(12.0));
}

vec2 ocean_foam_samples(vec2 flow, float clock, float detail) {
	vec2 advect = flow*vec2(8.4,11.5)+vec2(.05,-.30)*clock;
	vec2 warp = vec2(ocean_detail_noise(advect*.57).x,ocean_detail_noise(advect*.57+24.3).x);
	float clusters = ocean_detail_noise(advect+warp*2.6).x*.65+ocean_detail_noise(advect*2.3+warp).x*.35;
	float pixel = max(length(dFdx(advect)),length(dFdy(advect)));
	float coarse = ocean_detail_noise(flow*.75+vec2(.03,-.1)*clock).x;
	clusters = mix(coarse,clusters,1.0-smoothstep(.35,1.2,pixel));
	float pores = .65;
	if (detail > .01) {
		pores = mix(.65,ocean_detail_noise(advect*5.0+warp*3.0).x,1.0-smoothstep(.25,.9,pixel*5.0));
	}
	return vec2(clusters,pores);
}

float ocean_foam_coverage(vec2 samples, float coverage, float detail) {
	return smoothstep(.57-coverage*.53,.73-coverage*.43,samples.x)*coverage
		*mix(.88,.68+.32*samples.y,detail);
}

vec3 stylized_water(vec3 normal, vec3 view, float height, float foam,
		vec3 style_light, vec3 style_sun, float style_strength) {
	float facing = clamp(dot(normal,view),0.0,1.0);
	float rim = pow(1.0-facing,3.0);
	float shoulder = smoothstep(-.35,.85,height);
	vec3 water = mix(vec3(.025,.18,.29),vec3(.07,.43,.59),shoulder);
	float light = smoothstep(-.3,.75,dot(normal,normalize(style_light)));
	water *= .64+.40*light;
	vec3 reflection = reflect(-view,normal);
	vec3 sky = mix(vec3(.60,.78,.85),vec3(.15,.36,.56),smoothstep(-.04,.60,reflection.y));
	water = mix(water,sky,.08+rim*.34);
	vec3 half_direction = normalize(normalize(style_light)+view);
	float sun_glint = pow(max(dot(normal,half_direction),0.0),96.0)*.22;
	water += style_sun*sun_glint*style_strength*(1.0-foam);
	return mix(water,vec3(.91,.97,.99),clamp(foam,0.0,1.0));
}

vec3 ocean_reference_whitewater(float pores) {
	return mix(vec3(.62,.78,.85),vec3(.97,.99,1.0),.60+.40*pores);
}

vec3 ocean_reference_water(vec3 normal, vec3 view, float height, float foam,
		float pores, vec3 light_direction, vec3 light_color, float light_strength) {
	vec3 water = stylized_water(normal,view,height,0.0,light_direction,light_color,light_strength);
	water *= .72+.28*max(normal.y,0.0);
	return mix(water,ocean_reference_whitewater(pores),foam);
}
