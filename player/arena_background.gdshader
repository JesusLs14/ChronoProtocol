shader_type canvas_item;

// Fondo de la arena: piso metálico oscuro con paneles, juntas que brillan
// en cian, remaches y un pulso de energía que recorre el piso.
uniform vec2 area_size = vec2(3136.0, 2176.0);
uniform float panel_size = 128.0;
uniform vec4 base_color : source_color = vec4(0.06, 0.08, 0.13, 1.0);
uniform vec4 panel_color : source_color = vec4(0.10, 0.13, 0.20, 1.0);
uniform vec4 glow_color : source_color = vec4(0.10, 0.85, 0.95, 1.0);
uniform vec4 core_color : source_color = vec4(0.85, 0.20, 0.35, 1.0);
uniform float pulse_speed = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 pos = UV * area_size;
	vec2 cell = floor(pos / panel_size);
	vec2 local = fract(pos / panel_size);
	float variation = hash(cell);

	// Panel con bisel: más claro en el centro y oscuro en los bordes.
	vec2 edge = min(local, 1.0 - local);
	float edge_distance = min(edge.x, edge.y);
	float bevel = smoothstep(0.0, 0.08, edge_distance);
	vec3 color = mix(base_color.rgb, panel_color.rgb * (0.85 + 0.3 * variation), bevel);

	// Líneas diagonales finas en algunos paneles.
	if (variation > 0.72) {
		float stripes = step(0.5, fract((local.x + local.y) * 6.0));
		color *= 0.92 + 0.08 * stripes;
	}

	// Remaches en las esquinas de cada panel.
	vec2 corner = abs(local - 0.5);
	float rivet = 1.0 - smoothstep(0.012, 0.025, distance(corner, vec2(0.40)));
	color += vec3(0.10, 0.13, 0.18) * rivet;

	// Juntas brillantes entre paneles.
	float seam = 1.0 - smoothstep(0.0, 0.02, edge_distance);
	vec2 center_offset = pos / area_size - 0.5;
	float distance_to_center = length(center_offset * vec2(area_size.x / area_size.y, 1.0));
	float pulse = 0.5 + 0.5 * sin(distance_to_center * 18.0 - TIME * pulse_speed * 6.2831);
	color += glow_color.rgb * seam * (0.18 + 0.35 * pulse * pulse);

	// Núcleo de energía en el centro de la arena.
	float core = 1.0 - smoothstep(0.0, 0.18, distance_to_center);
	float ring = 1.0 - smoothstep(0.0, 0.006, abs(distance_to_center - 0.12 - 0.01 * sin(TIME * 2.0)));
	color += core_color.rgb * (core * 0.12 + ring * 0.35);

	// Oscurece hacia los bordes de la arena.
	float vignette = smoothstep(0.75, 0.25, distance_to_center);
	color *= 0.55 + 0.45 * vignette;

	COLOR = vec4(color, 1.0);
}
