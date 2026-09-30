shader_type canvas_item;

// Driven from GDScript on hit: set to 1.0, tween back to 0.0 over a couple of frames.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);

// Organic idle breathing motion
uniform float breath_speed : hint_range(0.0, 4.0) = 1.6;
uniform float breath_height : hint_range(0.0, 0.05) = 0.012;
uniform float breath_expand : hint_range(0.0, 0.04) = 0.006;

void vertex() {
	if (breath_speed > 0.0) {
		float phase = sin(TIME * breath_speed);
		float factor = 1.0 - UV.y;
		VERTEX.y -= phase * breath_height * 50.0 * factor;
		VERTEX.x += (UV.x - 0.5) * phase * breath_expand * 30.0 * factor;
	}
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color, flash_amount), tex.a);
}
