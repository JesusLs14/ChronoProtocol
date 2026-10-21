shader_type canvas_item;

// Líneas de barrido y viñeta de pantalla vieja, para la transmisión de la intro.
uniform float line_count = 270.0;
uniform float line_strength = 0.18;
uniform float flicker = 0.03;

void fragment() {
	float line = 0.5 + 0.5 * sin(UV.y * line_count * 6.2831);
	float vignette = smoothstep(0.95, 0.35, distance(UV, vec2(0.5)) * 1.3);
	float noise = fract(sin(dot(UV * TIME, vec2(12.9898, 78.233))) * 43758.5453);
	float alpha = line * line_strength + (1.0 - vignette) * 0.6 + (noise - 0.5) * flicker;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(alpha, 0.0, 1.0));
}
