// street-shaman-lite.glsl
// Lite variant: firelight flicker + bottom glow only.
// Drops: fbm smoke, azure wisps, heat distortion (26 -> 1 noise eval).
// Effects: firelight flicker, bottom glow, vignette, 40Hz gamma entrainment, text protection.
// Interaction: ember glow on the cursor (the candle), green comet on jumps of
// 2+ cells; unfocused, the fire burns down to embers; focus gain flares it.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// --- Noise functions ---

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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

// --- Main ---

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // Sample the clean terminal texture
    vec4 clean = texture(iChannel0, uv);

    // --- Text detection ---
    float luma = dot(clean.rgb, vec3(0.299, 0.587, 0.114));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec4 color = clean;

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
    float embers    = 1.0 - focused;
    float flare     = smoothstep(1.1, 0.05, focusAge) * focused;

    // --- 2. Firelight Flicker + Vignette ---
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vignette = smoothstep(0.78, 0.45, dist);

    float flickerNoise = noise(vec2(time * mix(3.0, 0.8, embers), uv.y * 5.0));
    float flicker = mix(0.6, 1.0, flickerNoise) * mix(1.0, 0.55, embers) + flare * 0.5;

    float edgeFactor = mix(flicker * 0.35, 1.0, vignette);
    color.rgb *= edgeFactor;

    // --- 5. Green ambient glow at bottom edge (fire below) ---
    float bottomGlow = (1.0 - uv.y) * (1.0 - uv.y);
    float glowPulse = 0.5 + 0.5 * sin(time * 1.2);
    vec3 fireGlow = vec3(0.0, 0.12, 0.03) * bottomGlow * mix(0.3, 0.6, glowPulse);
    fireGlow *= mix(1.0, 0.35, embers) + flare * 2.5;
    color.rgb += fireGlow;

    // --- The candle: ember glow on the cursor, comet on jumps ---
    float candle = exp(-cursorD * 1.4) * (0.8 + 0.2 * noise(vec2(time * 6.0, 3.0)));
    color.rgb += vec3(0.0, 1.0, 0.25) * candle * 0.18 * mix(0.35, 1.0, focused);
    float trail = cometTrail(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color.rgb += vec3(0.3, 1.0, 0.4) * trail * 0.6;

    // --- Focus: embers only in the background ---
    color.rgb *= mix(1.0, 0.65, embers);

    // --- 6. 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float gammaModulation = 1.0 + gamma * GAMMA_AMP;
    float gammaZone = smoothstep(0.15, 0.5, dist);
    color.rgb *= mix(1.0, gammaModulation, gammaZone);

    // --- 7. Text Protection ---
    color.rgb = mix(color.rgb, clean.rgb, textMask);

    fragColor = color;
}
