shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_schlick_ggx;

uniform sampler2D WindNoise;
uniform vec4 BaseColor : source_color = vec4(0.141176, 0.156863, 0.074510, 1.000000);
uniform vec4 WindColor : source_color = vec4(0.384314, 0.529412, 0.301961, 1.000000);



void vertex() {
	// Apply the instance transform correctly
    // Godot applies it automatically *unless* you override position incorrectly

    // If you modify vertex positions, always do it in local space:
    vec3 local_vertex = VERTEX;

    // Example: wind animation

    // Assign it back
    VERTEX = local_vertex;
// Input:11
	vec3 n_out11p0 = VERTEX;


// Input:3
	vec3 n_out3p0 = NODE_POSITION_WORLD;


// VectorDecompose:4
	float n_out4p0 = n_out3p0.x;
	float n_out4p1 = n_out3p0.y;
	float n_out4p2 = n_out3p0.z;


// VectorCompose:5
	vec2 n_out5p0 = vec2(n_out4p0, n_out4p2);


// Input:6
	float n_out6p0 = TIME;


// VectorOp:12
	vec2 n_out12p0 = n_out5p0 + vec2(n_out6p0);


// UVFunc:8
	vec2 n_in8p1 = vec2(0.10000, 0.10000);
	vec2 n_out8p0 = n_out12p0 * n_in8p1 + UV;


	vec4 n_out7p0;
// Texture2D:7
	n_out7p0 = texture(WindNoise, n_out8p0);


// Input:16
	vec2 n_out16p0 = UV;


// VectorDecompose:17
	float n_out17p0 = n_out16p0.x;
	float n_out17p1 = n_out16p0.y;


// FloatFunc:18
	float n_out18p0 = 1.0 - n_out17p1;


// VectorOp:14
	vec3 n_out14p0 = vec3(n_out7p0.xyz) * vec3(n_out18p0);


// VectorOp:22
	vec3 n_in22p1 = vec3(0.10000, 0.10000, 0.10000);
	vec3 n_out22p0 = n_out14p0 * n_in22p1;


// VectorOp:13
	vec3 n_out13p0 = n_out11p0 + n_out22p0;


// Output:0
	VERTEX = n_out13p0;


}

void fragment() {
// ColorParameter:18
	vec4 n_out18p0 = BaseColor;


// ColorParameter:13
	vec4 n_out13p0 = WindColor;


// Input:14
	vec2 n_out14p0 = UV;


// VectorDecompose:16
	float n_out16p0 = n_out14p0.x;
	float n_out16p1 = n_out14p0.y;


// FloatFunc:17
	float n_out17p0 = 1.0 - n_out16p1;


// Mix:15
	vec3 n_out15p0 = mix(vec3(n_out18p0.xyz), vec3(n_out13p0.xyz), vec3(n_out17p0));


// FloatConstant:4
	float n_out4p0 = 0.000000;


// VectorCompose:5
	float n_in5p0 = 0.00000;
	float n_in5p1 = 1.00000;
	float n_in5p2 = 0.00000;
	vec3 n_out5p0 = vec3(n_in5p0, n_in5p1, n_in5p2);


// Output:0
	ALBEDO = n_out15p0;
	ROUGHNESS = n_out4p0;
	NORMAL = n_out5p0;
	NORMAL_MAP = n_out5p0;


}
