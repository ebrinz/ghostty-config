// electrode-shaper-lite.glsl
// Lite variant: CRT artifacts only, no plasma/arcs/EMF.
// Drops: plasma field, electrode arcs, EMF interference (all noise removed).
// Effects: barrel distortion, chromatic aberration, scanlines, vignette,
//          40Hz gamma entrainment, text protection.
// Interaction: violet corona on the cursor, straight discharge line on jumps
// of 2+ cells; unfocused, the chamber powers down; focus gain surges.
// Scene (lite): the Jacob's ladder as soft light — two conductors and the climbing arc.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// ---------------------------------------------------------------------------
// CRT barrel distortion
// ---------------------------------------------------------------------------

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

// --- Noise (for the arc jag) ---
float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + vec2(1.0, 0.0)), c = hash21(i + vec2(0.0, 1.0)), d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// --- Jacob's ladder helpers (see electrode-shaper.glsl) ---
float segDistQ(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// Rail point for side (-1 left, +1 right) at height h (0 bottom .. 1 top).
vec2 railPoint(float side, float h, float aspect) {
    return vec2(aspect * 0.5 + side * mix(0.035, 0.22, h), mix(0.95, 0.12, h));
}

// Where the ladder arc is in its cycle. Returns (height 0..1, on 0/1, snap flash 0..1).
const float LADDER_T = 3.6;
vec3 ladderPhase(float t) {
    float ph = fract(t / LADDER_T);
    float climbing = step(ph, 0.78);
    float h = pow(ph / 0.78, 1.6);
    float snap = smoothstep(0.78, 0.785, ph) * smoothstep(0.86, 0.80, ph);
    return vec3(min(h, 1.0), climbing, snap);
}

// A jagged arc between a and b, seeded per frame-step so it crackles.
// Returns (core, glow) at p. `amp` is the sideways jag in q units.
vec2 jagArc(vec2 p, vec2 a, vec2 b, float seed, float amp, float pxl) {
    vec2 ab = b - a;
    float len = max(length(ab), 1e-4);
    vec2 dir = ab / len;
    vec2 nrm = vec2(-dir.y, dir.x);
    float along = clamp(dot(p - a, dir), 0.0, len);
    float side = dot(p - a, nrm);
    float u = along / len;
    float jag = (noise(vec2(along * 60.0, seed)) - 0.5) * 2.0
              + (noise(vec2(along * 180.0, seed + 7.0)) - 0.5) * 0.6;
    jag *= amp * sin(u * 3.14159);
    float d = abs(side - jag);
    float core = smoothstep(pxl * 1.8, 0.0, d);
    float glow = smoothstep(amp * 0.9 + 0.01, 0.0, d) * 0.45;
    return vec2(core, glow);
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
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;
    float time = iTime;

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
    float down      = 1.0 - focused;
    float surge     = focused * exp(-focusAge * 4.0) * sin(min(focusAge * 9.0, 3.14159)) * 0.35;

    // --- Layer 1: CRT Screen Artifacts ---

    // Barrel distortion
    float barrelStrength = 0.05;
    vec2 uv = barrelDistort(rawUV, barrelStrength);

    // Chromatic aberration
    vec2 fromCenter = uv - 0.5;
    float edgeDist = length(fromCenter);
    float aberration = edgeDist * 0.003;
    vec2 aberrationDir = normalize(fromCenter + 0.0001);

    float r = texture(iChannel0, uv + aberrationDir * aberration).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - aberrationDir * aberration).b;
    float a = texture(iChannel0, uv).a;

    vec4 clean = vec4(r, g, b, a);
    vec3 color = clean.rgb;

    // Text detection
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // Scanlines (deeper when powered down)
    float scanline = 1.0 - mix(0.15, 0.3, down) * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // --- The electrode: corona on the cursor, discharge on jumps ---
    vec3 violet = vec3(0.56, 0.25, 0.85);
    vec3 hotWhite = vec3(0.9, 0.88, 1.0);
    float corona = exp(-cursorD * 1.8) * (0.7 + 0.3 * sin(time * 9.0));
    color += violet * corona * 0.25 * mix(0.3, 1.0, focused);
    float bolt = cometTrail(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += mix(violet, hotWhite, bolt) * bolt * 0.7;

    // --- The apparatus (lite): soft conductors and the climbing arc ---
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(uv.x * aspect, uv.y);
    float pxl = 1.0 / iResolution.y;
    vec3 plasmaColor = mix(violet, vec3(0.13, 0.72, 0.78), 0.5);
    vec3 conductor = vec3(0.45, 0.76, 0.86);
    vec3 lp = ladderPhase(time);
    for (int sdx = 0; sdx < 2; sdx++) {
        float side = (sdx == 0) ? -1.0 : 1.0;
        float d = segDistQ(q, railPoint(side, 0.0, aspect), railPoint(side, 1.0, aspect));
        color += conductor * exp(-d * 110.0) * 0.25 * mix(0.35, 1.0, focused);
    }
    if (lp.y * focused > 0.5) {
        vec2 a = railPoint(-1.0, lp.x, aspect), b = railPoint(1.0, lp.x, aspect);
        vec2 arcv = jagArc(q, a, b, floor(time * 45.0), mix(0.004, 0.03, lp.x), pxl);
        float energy = mix(0.7, 1.3, lp.x);
        color += mix(hotWhite, plasmaColor, 0.35) * arcv.x * energy * 0.8 + plasmaColor * arcv.y * energy * 1.3;
    }

    // --- Layer 5: Vignette ---
    float vignetteDist = length(rawUV - 0.5);
    float vignette = smoothstep(0.75, 0.3, vignetteDist);
    vignette = mix(0.2, 1.0, vignette);
    color *= vignette;

    // --- Focus: power state ---
    color *= mix(1.0, 0.6, down) + surge;

    // --- Layer 6: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Layer 7: Text Protection ---
    color = clamp(color, 0.0, 1.0);
    vec3 cleanText = texture(iChannel0, uv).rgb;
    color = mix(color, cleanText, textMask);

    // CRT edge fade
    float edgeFade = smoothstep(0.0, 0.01, uv.x) * smoothstep(1.0, 0.99, uv.x)
                   * smoothstep(0.0, 0.01, uv.y) * smoothstep(1.0, 0.99, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
