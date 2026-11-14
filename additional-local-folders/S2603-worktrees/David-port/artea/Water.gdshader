shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform float time_speed = 0.35;
uniform float surface_speed = 0.025;
uniform float spin = 0.08;
uniform float brightness = 0.82;
uniform float color_intensity = 0.35;
uniform float horizontal_frequency = 2.0;
uniform float vertical_frequency = 2.0;
uniform float size = 3.0;
uniform float banding_bias = 0.66;
uniform sampler2D wave_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform float wave_height = 0.45;
uniform float texture_height = 0.12;
uniform vec4 color1 : source_color = vec4(0.38, 0.76, 0.84, 1.0);
uniform vec4 color2 : source_color = vec4(0.10, 0.48, 0.66, 1.0);
uniform vec4 color3 : source_color = vec4(0.025, 0.25, 0.43, 1.0);
uniform vec4 color4 : source_color = vec4(0.015, 0.12, 0.24, 1.0);
uniform vec3 sun_direction = vec3(-0.45, 0.78, -0.43);
uniform vec3 sun_color : source_color = vec3(1.0, 0.72, 0.42);
uniform float sun_glint_strength = 1.15;
#include "res://shaders/ocean_waves.gdshaderinc"
#include "res://shaders/ocean_style.gdshaderinc"
#include "res://shaders/ocean_surface.gdshaderinc"

varying vec3 world_position;
varying vec4 interpolated_waves;

void vertex() {
	vec2 point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	interpolated_waves = sea_wave_field(point);
	VERTEX.y += interpolated_waves.x;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Nine-wave displacement and slopes are interpolated from the mesh.
	// No expensive repeated wave-field evaluation per screen pixel.
	vec4 waves = interpolated_waves;
	vec2 slope = waves.yz + sea_ripple_slope(world_position.xz);
	vec2 across = vec2(-wind_state.y,wind_state.x);
	vec2 flow = vec2(dot(world_position.xz,across),dot(world_position.xz,wind_state.xy)*.6);
	float camera_distance = distance(CAMERA_POSITION_WORLD,world_position);
	float detail = (1.0-smoothstep(.08,.38,length(fwidth(flow))))*(1.0-smoothstep(70.0,150.0,camera_distance));
	if (detail > .01) {
		vec2 gradient = ocean_flow_gradient(flow,sea_time);
		slope += (across*gradient.x+wind_state.xy*gradient.y*.6)*.006*detail;
	}
	vec3 water_normal = normalize(vec3(-slope.x,1.0,-slope.y));
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD-world_position);
	float fresnel = pow(1.0-clamp(dot(water_normal,view_direction),0.0,1.0),3.0);
	vec2 foam_data = sea_reference_foam(world_position.xz,detail);
	float foam = foam_data.x;
	vec3 water = ocean_reference_water(water_normal,view_direction,waves.x,foam,foam_data.y,sun_direction,sun_color,sun_glint_strength);
	float aerial_haze = smoothstep(210.0,470.0,distance(CAMERA_POSITION_WORLD,world_position));
	ALBEDO = mix(water,vec3(.70,.84,.91),aerial_haze*.82);
	EMISSION = water*.10;
	NORMAL = normalize((VIEW_MATRIX*vec4(water_normal,0)).xyz);
	ROUGHNESS = mix(.38,.86,foam);
	SPECULAR = .18;
	METALLIC = 0.0;
	// Preserve the transparent harbour pool and visible sea life.
	float pool = 1.0-smoothstep(harbour_clear_radius*.35,max(harbour_clear_radius,.01),distance(world_position.xz,harbour_center));
	pool *= step(.1,harbour_clear_radius);
	ALBEDO = mix(ALBEDO,vec3(.12,.48,.55),pool*.28);
	ALPHA = mix(1.0,.60,pool*(1.0-fresnel));
}
