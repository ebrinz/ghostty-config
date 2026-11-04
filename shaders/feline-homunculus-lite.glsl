// feline-homunculus-lite.glsl
// Lite variant: single-layer rain only.
// Drops: neon bleed, pavement reflections, bottom glow (7 noise calls removed).
// Effects: rain streaks (1 layer), vignette, 40Hz gamma entrainment, text protection.
// Interaction: amber lantern glow on the cursor with a light streak on jumps
// of 2+ cells; unfocused, the alley goes cold and blue.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// ---------------------------------------------------------------------------
// Noise utilities
// ---------------------------------------------------------------------------

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// ---------------------------------------------------------------------------
// Rain streak function — single layer only (foreground rain)
// ---------------------------------------------------------------------------

float rainStreak(vec2 uv, float time) {
    float rain = 0.0;

    // Single foreground layer only (lite: dropped far rain layer)
    float scale = 14.0;
    float speed = 1.4;

    vec2 st = uv * scale;
    st.y += time * speed * scale;

    vec2 cell = floor(st);
    vec2 local = fract(st);

    float cellHash = hash21(cell);
    if (cellHash < 0.65) return 0.0;

    float xOff = hash21(cell + 0.5);

    float wind = sin(cell.y * 0.8 + time * 2.0 + xOff * 6.28);
    float wobbleHead = wind * 0.08;
    float wobbleTail = wind * 0.16;
    float wobble = mix(wobbleTail, wobbleHead, smoothstep(0.0, 0.8, local.y));

    float dropX = fract(xOff + wobble);

    float taper = 0.3 + 0.7 * smoothstep(0.0, 0.7, local.y);
    float dx = abs(local.x - dropX);
    float baseWidth = 0.018;
    float lineWidth = (baseWidth + 0.01 * hash21(cell + 99.0)) * taper;
    float streak = smoothstep(lineWidth, 0.0, dx);

    float trail = pow(smoothstep(0.0, 0.85, local.y), 1.8);
    float headCap = smoothstep(1.0, 0.93, local.y);
    streak *= trail * headCap;

    return clamp(streak, 0.0, 1.0);
}

// --- Interaction helpers (Ghostty 1.4 uniforms) ---
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// Comet trail: head glides prev -> cur with ease-out, tail fades over 0.5 s.
float cometTrail(vec2 p, vec2 a, vec2 b, float age, float cell) {
    const float DUR = 0.5;
    float k = clamp(age / DUR, 0.0, 1.0);
    vec2 head = mix(a, b, 1.0 - pow(1.0 - k, 3.0));
    vec2 ab = head - a;
    float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    float d = length(p - a - ab * h);
    return smoothstep(cell * mix(0.25, 0.6, h), 0.0, d) * (1.0 - k) * mix(0.3, 1.0, h);
}

// ---------------------------------------------------------------------------
// Main image
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Text detection ---
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

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

    // --- Layer 1: Rain Streaks (single layer) ---
    float rain = rainStreak(uv, time);
    vec3 rainColor = vec3(0.6, 0.75, 0.9);
    color += rainColor * rain * 0.18;

    // --- The lantern: amber glow on the cursor, light streak on jumps ---
    vec3 lanternColor = vec3(0.93, 0.56, 0.11);
    float lamp = exp(-cursorD * 1.5);
    color += lanternColor * lamp * 0.22 * mix(0.4, 1.0, focused);
    float streak = cometTrail(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += mix(lanternColor, vec3(1.0, 0.95, 0.85), streak) * streak * 0.6;

    // --- Layer 4: Asymmetric Vignette ---
    vec2 vignetteCenter = vec2(0.55, 0.45);
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.8, 0.35, vignetteDist);
    vignette = mix(0.3, 1.0, vignette);
    color *= vignette;

    // --- Focus: unfocused, the alley goes cold — toward blue, dimmer ---
    float cold = 1.0 - focused;
    float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(color, mix(vec3(gray), vec3(0.45, 0.6, 0.9) * gray, 0.5), cold * 0.6);
    color *= mix(1.0, 0.7, cold);

    // --- Layer 5: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float centerDist = length(uv - vec2(0.5));
    float peripheryWeight = smoothstep(0.15, 0.5, centerDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Layer 6: Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
