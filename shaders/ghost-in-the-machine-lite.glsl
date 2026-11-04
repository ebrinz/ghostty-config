// ghost-in-the-machine-lite.glsl
// Lite variant: ectoplasmic vapor (3-octave, no domain warp) + matrix
// code-rain only. Drops the geodesic lattice and Snow Crash burst.
// Interaction: ecto aura on the cursor, ectoplasm wake on jumps of 2+ cells;
// unfocused, the code-rain stops and the room dims.
// The trickster: a soft Gaussian figure of denser churning ectoplasm,
// every ~41 s, fading as the cursor approaches; watches when unfocused.

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

// ---------------------------------------------------------------------------
// The trickster. No geometry: a soft field of Gaussians (head, shoulders, a
// torso tattering into wisps) warped by the vapor. Where it stands the
// ectoplasm gathers into a denser, slowly churning mass. No outline, no rim.
// ---------------------------------------------------------------------------

// Manifestation schedule from the clock alone. Returns
// (amplitude 0..1, dissipating 0..1, eyes 0..1, cycle index).
const float GHOST_CYCLE = 41.0;
vec4 ghostCycle(float t) {
    float c  = floor(t / GHOST_CYCLE);
    float ph = fract(t / GHOST_CYCLE);
    float goes = step(0.30, hash21(vec2(c, 77.0)));
    float env  = smoothstep(0.55, 0.65, ph) * (1.0 - smoothstep(0.82, 0.90, ph));
    float diss = smoothstep(0.80, 0.86, ph) * (1.0 - smoothstep(0.86, 0.92, ph));
    // one glimpse of the eyes mid-linger, two quick blinks
    float g1 = smoothstep(0.715, 0.720, ph) * (1.0 - smoothstep(0.728, 0.733, ph));
    float g2 = smoothstep(0.740, 0.745, ph) * (1.0 - smoothstep(0.753, 0.758, ph));
    return vec4(env * goes, diss * goes, (g1 + g2) * goes, c);
}

// Where it stands this cycle, in uv, with a slow sway.
vec2 ghostCenter(float c, float t) {
    vec2 base = vec2(mix(0.20, 0.80, hash21(vec2(c, 3.0))), mix(0.30, 0.65, hash21(vec2(c, 5.0))));
    return base + vec2(sin(t * 0.30 + c) * 0.010, sin(t * 0.21 + c * 2.0) * 0.006);
}

