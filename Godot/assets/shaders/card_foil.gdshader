shader_type canvas_item;

// Holographic iridescent foil sheen sweep with crystalline prism refraction
uniform float foil_speed : hint_range(0.1, 5.0) = 0.85;
uniform float foil_intensity : hint_range(0.0, 1.0) = 0.42;
uniform float foil_width : hint_range(0.1, 1.0) = 0.45;
uniform float tilt_shift : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.05) {
		float pos = (UV.x + UV.y * 0.85 + tilt_shift * 0.3) * 0.5;
		float t = mod(TIME * foil_speed, 2.6) - 0.8;
		float dist = abs(pos - t);
		if (dist < foil_width) {
			float band = cos(dist / foil_width * 1.570796);
			// Prismatic color diffraction with secondary shimmer
			float hue = mod(pos * 3.0 + TIME * 0.35 + UV.x * 0.5, 1.0);
			vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
			float sparkle = sin(UV.x * 60.0 + TIME * 4.0) * cos(UV.y * 60.0 - TIME * 4.0);
			sparkle = max(0.0, sparkle * 0.3);
			vec3 sheen = rainbow * 0.85 + vec3(sparkle);
			tex.rgb = mix(tex.rgb, tex.rgb + sheen, band * foil_intensity);
		}
	}
	COLOR = tex;
}
