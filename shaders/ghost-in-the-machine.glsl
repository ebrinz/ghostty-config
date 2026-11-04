// ghost-in-the-machine.glsl
// Spectral ectoplasm drifting through a jittering Fuller geodesic lattice,
// sparse matrix code-rain, and a rare magenta Snow Crash glitch burst.
// Ecto-green leads; magenta is the neon twang. Luma text guard keeps
// glyphs crisp. Single-pass Ghostty fragment shader.
//
// The trickster: every ~41 s, most cycles, a figure condenses somewhere in
// the lattice — not drawn, but a soft Gaussian field where the ectoplasm
// gathers into a churning mass, the lattice nodes brighten and tremble and
// the rain flickers faster. It fades as the cursor approaches, shies while you type,
// glimpses its magenta eyes once per visit, and when the window loses focus
// it comes out fully and watches until you return.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor  — the ghost. An ectoplasm wake trails the cursor on jumps of
//             2+ cells, and the landing cell tears with a magenta glitch.
//             A faint ecto aura breathes around the resting cursor.
//   focus   — unfocused, the séance goes still: lattice tremor stops, the
//             code-rain and glitch bursts stop, the room dims. Regaining
//             focus fires a Snow Crash burst at the cursor's row.

const float PI = 3.14159265359;

// --- Palette -----------------------------------------------------------------
const vec3 ECTO    = vec3(0.490, 1.000, 0.769); // #7dffc4 spectral green
const vec3 PHOS    = vec3(0.302, 0.902, 0.596); // #4de698 matrix phosphor
const vec3 MAGENTA = vec3(1.000, 0.373, 0.824); // #ff5fd2 Snow Crash neon
const vec3 DEEP    = vec3(0.024, 0.039, 0.035); // #060a09 near-black green

// ---------------------------------------------------------------------------
// Hash / noise
// ---------------------------------------------------------------------------
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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

// ---------------------------------------------------------------------------
// Geodesic lattice — triangulated mesh with nervously jittering vertices.
// Returns (edge intensity, vertex-node intensity).
// ---------------------------------------------------------------------------
float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

vec2 jitterVert(vec2 v, float t, float agit) {
    float h1 = hash21(v);
    float h2 = hash21(v + 31.7);
    // slow drift plus a fast nervous tremor, both per-vertex; `agit` scales
    // the tremor (the lattice shakes where the trickster stands)
    vec2 drift  = vec2(sin(t * (0.6 + h1) + h1 * 2.0 * PI),
                       cos(t * (0.7 + h2) + h2 * 2.0 * PI)) * 0.06;
    vec2 tremor = vec2(sin(t * (5.0 + h2 * 3.0)),
                       cos(t * (4.3 + h1 * 3.0))) * 0.015 * agit;
    return drift + tremor;
}

vec2 geodesicLattice(vec2 uv, float aspect, float t, float agit) {
    vec2 p = uv * vec2(aspect, 1.0) * 6.0;
    // skew world -> triangular lattice coords (basis e1=(1,0), e2=(0.5,0.866))
    mat2 toTri = mat2(1.0, 0.0, -0.57735, 1.15470);
    mat2 fromTri = mat2(1.0, 0.0, 0.5, 0.866025);
    vec2 g = toTri * p;
    vec2 gi = floor(g);
    vec2 gf = fract(g);
    float upper = step(1.0, gf.x + gf.y);
    vec2 v0 = gi + vec2(upper, upper);
    vec2 v1 = gi + vec2(1.0, 0.0);
    vec2 v2 = gi + vec2(0.0, 1.0);
    vec2 w0 = fromTri * v0 + jitterVert(v0, t, agit);
    vec2 w1 = fromTri * v1 + jitterVert(v1, t, agit);
    vec2 w2 = fromTri * v2 + jitterVert(v2, t, agit);
    float d = min(segDist(p, w0, w1), min(segDist(p, w1, w2), segDist(p, w2, w0)));
    float edge = smoothstep(0.025, 0.0, d);
    float nd = min(length(p - w0), min(length(p - w1), length(p - w2)));
    float node = smoothstep(0.06, 0.0, nd);
    return vec2(edge, node);
}

// ---------------------------------------------------------------------------
// The trickster. No geometry: a soft field of Gaussians (head, shoulders, a
// torso tattering into wisps) warped by the vapor. Where it stands the
// ectoplasm gathers into a denser, slowly churning mass; the lattice trembles
// and the rain flickers. No outline, no rim: only vapor.
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

