shader_type canvas_item;

// Viñeta roja: transparente en el centro y más intensa hacia los bordes.
uniform float inner_radius = 0.35;
uniform float outer_radius = 0.85;

void fragment() {
	float distance_to_center = distance(UV, vec2(0.5)) * 1.41421356;
	float strength = smoothstep(inner_radius, outer_radius, distance_to_center);
	COLOR = vec4(COLOR.rgb, COLOR.a * strength);
}
