// Greybox world-space grid: 1 m minor lines, 10 m major lines. Makes scale readable
// (1 unit = 1 metre) without any texture assets. Works in Forward+ and Compatibility.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.40, 0.43, 0.38, 1.0);
uniform vec4 minor_color : source_color = vec4(0.34, 0.37, 0.32, 1.0);
uniform vec4 major_color : source_color = vec4(0.27, 0.29, 0.25, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p, float cell, float width) {
	vec2 g = abs(fract(p / cell - 0.5) - 0.5) * cell;
	vec2 aa = fwidth(p) * width;
	vec2 l = 1.0 - smoothstep(vec2(0.0), aa, g);
	return max(l.x, l.y);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = world_pos.xz;
	if (n.x > n.y && n.x > n.z) {
		p = world_pos.zy;
	} else if (n.z > n.y) {
		p = world_pos.xy;
	}
	float minor = grid_line(p, 1.0, 1.0);
	float major = grid_line(p, 10.0, 1.6);
	vec3 c = mix(base_color.rgb, minor_color.rgb, minor);
	c = mix(c, major_color.rgb, major);
	ALBEDO = c;
	ROUGHNESS = roughness_value;
}
