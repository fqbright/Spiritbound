shader_type canvas_item;

// Holographic iridescent foil sheen sweep for Rare and Upgraded cards
uniform float foil_speed : hint_range(0.1, 5.0) = 0.75;
uniform float foil_intensity : hint_range(0.0, 1.0) = 0.38;
uniform float foil_width : hint_range(0.1, 1.0) = 0.40;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.05) {
		float pos = (UV.x + UV.y * 0.8) * 0.5;
		float t = mod(TIME * foil_speed, 2.5) - 0.75;
		float dist = abs(pos - t);
		if (dist < foil_width) {
			float band = cos(dist / foil_width * 1.570796);
			float hue = mod(pos * 2.5 + TIME * 0.25, 1.0);
			vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
			tex.rgb = mix(tex.rgb, tex.rgb + rainbow * 0.75, band * foil_intensity);
		}
	}
	COLOR = tex;
}
