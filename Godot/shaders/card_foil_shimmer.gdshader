shader_type canvas_item;

uniform float foil_intensity : hint_range(0.0, 1.0) = 0.38;
uniform float shimmer_time = 0.0;
uniform vec2 tilt_offset = vec2(0.0, 0.0);
uniform bool is_gold_foil = false;
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.35;

// Compact pseudo-noise for holographic glitter flecks
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a < 0.02) {
        COLOR = tex_color;
    } else {
        // Diagonal perspective coordinates shifted by card tilt and time
        vec2 p = UV + tilt_offset * 0.35;
        float diag = (p.x * 0.8 + p.y * 1.2) * 2.2 + tilt_offset.x * 2.0 + shimmer_time * 0.45;
        
        // Holographic rainbow spectrum (Cosine gradient)
        vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (diag + vec3(0.0, 0.33, 0.67)));
        if (is_gold_foil) {
            // Gold-biased iridescence
            vec3 gold = vec3(1.0, 0.82, 0.35);
            rainbow = mix(rainbow, gold, 0.55);
        }
        
        // Sweeping diagonal specular sheen band
        float sweep = sin(diag * 1.8);
        float sheen = smoothstep(0.75, 0.98, sweep);
        
        // Micro-glitter flecks (reactive to tilt)
        vec2 grid = floor(UV * 85.0);
        float n = hash(grid + floor(tilt_offset * 12.0));
        float glitter = step(0.88, n) * sparkle_strength * (0.5 + 0.5 * sin(shimmer_time * 4.0 + n * 6.28));
        
        // Blend sheen & rainbow onto base texture
        vec3 foil_effect = rainbow * (0.28 + sheen * 0.55) + vec3(glitter);
        vec3 final_rgb = mix(tex_color.rgb, tex_color.rgb + foil_effect, foil_intensity);
        
        COLOR = vec4(final_rgb, tex_color.a);
    }
}
