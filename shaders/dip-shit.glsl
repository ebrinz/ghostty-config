// dip-shit.glsl
// Theme: Degraded VHS tape + CRT monitor effect
// A trashed VHS tape played through a dying CRT — tracking errors, color bleed,
// static bursts, tape dropouts, and barrel distortion.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — the tape skips. A cursor jump of 2+ cells throws a tracking
//            error across the row it lands on for ~300 ms: horizontal tear,
//            chroma smear and white static.
//   focus  — unfocused is PAUSE: the picture dims and desaturates and the
//            head-switching noise bars creep in at the top and bottom.
//            Regaining focus is PLAY: the frame rolls back into lock over
//            half a second.
//
// Setup:
//   1. Save to ~/.config/ghostty/shaders/dip-shit.glsl
//   2. Add to Ghostty config:
//        theme = dip-shit
//        custom-shader = ~/.config/ghostty/shaders/dip-shit.glsl
//        custom-shader-animation = true
//   3. Reload with Cmd+Shift+, or restart Ghostty.
//
// ========== TUNABLE PARAMETERS ==========
//
// CRT_CURVE:    Screen curvature. 0.0 = flat, 0.04 = strong bend.
#define CRT_CURVE     0.02
//
// BRIGHTNESS:   Overall brightness multiplier.
#define BRIGHTNESS    1.8
//
// DISTORTION:   Wobble, jitter, tracking band, frame jump, static burst.
//               0.0 = clean signal, 1.0 = normal, 2.0 = heavy.
#define DISTORTION    1.0
//
// TAPE_WEAR:    Grain, noise, dropout, head-switch, warm shift.
//               0.0 = pristine tape, 1.0 = normal, 2.0 = trashed.
#define TAPE_WEAR     1.75
//
// COLOR_BLEED:  Chroma smearing. 0.0 = perfect color, 1.0 = normal, 2.0 = heavy.
#define COLOR_BLEED   2.0
//
// VIGNETTE:     Corner darkening. 0.0 = none, 0.3 = light, 0.8 = heavy.
#define VIGNETTE      0.35
//
// STATIC:       Persistent white static flecks. 0.0 = none, 0.5 = subtle, 1.0 = normal.
#define STATIC        0.9
//
// =========================================

