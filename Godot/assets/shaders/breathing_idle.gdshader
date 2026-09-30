shader_type canvas_item;

// Idle breathing motion and subtle cultivation aura glow
uniform float breath_speed : hint_range(0.5, 4.0) = 1.6;
uniform float breath_height : hint_range(0.0, 0.05) = 0.015;
uniform float breath_expand : hint_range(0.0, 0.04) = 0.008;
uniform vec4 rim_color : source_color = vec4(0.4, 0.9, 1.0, 0.0);
uniform float rim_power : hint_range(0.0, 2.0) = 0.0;

void vertex() {
	// Vertical breathing cycle using smooth sine wave
	float phase = sin(TIME * breath_speed);
	// Feet stay pinned to ground (UV.y near 1.0), upper torso floats & expands smoothly
	float factor = 1.0 - UV.y;
	VERTEX.y -= phase * breath_height * 60.0 * factor;
	VERTEX.x += (UV.x - 0.5) * phase * breath_expand * 40.0 * factor;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (rim_power > 0.0 && tex.a > 0.05) {
		float rim_pulse = sin(TIME * breath_speed) * 0.5 + 0.5;
		COLOR = mix(tex, vec4(rim_color.rgb, tex.a), rim_color.a * rim_pulse * rim_power);
	} else {
		COLOR = tex;
	}
}
