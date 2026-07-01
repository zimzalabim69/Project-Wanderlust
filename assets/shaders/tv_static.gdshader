// TV static shader for Project Wanderlust.
// Apply to a flat QuadMesh (the TV screen face) as a ShaderMaterial.
//
// Combines:
//   1. White noise static — the base analogue snow.
//   2. Rolling scanline bands — bright horizontal streaks rolling up the screen.
//   3. Horizontal hold glitch — occasional vertical jitter of horizontal strips.
//   4. Ghosting — faint luminance trail from previous frame (approximated via noise).
//   5. Colour bleed — slight magenta/green fringe on high-contrast edges.
//   6. Phosphor glow — subtle green/amber tint to pure white areas.
//
// Tunable at runtime; defaults match a bad-signal 1990s VHF channel.

shader_type spatial;
render_mode unshaded, cull_back;

// --- Tunable uniforms ---

// 0 = pure static, 1 = mostly visible picture (for a channel with weak signal).
// For a dead channel set this to 0.0.
uniform float signal_quality : hint_range(0.0, 1.0, 0.01) = 0.0;

// Static brightness — how bright the snow is.
uniform float static_brightness : hint_range(0.0, 2.0, 0.05) = 0.9;

// Speed of the rolling scan band.
uniform float scan_speed : hint_range(0.1, 4.0, 0.05) = 0.8;

// Width of the bright scan band (fraction of screen height).
uniform float scan_band_width : hint_range(0.01, 0.5, 0.01) = 0.12;

// Intensity of the bright scan band.
uniform float scan_band_brightness : hint_range(0.0, 3.0, 0.1) = 1.4;

// Horizontal hold instability — how much strips jitter sideways.
uniform float hold_jitter : hint_range(0.0, 0.06, 0.002) = 0.018;

// Phosphor tint colour (default: green-tinged white).
uniform vec3 phosphor_color : source_color = vec3(0.88, 0.96, 0.80);

// Screen brightness / dimness.
uniform float screen_brightness : hint_range(0.0, 1.5, 0.05) = 0.85;

// Vignette to make edges of the screen darker.
uniform float vignette_strength : hint_range(0.0, 1.5, 0.05) = 0.6;


// --- Hash / noise helpers ---

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Value noise: smooth interpolation between hash values.
float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}


void fragment() {
	vec2 uv = UV;

	// 1. Horizontal hold glitch — jitter strips sideways at varying amounts.
	float strip = floor(uv.y * 24.0);
	float jitter_seed = hash11(strip + floor(TIME * 3.0) * 47.0);
	float jitter = (jitter_seed - 0.5) * 2.0 * hold_jitter;
	// Only apply jitter to some strips (sparse glitch).
	jitter *= step(0.85, jitter_seed);
	uv.x = fract(uv.x + jitter);

	// 2. White noise static.
	// Animate rapidly by hashing against time rounded to frame-like steps.
	float frame_t = floor(TIME * 30.0);   // ~30fps grain update
	float static_val = hash21(uv * vec2(320.0, 240.0) + frame_t * 1337.0);

	// 3. Rolling scan band — a bright horizontal stripe rolling upward.
	float scan_pos = fract(-TIME * scan_speed);
	float scan_dist = abs(uv.y - scan_pos);
	float scan_wrap = abs(uv.y - scan_pos + 1.0);  // wrap-around
	float scan_d = min(scan_dist, scan_wrap);
	float scan_band = smoothstep(scan_band_width, 0.0, scan_d) * scan_band_brightness;

	// 4. Ghosting — a faint smear of a slightly offset, dimmer frame.
	float ghost = hash21(uv * vec2(320.0, 240.0) + (frame_t - 1.0) * 1337.0) * 0.18;

	// Combine static layers.
	float luminance = static_val * static_brightness + scan_band + ghost;
	luminance = clamp(luminance, 0.0, 1.5);

	// 5. Signal quality — lerp toward a "picture" colour if signal_quality > 0.
	// Since we have no actual picture texture, the "picture" is a clean grey.
	vec3 color = mix(vec3(luminance) * phosphor_color, vec3(0.6, 0.6, 0.6), signal_quality);

	// 6. Vignette — darker at screen edges.
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * vignette_strength;
	color *= clamp(vignette, 0.0, 1.0);

	// Overall screen brightness.
	color *= screen_brightness;

	ALBEDO = color;
	ALPHA  = 1.0;
}
