shader_type canvas_item;

// Hit flash support for combat reactions
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);

// Breathing & organic articulation pinned at feet
uniform float breath_speed : hint_range(0.0, 5.0) = 1.6;
uniform float breath_height : hint_range(0.0, 0.08) = 0.016;
uniform float breath_expand : hint_range(0.0, 0.08) = 0.010;
uniform float breathing_enabled : hint_range(0.0, 1.0) = 1.0;

// Dynamic 2.5D Volumetric Lighting (Spirit Orb / Combat FX reactive)
uniform vec2 light_pos = vec2(0.8, 0.2); // UV space of light source relative to sprite
uniform vec4 light_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float light_radius : hint_range(0.1, 4.0) = 1.5;
uniform float light_intensity : hint_range(0.0, 3.0) = 0.65;
uniform float ambient_intensity : hint_range(0.0, 1.2) = 0.85;

// Volumetric Rim & Specular Highlights
uniform float rim_power : hint_range(0.5, 8.0) = 2.5;
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.40;
uniform vec4 rim_color : source_color = vec4(0.35, 0.88, 1.0, 1.0);
uniform float specular_power : hint_range(2.0, 64.0) = 16.0;
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.35;
uniform float normal_depth : hint_range(0.1, 5.0) = 2.2;

void vertex() {
	if (breathing_enabled > 0.5 && breath_speed > 0.0) {
		float phase = sin(TIME * breath_speed);
		// Pinned at feet: UV.y = 1.0 at bottom, 0.0 at top. Factor 1.0 - UV.y increases towards chest/head
		float factor = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.2);
		VERTEX.y -= phase * breath_height * 60.0 * factor;
		VERTEX.x += (UV.x - 0.5) * phase * breath_expand * 40.0 * factor;
	}
}

void fragment() {
	vec4 base_col = texture(TEXTURE, UV);
	if (base_col.a < 0.01) {
		discard;
	}

	// Analytical 2.5D Normal reconstruction from texture alpha & luminance
	vec2 step = 1.0 / vec2(textureSize(TEXTURE, 0));

	// Sample neighbors
	float aL = texture(TEXTURE, UV - vec2(step.x * 2.0, 0.0)).a;
	float aR = texture(TEXTURE, UV + vec2(step.x * 2.0, 0.0)).a;
	float aU = texture(TEXTURE, UV - vec2(0.0, step.y * 2.0)).a;
	float aD = texture(TEXTURE, UV + vec2(0.0, step.y * 2.0)).a;

	// Surface slope from alpha boundary
	float dx = (aL - aR) * normal_depth;
	float dy = (aU - aD) * normal_depth;

	// Subtle spherical dome curvature across sprite body to give volumetric 3D roundness
	vec2 center_offset = (UV - vec2(0.5, 0.5)) * 2.0;
	dx += center_offset.x * 0.45;
	dy += center_offset.y * 0.45;

	vec3 normal = normalize(vec3(dx, dy, 1.0));

	// Light vector in UV space
	vec3 light_dir = vec3(light_pos - UV, 0.35);
	float light_dist = length(light_dir.xy);
	light_dir = normalize(light_dir);

	// Distance attenuation
	float atten = clamp(1.0 - (light_dist / light_radius), 0.0, 1.0);
	atten = atten * atten;

	// Diffuse term
	float n_dot_l = max(dot(normal, light_dir), 0.0);
	vec3 diffuse = light_color.rgb * n_dot_l * light_intensity * atten;

	// Blinn-Phong Specular
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	vec3 half_vector = normalize(light_dir + view_dir);
	float n_dot_h = max(dot(normal, half_vector), 0.0);
	float spec = pow(n_dot_h, specular_power) * specular_intensity * atten;
	vec3 specular = light_color.rgb * spec;

	// Fresnel / Rim Lighting (grazing angles where normal is perpendicular to view)
	float rim_factor = 1.0 - max(dot(normal, view_dir), 0.0);
	rim_factor = pow(rim_factor, rim_power) * rim_intensity;
	vec3 rim = rim_color.rgb * rim_factor;

	// Combine ambient, diffuse, specular, and rim
	vec3 lit_color = base_col.rgb * (ambient_intensity + diffuse) + specular + rim;

	// Hit flash overlay
	lit_color = mix(lit_color, flash_color, flash_amount);

	COLOR = vec4(lit_color, base_col.a);
}
