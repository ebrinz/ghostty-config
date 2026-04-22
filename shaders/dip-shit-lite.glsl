// dip-shit-lite.glsl
// Theme: Degraded VHS tape + CRT monitor — lightweight variant
// Static CRT look without time-based animation. Keeps barrel distortion,
// scanlines, color bleed, vignette, and static grain but no wobble,
// tracking bands, bursts, or tape artifacts.
//
// Setup:
//   1. Save to ~/.config/ghostty/shaders/dip-shit-lite.glsl
//   2. Add to Ghostty config:
//        theme = dip-shit
//        custom-shader = ~/.config/ghostty/shaders/dip-shit-lite.glsl
//   3. Reload with Cmd+Shift+, or restart Ghostty.
//
// ========== TUNABLE PARAMETERS ==========
#define CRT_CURVE     0.02
#define BRIGHTNESS    1.8
#define COLOR_BLEED   2.0
#define VIGNETTE      0.35
#define STATIC        0.9
// =========================================

float hash(vec2 p) {
    p = fract(p * vec2(443.8975, 397.2973));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // CRT barrel distortion
    vec2 cc = uv - 0.5;
    vec2 wuv = clamp(uv + cc * (dot(cc, cc) * CRT_CURVE), 0.0, 1.0);

    // --- Color sampling with chromatic aberration ---

    float aberr = 0.0003 * COLOR_BLEED;
    vec3 color;
    color.r = texture(iChannel0, wuv + vec2(aberr, 0.0)).r;
    color.g = texture(iChannel0, wuv).g;
    color.b = texture(iChannel0, wuv - vec2(aberr, 0.0)).b;

    // Rightward color bleed
    float px = 1.0 / iResolution.x;
    vec3 s_r1 = texture(iChannel0, wuv + vec2(px, 0.0)).rgb;
    vec3 s_r2 = texture(iChannel0, wuv + vec2(px * 3.0, 0.0)).rgb;
    vec3 nb = s_r1 * 0.4 + s_r2 * 0.6;
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = luma + mix(color - luma, nb - dot(nb, vec3(0.299, 0.587, 0.114)), 0.5 * COLOR_BLEED);

    // --- Post-processing ---

    color *= BRIGHTNESS;

    // Warm shift
    color *= vec3(1.03, 1.01, 0.96);

    // Scanlines
    color *= 1.0 - 0.08 * mod(floor(fragCoord.y), 2.0);

    // Vignette
    vec2 vig = uv * (1.0 - uv);
    color *= mix(1.0, clamp(vig.x * vig.y * 15.0, 0.0, 1.0), VIGNETTE);

    // Static grain (seeded from pixel position only — no time dependence)
    float grain = hash(fragCoord.xy * 0.37);
    color = mix(color, vec3(1.0), step(1.0 - 0.001 * STATIC, grain) * 0.15 * STATIC);

    fragColor = vec4(color, 1.0);
}
