// CRT post-process shader for Project Wanderlust.
// Applied as a CanvasLayer over the entire viewport (ui/crt_overlay.tscn).
//
// Effects:
//   1. Scanlines — horizontal dark bands mimicking a CRT electron gun.
//   2. Vignette  — darkens screen edges, draws focus to centre.
//   3. Chromatic aberration — slight RGB fringe toward screen edges.
//   4. Subtle screen curvature (barrel distortion) — optional, mild.
//   5. Noise grain — single-frame random noise for film grain texture.

shader_type canvas_item;

// --- Tunable parameters ---

// Scanline darkness. 0 = invisible, 1 = fully black lines.
uniform float scanline_strength : hint_range(0.0, 1.0, 0.01) = 0.18;

// Scanline frequency relative to screen height.
// Higher = more scanlines (thinner lines, closer together).
uniform float scanline_count : hint_range(100.0, 800.0, 10.0) = 240.0;

// Vignette intensity. 0 = none, 1 = very heavy.
uniform float vignette_strength : hint_range(0.0, 2.0, 0.05) = 0.55;

// Vignette shape: higher = more concentrated toward edges.
uniform float vignette_power : hint_range(1.0, 6.0, 0.1) = 2.0;

// Chromatic aberration max offset in UV units.
// PS1 screens had noticeable colour fringing at the edges.
uniform float aberration_strength : hint_range(0.0, 0.012, 0.001) = 0.004;

// Film grain intensity.
uniform float grain_strength : hint_range(0.0, 0.15, 0.005) = 0.04;

// Barrel distortion amount. 0 = flat, 0.05 = subtle curve.
uniform float barrel_distortion : hint_range(0.0, 0.12, 0.005) = 0.02;

// Overall brightness multiplier (use to compensate for scanline darkening).
uniform float brightness : hint_range(0.5, 1.5, 0.01) = 1.05;

// Time is supplied by Godot automatically — used for grain animation.
uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;


// --- Helpers ---

// Simple hash for pseudo-random grain.
float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

// Barrel distortion: maps flat UV to curved UV.
vec2 barrel(vec2 uv) {
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	c *= 1.0 + barrel_distortion * r2;
	return c + 0.5;
}


void fragment() {
	// 1. Barrel / lens distortion.
	vec2 uv = barrel(UV);

	// Clip pixels that land outside the curved screen area.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	// 2. Chromatic aberration — shift R and B channels outward from centre.
	vec2 dir = uv - 0.5;
	float dist = length(dir);
	vec2 aberr_offset = normalize(dir + vec2(0.0001)) * dist * aberration_strength;

	float r = texture(TEXTURE, uv + aberr_offset).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - aberr_offset).b;
	float a = texture(TEXTURE, uv).a;

	vec3 color = vec3(r, g, b);

	// 3. Scanlines — modulate brightness by a sine wave aligned to screen rows.
	float scan = sin(uv.y * scanline_count * PI);
	// Smooth the sine so lines have soft edges rather than hard cutoff.
	scan = scan * 0.5 + 0.5;  // remap [−1,1] → [0,1]
	scan = pow(scan, 0.6);     // sharpen the bright band
	color *= mix(1.0 - scanline_strength, 1.0, scan);

	// 4. Vignette — radial darkening.
	float vignette = 1.0 - pow(dist * 2.0, vignette_power) * vignette_strength;
	vignette = clamp(vignette, 0.0, 1.0);
	color *= vignette;

	// 5. Film grain — changes every frame via TIME.
	float grain = hash(uv + fract(TIME * 0.07 + time_offset));
	// Centre grain around 0 so it adds and subtracts equally.
	grain = (grain - 0.5) * grain_strength;
	color += grain;

	// 6. Overall brightness correction.
	color *= brightness;

	COLOR = vec4(clamp(color, 0.0, 1.0), a);
}
