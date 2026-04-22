// dip-shit-static.glsl
// Theme: Degraded VHS tape + CRT monitor — static variant
// Frozen-in-time VHS frame. All the distortion artifacts baked at a single
// moment: tracking error, color bleed, tape noise, scanlines. No animation.
//
// Setup:
//   1. Save to ~/.config/ghostty/shaders/dip-shit-static.glsl
//   2. Add to Ghostty config:
//        theme = dip-shit
//        custom-shader = ~/.config/ghostty/shaders/dip-shit-static.glsl
//   3. Reload with Cmd+Shift+, or restart Ghostty.
//
// ========== TUNABLE PARAMETERS ==========
#define CRT_CURVE     0.02
#define BRIGHTNESS    1.8
#define DISTORTION    1.0
#define TAPE_WEAR     1.75
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

    // --- Static signal distortion (frozen wobble) ---

    wuv.x += (sin(wuv.y * 40.0) * 0.000375
            + sin(wuv.y * 80.0) * 0.0001875
            + (hash(vec2(floor(fragCoord.y), 42.0)) - 0.5) * 0.0006) * DISTORTION;

    // Frozen tracking band at ~30% height
    float tracking_y = 0.3;
    float band = smoothstep(0.05, 0.0, abs(wuv.y - tracking_y));
    float h_offset = band * (hash(vec2(floor(fragCoord.y * 0.5), 7.7)) - 0.5) * 0.006 * DISTORTION;

    vec2 sample_uv = clamp(wuv + vec2(h_offset, 0.0), 0.0, 1.0);

    // --- Color sampling ---

    float aberr = (0.0003 + band * 0.0015) * COLOR_BLEED;
    vec3 color;
    color.r = texture(iChannel0, sample_uv + vec2(aberr, 0.0)).r;
    color.g = texture(iChannel0, sample_uv).g;
    color.b = texture(iChannel0, sample_uv - vec2(aberr, 0.0)).b;

    // Rightward color bleed
    float px = 1.0 / iResolution.x;
    vec3 s_r1 = texture(iChannel0, sample_uv + vec2(px, 0.0)).rgb;
    vec3 s_r2 = texture(iChannel0, sample_uv + vec2(px * 3.0, 0.0)).rgb;
    vec3 nb = s_r1 * 0.4 + s_r2 * 0.6;
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = luma + mix(color - luma, nb - dot(nb, vec3(0.299, 0.587, 0.114)), 0.5 * COLOR_BLEED);

    // --- Static tape artifacts ---

    // Head-switch noise at top of frame
    if (wuv.y > 0.97) {
        float hs = smoothstep(0.98, 1.0, wuv.y);
        color += hs * (hash(vec2(fragCoord.x, 55.0)) * 2.0 - 1.0) * 0.15 * TAPE_WEAR;
    }

    // Tape dropouts
    float dr = floor(fragCoord.y / 3.0);
    if (hash(vec2(dr, 33.0)) > 1.0 - 0.003 * TAPE_WEAR) {
        float dx = hash(vec2(dr, 34.0));
        if (wuv.x > dx && wuv.x < dx + hash(vec2(dr, 35.0)) * 0.15)
            color = mix(color, vec3(1.0), 0.05 * TAPE_WEAR);
    }

    // --- Post-processing ---

    color *= BRIGHTNESS;

    // Chroma noise
    float cn1 = hash(fragCoord.xy) - 0.5;
    float cn2 = hash(fragCoord.xy + 100.0) - 0.5;
    float gl = dot(color, vec3(0.299, 0.587, 0.114));
    color += (color - gl) * vec3(cn1, cn2, -cn1) * 0.15 * TAPE_WEAR;
    color += cn1 * 0.05 * TAPE_WEAR;

    // Warm shift
    color *= vec3(1.03, 1.01, 0.96);

    // Scanlines
    color *= 1.0 - 0.08 * mod(floor(fragCoord.y), 2.0);

    // Vignette
    vec2 vig = uv * (1.0 - uv);
    color *= mix(1.0, clamp(vig.x * vig.y * 15.0, 0.0, 1.0), VIGNETTE);

    // Static flecks
    color = mix(color, vec3(1.0), step(1.0 - 0.001 * STATIC, hash(vec2(floor(fragCoord.x / 10.0), floor(fragCoord.y / 2.0)) + 77.0)) * 0.15 * STATIC);

    fragColor = vec4(color, 1.0);
}
