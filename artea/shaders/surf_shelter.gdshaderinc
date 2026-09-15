uniform vec4 surf_patches[6]; // center XZ, inner half-width/depth
uniform vec4 surf_axes[6]; // cos/sin heading, lifecycle weight, age

vec4 sea_surf_shelter(vec2 p, vec4 wave) {
	for (int i = 0; i < 6; i++) {
		vec4 patch = surf_patches[i], a = surf_axes[i];
		if (a.z <= 0.0) { continue; }
		vec2 right = vec2(a.x,-a.y), forward = vec2(a.y,a.x);
		vec2 offset = p - patch.xy;
		vec2 local = vec2(dot(offset,right),dot(offset,forward));
		vec2 u = clamp((abs(local)-patch.zw)/3.0,vec2(0),vec2(1));
		vec2 m = 1.0 - u*u*(3.0-2.0*u);
		float weight = m.x*m.y*a.z;
		vec2 gradient = (right * (-2.0*u.x*(1.0-u.x)*sign(local.x)*m.y)
			+ forward * (-2.0*u.y*(1.0-u.y)*sign(local.y)*m.x)) * a.z;
		float gain = 1.0 - 0.97*weight;
		wave.yz = wave.yz*gain - wave.x*0.97*gradient;
		wave.x *= gain;
		wave.w *= gain;
	}
	return wave;
}
