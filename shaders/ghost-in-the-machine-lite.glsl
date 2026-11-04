// ghost-in-the-machine-lite.glsl
// Lite variant: ectoplasmic vapor (3-octave, no domain warp) + matrix
// code-rain only. Drops the geodesic lattice and Snow Crash burst.
// Interaction: ecto aura on the cursor, ectoplasm wake on jumps of 2+ cells;
// unfocused, the code-rain stops and the room dims.

const vec3 ECTO = vec3(0.490, 1.000, 0.769); // #7dffc4 spectral green
const vec3 PHOS = vec3(0.302, 0.902, 0.596); // #4de698 matrix phosphor
const vec3 DEEP = vec3(0.024, 0.039, 0.035); // #060a09 near-black green

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float time = iTime;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.14, luma);

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

    // --- Ectoplasmic vapor: slow-drifting mist ---
    vec2 fp = uv * vec2(aspect, 1.0) * 2.5;
    float vapor = fbm(fp + vec2(time * 0.04, time * 0.02));
    vapor = pow(vapor, 1.5);
    color += mix(DEEP, ECTO * 0.45, vapor) * 0.12;

    // --- Matrix code-rain: sparse glyph-blocky streaks ---
    float colId = floor(uv.x * 80.0);
    float colRand = hash21(vec2(colId, 3.7));
    float gate = step(0.72, colRand);
    float speed = 0.25 + colRand * 0.6;
    float phase = fract(uv.y + time * speed + colRand);
    float streak = smoothstep(0.0, 0.05, phase) * smoothstep(0.45, 0.0, phase);
    float rowId = floor(uv.y * 45.0);
    float glyph = step(0.4, hash21(vec2(colId, rowId) + floor(time * 6.0)));
    streak *= (0.45 + 0.55 * glyph) * gate * focused;
    color += PHOS * streak * 0.16;

    // --- The ghost: ecto aura on the cursor, ectoplasm wake on jumps ---
    float aura = exp(-cursorD * 1.6) * (0.75 + 0.25 * sin(time * 1.7)) * focused;
    color += ECTO * aura * 0.22;
    float wake = cometTrail(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += ECTO * wake * 0.5;

    // --- Vignette ---
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * 1.1;
    color *= clamp(vig, 0.0, 1.0);
    color *= mix(0.62, 1.0, focused);   // unfocused: sink into the dark

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
