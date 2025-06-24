shader_type canvas_item;

// Texture uniforms
uniform sampler2D noise_texture : hint_default_white;
uniform sampler2D color_noise_texture : hint_default_white;

// Foliage control parameters
uniform float foliage_density : hint_range(0.0, 1.0) = 0.8;
uniform float foliage_threshold : hint_range(0.0, 1.0) = 0.15; // Threshold for foliage presence
uniform float limb_threshold : hint_range(0.0, 1.0) = 0.6; // Higher threshold to mask out limbs (should be > foliage_threshold)
uniform float foliage_expansion_lateral : hint_range(0.0, 1.0) = 0.1; // How far leaves extend beyond branches
uniform float foliage_expansion_vertical : hint_range(0.0, 1.0) = 0.1; // How far leaves extend beyond branches
uniform float min_foliage_height : hint_range(0.0, 1.0) = 0.3; // Minimum height where foliage can appear (0=bottom, 1=top)

// Color parameters
instance uniform vec4 foliage_color : source_color = vec4(0.8, 0.0, 0.0, 1.0);
instance uniform vec4 foliage_color_variation : source_color = vec4(1.0, 0.34, 0.0, 1.0);
uniform float color_variation_strength : hint_range(0.0, 1.0) = 0.3;

// Animation parameters
uniform float wind_strength : hint_range(0.0, 2.0) = 0.0;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec2 wind_direction = vec2(1.0, 0.3);

void fragment() {
	// Sample the base tree texture (from the sprite this shader is applied to)
	vec4 tree_color = texture(TEXTURE, UV);
	
	// Sample noise texture multiple times for more complex patterns
	float noise1 = texture(noise_texture, UV).r;
	float noise2 = texture(noise_texture, UV * 2.3 + vec2(0.5, 0.3)).r;
	float noise3 = texture(noise_texture, UV * 0.7 + vec2(0.2, 0.8)).r;
	
	// Combine noise layers
	float combined_noise = (noise1 * 0.5 + noise2 * 0.3 + noise3 * 0.2);
    //combined_noise = 1.0; // For testing, set to 1.0 to visualize tree without noise
	
    // Height-based foliage distribution with minimum height threshold
	// Since tree origin is at bottom center, invert the height calculation
	float tree_height_normalized = 1.0 - UV.y; // 0=bottom, 1=top
	float height_factor = smoothstep(min_foliage_height, 2.0*min_foliage_height, tree_height_normalized);
    // Create foliage mask based on tree presence (alpha channel)
	float tree_alpha = tree_color.a * height_factor;
    
	// Create expanded foliage area - dilate the tree mask
	float expanded_tree = tree_alpha;
	
	// Sample surrounding pixels to create expansion effect
	for(float x = -foliage_expansion_lateral; x <= foliage_expansion_lateral; x += 0.01) {
		for(float y = -foliage_expansion_vertical; y <= foliage_expansion_vertical; y += 0.01) {
			vec2 sample_uv = UV + vec2(x, y);
			// Ensure we stay within bounds
			if(sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0-min_foliage_height) {
				vec4 sample_color = texture(TEXTURE, sample_uv);
				float sample_alpha = sample_color.a;
                float distance_alpha = 1.0 - step(foliage_expansion_lateral*foliage_expansion_vertical,(x*x + y*y));
				expanded_tree = max(expanded_tree, sample_alpha * distance_alpha); // Fade expansion
			}
		}
	}
	
	// Blend original tree with expanded area
	float final_tree_factor = expanded_tree;
	
	// More generous distance factor for leaf expansion - centered around tree
	vec2 center_offset = abs(UV - vec2(0.5, 1.0)); // Center horizontally, bottom vertically (tree base)
	float distance_factor = 1.0 - smoothstep(0.05, 0.8, length(center_offset));

	// Calculate foliage mask
	float foliage_mask = combined_noise * final_tree_factor;//distance_factor * height_factor;
	
	// Create color variation for foliage - use separate noise texture for more varied colors
	float color_noise = texture(color_noise_texture, UV).r;
	vec4 varied_foliage_color = mix(
		foliage_color, 
		foliage_color_variation, 
		color_noise * color_variation_strength
	);
	
	// Create soft edges for foliage
	float edge_softness = 0.1;
	float soft_foliage = smoothstep(foliage_threshold - edge_softness, 
									foliage_threshold + edge_softness, 
									foliage_mask * foliage_density);
    
    // Apply limb masking to reduce limb visibility
    float limb_mask = 1.0 - (step(limb_threshold, combined_noise) * tree_alpha);

	// Combine tree and foliage
	vec4 final_color = tree_color;
	
	// Blend foliage onto tree
	final_color = mix(tree_color, varied_foliage_color, limb_mask * soft_foliage * varied_foliage_color.a);

	COLOR = final_color;
}