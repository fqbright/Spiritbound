shader_type canvas_item;

// Driven from GDScript on hit: set to 1.0, tween back to 0.0 over a couple of frames.
// Runs alongside the node's own `modulate` (elemental tints, fade-outs) since the engine
// applies modulate to the shader's output, not the other way around.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color, flash_amount), tex.a);
}
