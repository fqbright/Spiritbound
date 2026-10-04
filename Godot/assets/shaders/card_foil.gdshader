shader_type canvas_item;

// Holographic iridescent foil sheen sweep with crystalline prism refraction
uniform float foil_speed : hint_range(0.1, 5.0) = 0.85;
uniform float foil_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float foil_width : hint_range(0.1, 1.0) = 0.48;
uniform float tilt_shift : hint_range(-1.0, 1.0) = 0.0;
uniform vec2 tilt_offset = vec2(0.0, 0.0);
uniform bool is_gold_foil = false;

// Pseudo-noise for holographic glitter flecks
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.05) {
		vec2 p = UV + tilt_offset * 0.35;
		float pos = (p.x * 0.85 + p.y * 1.1 + (tilt_shift + tilt_offset.x) * 0.4) * 0.5;
		float t = mod(TIME * foil_speed, 2.6) - 0.8;
		float dist = abs(pos - t);
		if (dist < foil_width) {
			float band = cos(dist / foil_width * 1.570796);
			// Prismatic color diffraction with secondary shimmer
			float hue = mod(pos * 3.2 + TIME * 0.4 + UV.x * 0.5, 1.0);
			vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
			if (is_gold_foil) {
				vec3 gold = vec3(1.0, 0.85, 0.35);
				rainbow = mix(rainbow, gold, 0.60);
			}
			// Micro glitter sparkle
			vec2 grid = floor(UV * 80.0);
			float n = hash(grid + floor(tilt_offset * 8.0));
			float sparkle = step(0.86, n) * 0.35 * (0.5 + 0.5 * sin(TIME * 6.0 + n * 6.28));
			vec3 sheen = rainbow * 0.90 + vec3(sparkle);
			tex.rgb = mix(tex.rgb, tex.rgb + sheen, band * foil_intensity);
		}
	}
	COLOR = tex;
}