float hash(vec2 p) {
    p = fract(p * vec2(443.8975, 397.2973));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // --- Interaction state ---
    float focused   = float(iFocus > 0);
    float focusAge  = iTime - iTimeFocus;
    vec2  curC      = cursorCenter(iCurrentCursor);
    vec2  prevC     = cursorCenter(iPreviousCursor);
    float cell      = max(max(iCurrentCursor.z, iCurrentCursor.w), 4.0);
    float moveAge   = iTime - iTimeCursorChange;
    // move measured in columns/rows (a bar cursor's z is only the bar width
    // and an underline's w only its thickness, so each axis has a fallback)
    vec2  cellWH    = vec2(iCurrentCursor.z > 4.0 ? iCurrentCursor.z : max(iCurrentCursor.w * 0.5, 2.0),
                           max(max(iCurrentCursor.w, iCurrentCursor.z * 2.0), 4.0));
    float moveCells = length((curC - prevC) / cellWH);
    float jumpGate  = step(0.5, iPreviousCursor.w) * smoothstep(1.2, 3.0, moveCells);
    float paused    = 1.0 - focused;
    // tape skip: tracking error on the cursor's new row, decaying over 0.3 s
    float skip = smoothstep(cell * 1.6, cell * 0.5, abs(fragCoord.y - curC.y))
               * smoothstep(0.3, 0.0, moveAge) * jumpGate;
    // PLAY: vertical roll that locks back in over ~0.5 s
    float roll = focused * exp(-focusAge * 6.0) * 0.3 * step(focusAge, 1.0);

    // CRT barrel distortion
    vec2 cc = uv - 0.5;
    vec2 wuv = clamp(uv + cc * (dot(cc, cc) * CRT_CURVE), 0.0, 1.0);

    // --- Signal distortion ---

    wuv.x += (sin(wuv.y * 40.0 + iTime * 0.5) * 0.000375
            + sin(wuv.y * 80.0 + iTime * 0.2) * 0.0001875
            + (hash(vec2(floor(fragCoord.y), floor(iTime * 20.0))) - 0.5) * 0.0006) * DISTORTION;

    // Tracking band
    float tracking_y = fract(iTime * 0.04);
    float band = smoothstep(0.05, 0.0, min(abs(wuv.y - tracking_y), 1.0 - abs(wuv.y - tracking_y)));
    float h_offset = band * (hash(vec2(floor(fragCoord.y * 0.5), iTime * 3.0)) - 0.5) * 0.006 * DISTORTION;
    // the skip tears harder than the ambient tracking band
    h_offset += skip * (hash(vec2(floor(fragCoord.y), floor(iTime * 60.0))) - 0.5) * 0.03;

    // Static burst (5s window every ~30s)
    float burst_cycle = floor(iTime / 30.0);
    float burst_start = hash(vec2(burst_cycle, 88.0)) * 25.0;
    float burst_time = mod(iTime, 30.0);
    bool burst_active = burst_time > burst_start && burst_time < burst_start + 5.0;

    // Frame jump (burst-only)
    float jump_seed = floor(iTime * 2.0);
    float jump_offset = burst_active ? (hash(vec2(jump_seed, 11.3)) - 0.5) * 0.08 * DISTORTION : 0.0;

    vec2 sample_uv = fract(wuv + vec2(h_offset, jump_offset + roll));

    // --- Color sampling (5 texture fetches) ---

    float aberr = (0.0003 + band * 0.0015 + skip * 0.004) * COLOR_BLEED;
    vec3 color;
    color.r = texture(iChannel0, sample_uv + vec2(aberr, 0.0)).r;
    color.g = texture(iChannel0, sample_uv).g;
    color.b = texture(iChannel0, sample_uv - vec2(aberr, 0.0)).b;

    // Rightward-only neighborhood (VHS only smears right)
    float px = 1.0 / iResolution.x;
    vec3 s_r1 = texture(iChannel0, sample_uv + vec2(px, 0.0)).rgb;
    vec3 s_r2 = texture(iChannel0, sample_uv + vec2(px * 3.0, 0.0)).rgb;

    // Color bleed
    vec3 nb = s_r1 * 0.4 + s_r2 * 0.6;
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = luma + mix(color - luma, nb - dot(nb, vec3(0.299, 0.587, 0.114)), 0.5 * COLOR_BLEED);

    // skip static: white flecks in the torn row
    if (skip > 0.001) {
        float sn = hash(vec2(floor(fragCoord.x / 3.0), floor(fragCoord.y) + floor(iTime * 90.0)));
        color = mix(color, vec3(1.0), step(0.8, sn) * skip * 0.6);
    }

    // --- Tape artifacts ---

    if (burst_active) {
        float bm = smoothstep(0.7, 0.95, wuv.y);
        if (bm > 0.0) {
            float t = fract(iTime * 43.0);
            float pull = (hash(vec2(floor(fragCoord.y), t * 100.0)) - 0.5) * 0.02 * DISTORTION;
            vec2 sc = vec2(floor((fragCoord.x + pull * iResolution.x) / 10.0), fragCoord.y);
            color = mix(color, vec3(1.0), step(0.93, fract(sin(dot(sc, vec2(12.9898 + t, 78.233 + t))) * 43758.5453)) * bm * 0.4 * DISTORTION);
        }
    }

    if (jump_offset == 0.0 && wuv.y > 0.97) {
        float hs = smoothstep(0.98, 1.0, wuv.y);
        color += hs * (hash(vec2(fragCoord.x, floor(iTime * 15.0))) * 2.0 - 1.0) * 0.15 * TAPE_WEAR;
    }

    float dr = floor(fragCoord.y / 3.0), dt = floor(iTime * 10.0);
    if (hash(vec2(dr, dt)) > 1.0 - 0.003 * TAPE_WEAR) {
        float dx = hash(vec2(dr, dt + 1.0));
        if (wuv.x > dx && wuv.x < dx + hash(vec2(dr, dt + 2.0)) * 0.15)
            color = mix(color, vec3(1.0), 0.05 * TAPE_WEAR);
    }

    // --- PAUSE: dim, desaturate, head-switching bars top and bottom ---
    if (paused > 0.5) {
        float g = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(color, vec3(g), 0.45) * 0.6;
        float bars = smoothstep(0.07, 0.0, wuv.y) + smoothstep(0.93, 1.0, wuv.y);
        float bn = hash(vec2(floor(fragCoord.x / 2.0) + floor(iTime * 30.0), floor(fragCoord.y / 2.0)));
        color = mix(color, vec3(bn * 0.5), bars * 0.75);
    }

    // --- Post-processing ---

    color *= BRIGHTNESS;

    float tg = fract(iTime);
    float cn1 = hash(fragCoord.xy + tg * 100.0) - 0.5;
    float cn2 = hash(fragCoord.xy + tg * 200.0) - 0.5;
    float gl = dot(color, vec3(0.299, 0.587, 0.114));
    color += (color - gl) * vec3(cn1, cn2, -cn1) * 0.15 * TAPE_WEAR;
    color += cn1 * 0.05 * TAPE_WEAR;
    color *= mix(vec3(1.0), vec3(1.03, 1.01, 0.96), TAPE_WEAR);

    vec2 vig = uv * (1.0 - uv);
    color *= mix(1.0, clamp((jump_offset != 0.0) ? vig.x * 4.0 : vig.x * vig.y * 15.0, 0.0, 1.0), VIGNETTE);

    float st = fract(iTime * 20.0);
    color = mix(color, vec3(1.0), step(1.0 - 0.001 * STATIC, hash(vec2(floor(fragCoord.x / 10.0), floor(fragCoord.y / 2.0) + st * 500.0) + st * 77.0)) * 0.15 * STATIC);

    fragColor = vec4(color, 1.0);
}