// ---------------------------------------------------------------------------
// Interaction helpers
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge of the cursor
// in fragCoord pixels, zw = size. Ghostty keeps the +Y edge convention
// consistent with fragCoord on every backend, so this needs no y-flip.
// ---------------------------------------------------------------------------
vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// Ectoplasm wake: head glides prev -> cur with ease-out, body thins and
// dissolves behind it. Returns intensity 0..1 at pixel p.
float ectoWake(vec2 p, vec2 a, vec2 b, float age, float cell, float t) {
    const float DUR = 0.55;
    float k = clamp(age / DUR, 0.0, 1.0);
    float ease = 1.0 - pow(1.0 - k, 3.0);
    vec2 head = mix(a, b, ease);
    float d = segDist(p, a, head);
    vec2 ab = head - a;
    float along = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    // wake is wide at the head, tapers toward the tail
    float width = cell * mix(0.25, 0.75, along);
    float body = smoothstep(width, 0.0, d);
    // vapor break-up so the wake dissolves instead of fading uniformly
    float wisp = noise(p / cell * 1.5 + vec2(t * 2.0, -t * 1.5));
    body *= mix(0.4, 1.0, wisp);
    return body * (1.0 - k) * mix(0.35, 1.0, along);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float time = iTime;

    // --- Text detection: protect bright glyphs from any overlay ---
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.14, luma);

    vec3 color = clean.rgb;

    // --- Interaction state ---
    float focused   = float(iFocus > 0);
    float focusAge  = iTime - iTimeFocus;                 // s since focus gained
    vec2  curC      = cursorCenter(iCurrentCursor);
    vec2  prevC     = cursorCenter(iPreviousCursor);
    float cell      = max(max(iCurrentCursor.z, iCurrentCursor.w), 4.0);
    float moveAge   = iTime - iTimeCursorChange;
    // move measured in columns/rows (a bar cursor's z is only the bar width
    // and an underline's w only its thickness, so each axis has a fallback)
    vec2  cellWH    = vec2(iCurrentCursor.z > 4.0 ? iCurrentCursor.z : max(iCurrentCursor.w * 0.5, 2.0),
                           max(max(iCurrentCursor.w, iCurrentCursor.z * 2.0), 4.0));
    float moveCells = length((curC - prevC) / cellWH);
    float hasPrev   = step(0.5, iPreviousCursor.w);       // 0 until first move
    float jumpGate  = hasPrev * smoothstep(1.2, 3.0, moveCells);
    float cursorD   = length(fragCoord - curC) / cell;    // distance in cells
    // unfocused: the séance goes still
    float still     = 1.0 - focused;

    // --- The trickster's presence ---
    vec4 gc = ghostCycle(time);
    vec2 gCenterUV = ghostCenter(gc.w, time);
    vec2 q = vec2(uv.x * aspect, uv.y);
    vec2 gC = vec2(gCenterUV.x * aspect, gCenterUV.y);
    float gS = 0.22 * (1.0 + 0.03 * sin(time * 0.9));                 // half-height, breathing
    vec3 gf = ghostField(q, gC, gS, time);
    // it fades as the cursor approaches, and shies while you type
    vec2 gCenterPx = gCenterUV * iResolution.xy;
    float approach = 1.0 - smoothstep(cell * 6.0, cell * 16.0, length(curC - gCenterPx));
    float typing = smoothstep(1.2, 0.0, moveAge);
    float presence = (1.0 - approach) * (1.0 - 0.6 * typing);
    float amp = gc.x * presence * focused;
    // unfocused it comes out fully and watches; dissolves 1.5 s after you return
    amp = max(amp, still);
    amp = max(amp, (1.0 - smoothstep(0.0, 1.5, focusAge)) * focused);
    float ghostBody = gf.x * amp;
    // the eyes dissolve with the body after focus returns
    float watch = max(still, (1.0 - smoothstep(0.0, 1.5, focusAge)) * focused);
    float eyesOn = max(gc.z * presence * focused, watch) * gf.z;

    // -----------------------------------------------------------------------
    // Layer 1 — Ectoplasmic vapor: domain-warped fbm mist that curls.
    // -----------------------------------------------------------------------
    vec2 fp = uv * vec2(aspect, 1.0) * 2.5;
    vec2 warp = vec2(fbm(fp + time * 0.04),
                     fbm(fp + vec2(5.2, 1.3) - time * 0.03));
    float vapor = fbm(fp + 1.8 * warp + vec2(0.0, time * 0.02));
    vapor = pow(vapor, 1.5);
    color += mix(DEEP, ECTO * 0.45, vapor) * 0.12;
    // the trickster: ectoplasm gathering into a denser, slowly churning mass
    float churn = fbm(fp * 1.6 + 2.2 * warp + vec2(time * 0.06, -time * 0.05));
    float mass = ghostBody * mix(0.45, 1.0, churn);                   // ragged, never an edge
    color += mix(ECTO * 0.35, ECTO, churn) * mass * (0.10 + 0.22 * churn);

    // -----------------------------------------------------------------------
    // Layer 2 — Geodesic lattice: faint jittering mesh, brighter nodes.
    // -----------------------------------------------------------------------
    // unfocused, the lattice freezes mid-tremor (time held at the focus-loss
    // frame is unavailable, so hold it on a slow clock instead)
    // the lattice trembles harder and its nodes burn brighter where it stands
    float agit = 1.0 + 3.0 * ghostBody;
    vec2 lat = geodesicLattice(uv, aspect, mix(time, floor(time * 0.5) * 2.0, still), agit);
    color += ECTO * lat.x * 0.07 * (1.0 + 0.8 * ghostBody);
    color += ECTO * lat.y * 0.18 * (1.0 + 2.5 * ghostBody);

    // -----------------------------------------------------------------------
    // Layer 3 — Matrix code-rain: sparse columns of glyph-blocky streaks.
    // -----------------------------------------------------------------------
    float colId = floor(uv.x * 80.0);
    float colRand = hash21(vec2(colId, 3.7));
    float gate = step(0.72, colRand); // only some columns rain
    float speed = 0.25 + colRand * 0.6;
    float phase = fract(uv.y + time * speed + colRand);   // the rain rises (by choice)
    float streak = smoothstep(0.0, 0.05, phase) * smoothstep(0.45, 0.0, phase);
    // glyph flicker: cells wink as the trail passes, like changing characters
    float rowId = floor(uv.y * 45.0);
    float glyph = step(0.4, hash21(vec2(colId, rowId) + floor(time * (6.0 + 18.0 * ghostBody))));
    streak *= (0.45 + 0.55 * glyph) * gate * focused;
    color += mix(PHOS, MAGENTA * 0.6, ghostBody * 0.5) * streak * 0.16;

    // the eyes: two faint magenta embers, glimpsed
    color += MAGENTA * eyesOn * 0.55;
    // dissipation: a faint magenta static shimmer as it lets go
    float shimmer = hash21(floor(fragCoord / 2.0) + floor(time * 40.0));
    color += MAGENTA * gf.x * gc.y * presence * focused * step(0.85, shimmer) * 0.25;
    // bright head at the leading edge of each trail
    float head = smoothstep(0.05, 0.0, phase) * gate * glyph * focused;
    color += vec3(0.85, 1.0, 0.92) * head * 0.22;

    // -----------------------------------------------------------------------
    // Layer 3b — The ghost: ecto aura on the resting cursor, ectoplasm wake
    // on jumps, magenta tear where it lands.
    // -----------------------------------------------------------------------
    float breath = 0.75 + 0.25 * sin(time * 1.7);
    float aura = exp(-cursorD * 1.6) * breath * focused;
    color += ECTO * aura * 0.22;

    float wake = ectoWake(fragCoord, prevC, curC, moveAge, cell, time) * jumpGate;
    color += mix(ECTO, vec3(0.85, 1.0, 0.92), wake) * wake * 0.55;

    // landing tear: a one-cell-tall band through the new cursor row that
    // resamples the frame sideways for ~180 ms
    float land = smoothstep(0.18, 0.0, moveAge) * jumpGate;
    if (land > 0.001) {
        float rowBand = smoothstep(cell * 0.9, cell * 0.3, abs(fragCoord.y - curC.y));
        float near = smoothstep(cell * 14.0, 0.0, abs(fragCoord.x - curC.x));
        float tear = rowBand * near * land;
        float sn = hash21(vec2(floor(fragCoord.y), floor(time * 60.0)));
        vec3 torn = texture(iChannel0, uv + vec2((sn - 0.5) * 0.015 * tear, 0.0)).rgb;
        color = mix(color, torn, tear * 0.7);
        color += MAGENTA * tear * sn * 0.5;
    }

    // -----------------------------------------------------------------------
    // Layer 4 — Snow Crash burst: rare magenta static band with glitch offset.
    // -----------------------------------------------------------------------
    const float CYCLE = 13.0;
    float ct = mod(time, CYCLE);
    float burst = smoothstep(0.0, 0.06, ct) * smoothstep(0.55, 0.30, ct) * focused;
    float bandY = hash21(vec2(floor(time / CYCLE), 2.0)) * 0.8 + 0.1;
    // focus gain: the machine notices you — a burst rides the cursor's row
    float fburst = smoothstep(0.0, 0.05, focusAge) * smoothstep(0.7, 0.25, focusAge) * focused;
    if (fburst > burst) {
        burst = fburst;
        bandY = curC.y / iResolution.y;
    }
    if (burst > 0.001) {
        float band = smoothstep(0.05, 0.0, abs(uv.y - bandY));
        float staticN = hash21(vec2(floor(uv.y * 300.0), floor(time * 60.0)));
        // chromatic tear: resample the frame shifted sideways inside the band
        float shift = (staticN - 0.5) * 0.02 * band * burst;
        vec3 torn = texture(iChannel0, uv + vec2(shift, 0.0)).rgb;
        color = mix(color, torn, band * burst * 0.6);
        color += MAGENTA * band * burst * staticN * 0.35;
    }

    // -----------------------------------------------------------------------
    // Layer 5 — Vignette: sink the periphery into black-green.
    // -----------------------------------------------------------------------
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * 1.1;
    color *= clamp(vig, 0.0, 1.0);

    // --- Focus: unfocused window sinks further into the dark ---
    color *= mix(1.0, 0.62, still);

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