// The presence field at square-space point q. S is the figure's half-height.
// Returns (body 0..1, rim 0..1, eyes 0..1).
vec3 ghostField(vec2 q, vec2 c, float S, float t) {
    vec2 p = (q - c) / S;
    // the vapor warps the outline so it never holds a hard shape
    vec2 warp = vec2(noise(p * 2.5 + vec2(t * 0.17, 0.0)), noise(p * 2.5 + vec2(3.7, t * 0.13))) - 0.5;
    p += warp * 0.18;
    float head = exp(-dot(p - vec2(0.0, -0.95), p - vec2(0.0, -0.95)) / (0.22 * 0.22));
    vec2 sh = (p - vec2(0.0, -0.45)) / vec2(0.50, 0.35);
    float shoulders = exp(-dot(sh, sh));
    vec2 to = (p - vec2(0.0, 0.10)) / vec2(0.42, 0.60);
    float torso = exp(-dot(to, to)) * smoothstep(0.95, -0.2, p.y);
    float f = clamp(head + shoulders + torso, 0.0, 1.0);
    // the hem tatters into the mist
    float hem = mix(1.0, noise(p * 4.0 - vec2(0.0, t * 0.4)), smoothstep(-0.2, 0.9, p.y));
    f *= mix(0.6, 1.0, hem);
    // no edge: a wide soft falloff, so the mass has no outline
    float body = smoothstep(0.10, 0.90, f);
    vec2 eL = p - vec2(-0.075, -0.97), eR = p - vec2(0.075, -0.97);
    float eyes = exp(-dot(eL, eL) / (0.035 * 0.035)) + exp(-dot(eR, eR) / (0.035 * 0.035));
    return vec3(body, 0.0, min(eyes, 1.0));
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

    // --- The trickster's presence ---
    vec4 gc = ghostCycle(time);
    vec2 gCenterUV = ghostCenter(gc.w, time);
    vec2 gC = vec2(gCenterUV.x * aspect, gCenterUV.y);
    float gS = 0.22;
    vec3 gf = ghostField(vec2(uv.x * aspect, uv.y), gC, gS, time);
    float approach = 1.0 - smoothstep(cell * 6.0, cell * 16.0, length(curC - gCenterUV * iResolution.xy));
    float presence = (1.0 - approach) * (1.0 - 0.6 * smoothstep(1.2, 0.0, moveAge));
    float amp = max(max(gc.x * presence * focused, 1.0 - focused), (1.0 - smoothstep(0.0, 1.5, focusAge)) * focused);
    float ghostBody = gf.x * amp;
    float watch = max(1.0 - focused, (1.0 - smoothstep(0.0, 1.5, focusAge)) * focused);
    float eyesOn = max(gc.z * presence * focused, watch) * gf.z;

    // --- Ectoplasmic vapor: slow-drifting mist ---
    vec2 fp = uv * vec2(aspect, 1.0) * 2.5;
    float vapor = fbm(fp + vec2(time * 0.04, time * 0.02));
    vapor = pow(vapor, 1.5);
    color += mix(DEEP, ECTO * 0.45, vapor) * 0.12;
    // the trickster: ectoplasm gathering into a denser, slowly churning mass
    float churn = fbm(fp * 1.6 + vec2(time * 0.06, -time * 0.05));
    float mass = ghostBody * mix(0.45, 1.0, churn);
    color += mix(ECTO * 0.35, ECTO, churn) * mass * (0.10 + 0.22 * churn);
    color += vec3(1.000, 0.373, 0.824) * eyesOn * 0.55;
    const vec3 MAGENTA = vec3(1.000, 0.373, 0.824);
    // departiculization: as it lets go — at the end of a visit, or when you
    // return focus — the mass breaks into magenta motes that lift, scatter
    // and wink out. Each cell/3 block is one mote; its brightness comes from
    // sampling the body where the mote started, so only the mass breaks up.
    float cycPh  = fract(time / GHOST_CYCLE);
    float cycT   = clamp((cycPh - 0.80) / 0.12, 0.0, 1.0);
    float cycOn  = step(0.001, gc.y) * focused;
    float focT   = clamp(focusAge / 1.5, 0.0, 1.0);
    float focOn  = step(focusAge, 1.5) * focused;
    float fadeT  = (cycOn > 0.5) ? cycT : focT;
    float fadeOn = max(cycOn, focOn) * presence;
    if (fadeOn > 0.001 && fadeT < 1.0) {
        float blk = max(cell / 3.0, 3.0);
        vec2 pb = floor(fragCoord / blk);
        float h1 = hash21(pb + 11.0), h2 = hash21(pb + 23.0);
        float flight = fadeT * (0.6 + 0.8 * h1);                                // staggered take-off
        vec2 lift = vec2((h2 - 0.5) * 0.10, 0.14) * flight;                      // up and outward (y down)
        vec2 qb = ((pb + 0.5) * blk) / iResolution.y;                            // block centre, square-space
        float born = ghostField(qb + lift, gC, gS, time).x;                      // was this mote part of the mass?
        float dot2 = smoothstep(0.5, 0.15, length(fract(fragCoord / blk) - 0.5));
        float wink = step(0.55, h1) * step(0.5, hash21(pb + floor(time * 18.0)));  // sparse, twinkling
        float mote = born * dot2 * wink * (1.0 - flight) * fadeOn;
        color += mix(MAGENTA, vec3(1.0, 0.8, 0.95), 0.3) * mote * 0.85;
    }

    // --- Matrix code-rain: sparse glyph-blocky streaks ---
    float colId = floor(uv.x * 80.0);
    float colRand = hash21(vec2(colId, 3.7));
    float gate = step(0.72, colRand);
    float speed = 0.25 + colRand * 0.6;
    float phase = fract(uv.y + time * speed + colRand);   // the rain rises (by choice)
    float streak = smoothstep(0.0, 0.05, phase) * smoothstep(0.45, 0.0, phase);
    float rowId = floor(uv.y * 45.0);
    float glyph = step(0.4, hash21(vec2(colId, rowId) + floor(time * (6.0 + 18.0 * ghostBody))));  // flickers faster through the trickster
    streak *= (0.45 + 0.55 * glyph) * gate * focused;
    color += mix(PHOS, vec3(1.000, 0.373, 0.824) * 0.6, ghostBody * 0.5) * streak * 0.16;

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
