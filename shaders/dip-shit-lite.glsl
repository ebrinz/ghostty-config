// dip-shit-lite.glsl
// Theme: Degraded VHS tape + CRT monitor — lightweight variant
// Static CRT look without time-based animation. Keeps barrel distortion,
// scanlines, color bleed, vignette, and static grain but no wobble,
// tracking bands, bursts, or tape artifacts.
// Interaction: a cursor jump of 2+ cells skips the tape (tracking tear on
// that row for ~300 ms); unfocused is PAUSE (dim, desaturated, noise bars);
// focus gain rolls the frame back into lock.
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
    float cursorD   = length(fragCoord - curC) / cell;
    float paused    = 1.0 - focused;
    float skip = smoothstep(cell * 1.6, cell * 0.5, abs(fragCoord.y - curC.y))
               * smoothstep(0.3, 0.0, moveAge) * jumpGate;
    float roll = focused * exp(-focusAge * 6.0) * 0.3 * step(focusAge, 1.0);

    // CRT barrel distortion
    vec2 cc = uv - 0.5;
    vec2 wuv = clamp(uv + cc * (dot(cc, cc) * CRT_CURVE), 0.0, 1.0);
    // tape skip tear on the cursor's row, PLAY roll on focus gain
    wuv.x += skip * (hash(vec2(floor(fragCoord.y), floor(iTime * 60.0))) - 0.5) * 0.03;
    wuv.y = fract(wuv.y + roll);

    // --- Color sampling with chromatic aberration ---

    float aberr = (0.0003 + skip * 0.004) * COLOR_BLEED;
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

    // skip static: white flecks in the torn row
    if (skip > 0.001) {
        float sn = hash(vec2(floor(fragCoord.x / 3.0), floor(fragCoord.y) + floor(iTime * 90.0)));
        color = mix(color, vec3(1.0), step(0.8, sn) * skip * 0.6);
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
