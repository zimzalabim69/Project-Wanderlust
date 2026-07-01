// PS1-style rendering shader for Project Wanderlust.
// Applies two signature PS1 rendering artifacts:
//   1. Vertex snapping — world-space positions are snapped to a coarse
//      integer grid before projection, producing the characteristic
//      "wobbly geometry" of the original PlayStation GPU.
//   2. Affine texture mapping — UV coordinates are NOT perspective-corrected;
//      they are interpolated linearly across screen-space, causing textures
//      to swim and warp on polygons viewed at an angle.
//
// Usage: assign this shader to a ShaderMaterial on any MeshInstance3D.
// The ps1_renderer.gd autoload applies it automatically to all scene geometry.

shader_type spatial;

// --- Tunable parameters (exposed to the Godot Inspector) ---

// Vertex grid resolution in world units.
// Lower = more aggressive snap / more wobble.
// PS1 resolution was roughly 1/200 to 1/50 of a meter depending on scene scale.
// Default 0.05 gives a clear but not headache-inducing effect at the 640x480 viewport.
uniform float snap_amount : hint_range(0.01, 1.0, 0.005) = 0.05;

// Affine warp strength. 1.0 = full PS1 affine (no perspective correction).
// 0.0 = modern perspective-correct UVs (defeats the effect).
// Values between 0.5 and 1.0 give a subtle-to-strong feel.
uniform float affine_strength : hint_range(0.0, 1.0, 0.05) = 0.85;

// Albedo texture (optional — falls back to albedo_color if none set).
uniform sampler2D albedo_texture : source_color, hint_default_white;

// Flat color tint (multiplied with texture sample).
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Ambient occlusion — baked AO texture (optional).
uniform sampler2D ao_texture : hint_default_white;

// Emissive colour and strength for glowing objects (TVs, neon signs, etc.).
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0, 0.1) = 0.0;

// Roughness / metallic — kept for PBR lighting compatibility.
uniform float roughness : hint_range(0.0, 1.0, 0.05) = 0.9;
uniform float metallic  : hint_range(0.0, 1.0, 0.05) = 0.0;

// Dither transparency threshold (0 = fully opaque, 1 = nearly invisible).
// Uses a Bayer 4×4 matrix so transparency is pixelated, not smooth — very PS1.
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.0;

// --- Varying: pass affine UV from vertex to fragment ---
// We carry both the affine (w-divided) UV and the raw w value so the fragment
// shader can blend between affine and perspective-correct modes.
varying vec2 affine_uv;
varying float vertex_w;

// --- Vertex shader ---
void vertex() {
	// 1. Vertex snapping.
	//    Convert to clip space, divide by w to get NDC, snap to grid, then
	//    reconstruct. This replicates the PS1 fixed-point integer coordinate
	//    truncation that caused geometry to "swim" during movement.
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 snapped = round(clip_pos.xy / clip_pos.w * (1.0 / snap_amount)) * snap_amount;
	clip_pos.xy = snapped * clip_pos.w;
	POSITION = clip_pos;

	// 2. Affine UV interpolation.
	//    On a real PS1 the rasteriser divided UV by z once per primitive, not
	//    per pixel — effectively multiplying UVs by w in clip space before the
	//    perspective divide. We emulate this by storing UV * w in a varying;
	//    the fragment shader then divides by the interpolated w to recover UVs
	//    that swim just like original PS1 hardware.
	vertex_w = clip_pos.w;
	affine_uv = UV * clip_pos.w;
}

// --- Fragment shader ---
void fragment() {
	// Reconstruct affine-warped UV.
	// When affine_strength = 1.0 we use the raw affine_uv / vertex_w (full
	// PS1 warp). When 0.0 we use the hardware perspective-correct UV.
	vec2 ps1_uv = mix(UV, affine_uv / vertex_w, affine_strength);

	// Sample albedo texture and apply colour tint.
	vec4 tex = texture(albedo_texture, ps1_uv) * albedo_color;

	// Bayer 4×4 dither for alpha cutout (transparent foliage, fences, etc.)
	// The matrix is normalised to [0, 1].
	if (alpha_scissor_threshold > 0.0) {
		const mat4 bayer = mat4(
			vec4( 0.0,  8.0,  2.0, 10.0),
			vec4(12.0,  4.0, 14.0,  6.0),
			vec4( 3.0, 11.0,  1.0,  9.0),
			vec4(15.0,  7.0, 13.0,  5.0)
		) / 16.0;
		ivec2 px  = ivec2(mod(FRAGCOORD.xy, 4.0));
		float threshold = bayer[px.x][px.y];
		if (tex.a - alpha_scissor_threshold < threshold) {
			discard;
		}
	}

	// Ambient occlusion.
	float ao = texture(ao_texture, ps1_uv).r;

	// Write to Godot's spatial output.
	ALBEDO    = tex.rgb * ao;
	ROUGHNESS = roughness;
	METALLIC  = metallic;
	EMISSION  = emission_color.rgb * emission_energy;
	ALPHA     = tex.a;
}
