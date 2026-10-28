shader_type canvas_item;

// Contaminación del Soldado Cero: tiñe al soldado de morado, le pasa venas
// verdes que laten, vuelve rojos los brillos cian (visor y luces de la
// armadura) y da parpadeos de glitch. glitch sube cuando se enfurece.

uniform vec4 tint : source_color = vec4(0.62, 0.3, 0.85, 1.0);
uniform vec4 vein_color : source_color = vec4(0.45, 1.0, 0.35, 1.0);
uniform vec4 eye_color : source_color = vec4(1.0, 0.12, 0.1, 1.0);
uniform float glitch : hint_range(0.0, 1.0) = 0.3;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = TIME;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 base = mix(c.rgb, tint.rgb * lum * 1.9, 0.7);

	// Venas: bandas onduladas que laten.
	float n = sin(UV.x * 140.0 + sin(UV.y * 90.0 + t * 1.7) * 4.0) * sin(UV.y * 160.0 - t * 1.3);
	float vein = smoothstep(0.82, 1.0, n) * (0.55 + 0.45 * sin(t * 4.5));
	base = mix(base, vein_color.rgb * 1.3, vein * 0.75);

	// Los brillos cian del traje se vuelven rojos.
	float cyan = smoothstep(0.15, 0.45, c.b - c.r) * smoothstep(0.35, 0.7, c.g);
	base = mix(base, eye_color.rgb * 1.8, cyan);

	// Glitch: franjas horizontales que se encienden de golpe.
	float band = floor(UV.y * 60.0);
	float flicker = step(1.0 - 0.12 * glitch, hash(band + floor(t * 14.0)));
	base = mix(base, vec3(base.g, base.b, base.r) + vein_color.rgb * 0.4, flicker);

	COLOR = vec4(base, c.a) * COLOR;
}
