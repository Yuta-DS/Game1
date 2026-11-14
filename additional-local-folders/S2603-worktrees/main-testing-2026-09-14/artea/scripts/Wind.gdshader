/**
 * WIND STRIP SHADER by DIP
 1. Add a new TubeTrailMesh with a small radius, unitary length, and a bell-shaped curve.
 2. Rotate the MeshInstance3D to your preference (TubeTrailMeshes are only vertical for some reason)
 3. Set custom_aabb.h = 20 to prevent off-camera pop-out.
 4. Use instance_shader_parameters/extra_offset_time and other extra instance parameters to create simultaneous, unique wind trails without needing to make individual resources.
 */
shader_type spatial;
render_mode unshaded;

group_uniforms Global;
/**
Wind color. Can use alpha values*/
uniform vec4 color:source_color = vec4(1.0);
/**
The [b]fade_in_out[/b] time in seconds*/
uniform float fade_time = 5.0;
/**
General speed of time. Affects every time calculation*/
uniform float time_scale = 3.0;

group_uniforms Wave;
/**
Width of the straight-travel wave animation*/
uniform float wave_amplitude = 0.1;
/**
Speed of the straight-travel wave animation*/
uniform float wave_frequency = 1.0;
/**
Length of each wave*/
uniform float wave_length = 2.0;
/**
How many waves of straight-travel before a loop happens. Only makes sense if [b]loop_count > 0[/b]*/
uniform float wave_count:hint_range(0.0, 10.0, 1.0) = 1.0;

group_uniforms Twist;
/**
Width of the back-and-forth twist animation*/
uniform float twist_amplitude = 0.1;
/**
Speed of the back-and-forth twist animation*/
uniform float twist_frequency = 1.0;

group_uniforms Loop;
/**
Size of the full circle animation. Set to zero to disable*/
uniform float loop_radius = 1.0;
/**
How many times the wind make a full circle at the same time*/
uniform float loop_count = 0.5;


// Add variety from Inspector > GeometryInstance3D > Instance Shader Parameters

void vertex() {
	float extra_offset_time = INSTANCE_CUSTOM.x * 10.0; // scale for timing
	float extra_wave_length = INSTANCE_CUSTOM.y * 0.5;   // scale for shape
	float extra_loop_radius = INSTANCE_CUSTOM.z * 0.3;   // scale for loops
	float scaled_time = TIME * time_scale + extra_offset_time;

	// Base wave shape
	vec3 wave = vec3(
		VERTEX.x + sin(VERTEX.y * twist_frequency + extra_offset_time) * twist_amplitude,
		VERTEX.y * (wave_length + extra_wave_length),
		VERTEX.z + sin(VERTEX.y * wave_frequency + extra_offset_time) * wave_amplitude
	);

	// Loop shape
	float loop_angle = VERTEX.y * TAU * loop_count + extra_offset_time;
	vec3 loop = vec3(
		VERTEX.x,
		sin(loop_angle) * (loop_radius+extra_loop_radius),
		cos(loop_angle) * (loop_radius+extra_loop_radius)
	);

	// Wave-loop transition
	float period = TAU;
	float offset_time = period*0.5;
	float hold_time = wave_count * period;
	float total_time = hold_time + 2.0*period;
	float t = mod(scaled_time + offset_time, total_time);
	float factor;
	if (t < hold_time) {
		factor = 0.0;
	} else if (t < hold_time + period) {
		factor = ((t - hold_time) / period) * 0.5;
	} else {
		factor = (1.0 - (t - hold_time - period) / period) * 0.5;
	}

	VERTEX = mix(wave, loop, factor);
	VERTEX.y += t;

	// Fade in/out
	COLOR = color;
	if (t < fade_time) {
		COLOR.a = t / fade_time;
	} else if (t > total_time - fade_time) {
		COLOR.a = (total_time - t) / fade_time;
	}
}

void fragment(){
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}


