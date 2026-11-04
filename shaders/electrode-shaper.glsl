// electrode-shaper.glsl
// Theme: Cyberpunk CRT Electrode Shaper
// A Curious Experiment in EMF Effects on Plasma and Psionic Attenuation
// Single-pass fragment shader for Ghostty with 7 composited layers.
// CRT artifacts, plasma field, Jacob's ladder, EMF interference,
// vignette, 40 Hz gamma entrainment, and luminance-based text protection.
//
// Scene (y down on Metal): a Jacob's ladder centered on screen, drawn as
// light rather than line art — two diverging conductors glowing softly in a
// region of violet haze. An arc ignites at the bottom gap, climbs faster as
// it stretches, flashes out at the tips, pauses, and restarts every 3.6 s.
// A cursor resting between the rails draws a tendril from the nearest rail.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — the electrode. A violet plasma corona pulses on the cursor;
//            jumps of 2+ cells discharge a jagged lightning arc from the
//            old position to the new one, with a short afterglow.
//   focus  — unfocused, the chamber powers down: plasma collapses, arcs
//            stop, scanlines deepen. Regaining focus is a power-on surge:
//            brightness overshoots and settles, and one arc crosses the
//            screen through the cursor.

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

// ---------------------------------------------------------------------------
// CRT barrel distortion
// ---------------------------------------------------------------------------

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

// ---------------------------------------------------------------------------
// The apparatus: a Jacob's ladder drawn as light. `q` is square-space
// (uv.x * aspect, uv.y) of the barrel-distorted uv, y down on Metal.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Interaction helpers
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
// ---------------------------------------------------------------------------

vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// Lightning arc from a to b: the straight path displaced sideways by
// layered noise, re-rolled every frame step so it crackles. Returns
// (core, glow) intensities at pixel p.
vec2 lightningArc(vec2 p, vec2 a, vec2 b, float age, float cell) {
    const float DUR = 0.32;
    if (age > DUR) return vec2(0.0);
    vec2 ab = b - a;
    float len = max(length(ab), 1e-3);
    vec2 dir = ab / len;
    vec2 nrm = vec2(-dir.y, dir.x);
    float along = clamp(dot(p - a, dir), 0.0, len);
    float side = dot(p - a, nrm);
    // jag: zero at both electrodes, wild in the middle
    float seed = floor(age * 40.0);
    float u = along / len;
    float jag = (noise(vec2(along / cell * 0.9, seed)) - 0.5) * 2.0
              + (noise(vec2(along / cell * 3.0, seed + 7.0)) - 0.5) * 0.7;
    jag *= cell * 1.3 * sin(u * 3.14159);
    float d = abs(side - jag);
    float env = smoothstep(DUR, DUR * 0.4, age);
    float core = smoothstep(cell * 0.08 + 1.0, 0.0, d) * env;
    float glow = smoothstep(cell * 1.1, 0.0, d) * env * 0.5;
    return vec2(core, glow);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Layer 1: CRT Screen Artifacts ---

    // Barrel distortion — apply before all sampling
    float barrelStrength = 0.05;
    vec2 uv = barrelDistort(rawUV, barrelStrength);

    // Chromatic aberration — separate R/G/B sampling at edges
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
    float down      = 1.0 - focused;                       // chamber powered down
    // power-on surge: overshoot to ~1.35x then settle over ~0.9 s
    float surge     = focused * exp(-focusAge * 4.0) * sin(min(focusAge * 9.0, 3.14159)) * 0.35;

    // Scanlines — darken every other pixel row (deeper when powered down)
    float scanline = 1.0 - mix(0.15, 0.3, down) * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // --- Layer 2: Plasma Field ---
    vec3 violet = vec3(0.56, 0.25, 0.85);
    vec3 cyan   = vec3(0.13, 0.72, 0.78);
    vec3 hotWhite = vec3(0.9, 0.88, 1.0);

    float phase = noise(vec2(time * 0.08, 0.0));
    float phase2 = noise(vec2(time * 0.06, 100.0));
    vec3 plasmaColor = mix(violet, cyan, phase);
    plasmaColor = mix(plasmaColor, hotWhite, phase2 * 0.4);

    float plasmaMask = smoothstep(0.25, 0.55, edgeDist);
    float plasmaFlicker = 0.7 + 0.3 * noise(vec2(time * 2.5, uv.x * 8.0 + uv.y * 8.0));

    color += plasmaColor * plasmaMask * plasmaFlicker * 0.08 * mix(1.0, 0.25, down);

    // --- Layer 3b: The electrode — corona on the cursor, discharge on jumps ---
    float coronaPulse = 0.7 + 0.3 * sin(time * 9.0) * noise(vec2(time * 7.0, 1.0));
    float corona = exp(-cursorD * 1.8) * coronaPulse;
    color += mix(violet, cyan, 0.3) * corona * 0.25 * mix(0.3, 1.0, focused);

    vec2 bolt = lightningArc(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += hotWhite * bolt.x * 0.9 + plasmaColor * bolt.y * 0.6;
    // afterglow: the plasma remembers the path for a moment
    float after = smoothstep(0.9, 0.32, moveAge) * jumpGate;
    if (after > 0.001) {
        vec2 ab = curC - prevC;
        float h = clamp(dot(fragCoord - prevC, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
        float dAfter = length(fragCoord - prevC - ab * h);
        color += plasmaColor * smoothstep(cell * 0.8, 0.0, dAfter) * after * 0.12;
    }

    // power-on arc: one bolt across the screen through the cursor's row
    float powerArc = smoothstep(0.0, 0.04, focusAge) * smoothstep(0.35, 0.12, focusAge) * focused;
    if (powerArc > 0.001) {
        vec2 bolt2 = lightningArc(fragCoord, vec2(0.0, curC.y), vec2(iResolution.x, curC.y), focusAge, cell);
        color += (hotWhite * bolt2.x + plasmaColor * bolt2.y) * powerArc * 0.8;
    }

    // --- Layer 3c: The apparatus — a Jacob's ladder, drawn as light, not line art ---
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(uv.x * aspect, uv.y);
    float pxl = 1.0 / iResolution.y;
    // the chamber: a soft region of violet haze, no outline
    vec2 jp = q - vec2(aspect * 0.5, 0.0);
    vec2 jbd = abs(jp - vec2(0.0, 0.66)) - vec2(0.30, 0.30);
    float jarSd = min(length(max(jbd, 0.0)) + min(max(jbd.x, jbd.y), 0.0), length(jp - vec2(0.0, 0.36)) - 0.30);
    float haze = smoothstep(0.06, -0.12, jarSd);
    color += violet * haze * 0.05 * plasmaFlicker * mix(0.3, 1.0, focused);
    // rails: soft glowing conductors, brighter near the live arc
    vec3 lp = ladderPhase(time);
    float arcOn = lp.y * focused;
    vec3 conductor = mix(cyan, vec3(0.75, 0.80, 0.95), 0.5);
    for (int sdx = 0; sdx < 2; sdx++) {
        float side = (sdx == 0) ? -1.0 : 1.0;
        vec2 rb = railPoint(side, 0.0, aspect), rt = railPoint(side, 1.0, aspect);
        float d = segDistQ(q, rb, rt);
        float h = clamp(dot(q - rb, rt - rb) / dot(rt - rb, rt - rb), 0.0, 1.0);
        float near = exp(-abs(h - lp.x) * 6.0) * arcOn;                 // charge gathers near the arc
        color += conductor * exp(-d * 110.0) * (0.22 + 0.35 * near) * mix(0.35, 1.0, focused);
        color += violet * exp(-d * 30.0) * 0.06 * mix(0.3, 1.0, focused);
        color += violet * exp(-length(q - rb) * 45.0) * 0.25 * mix(0.3, 1.0, focused);   // charge pool at the foot
    }
    // the climbing arc: bloom-heavy, soft core
    if (arcOn > 0.5) {
        vec2 a = railPoint(-1.0, lp.x, aspect), b = railPoint(1.0, lp.x, aspect);
        float seed = floor(time * 45.0);
        float amp = mix(0.004, 0.03, lp.x);
        vec2 main = jagArc(q, a, b, seed, amp, pxl);
        vec2 second = jagArc(q, a, b, seed + 31.0, amp * 1.4, pxl) * 0.45;
        float energy = mix(0.7, 1.3, lp.x) * (0.85 + 0.15 * noise(vec2(time * 30.0, 3.0)));
        color += mix(hotWhite, plasmaColor, 0.35) * (main.x + second.x) * energy * 0.8;
        color += plasmaColor * (main.y + second.y) * energy * 1.3;
        color += mix(cyan, hotWhite, 0.5) * (exp(-length(q - a) * 60.0) + exp(-length(q - b) * 60.0)) * 0.5 * energy;
    }
    // snap flash at the rail tips when the arc lets go
    if (lp.z > 0.001 && focused > 0.5) {
        vec2 ta = railPoint(-1.0, 1.0, aspect), tb = railPoint(1.0, 1.0, aspect);
        color += mix(hotWhite, plasmaColor, 0.3) * (exp(-length(q - ta) * 30.0) + exp(-length(q - tb) * 30.0)) * lp.z * 0.7;
    }
    // the probe: a cursor between the rails draws a tendril from the nearest rail
    vec2 curUV = barrelDistort(curC / iResolution.xy, barrelStrength);
    vec2 curQ = vec2(curUV.x * aspect, curUV.y);
    float ch = clamp((0.95 - curQ.y) / (0.95 - 0.12), 0.0, 1.0);
    vec2 rl = railPoint(-1.0, ch, aspect), rr = railPoint(1.0, ch, aspect);
    float between = step(rl.x - 0.03, curQ.x) * step(curQ.x, rr.x + 0.03) * step(0.10, curQ.y) * step(curQ.y, 0.95);
    if (between * focused > 0.5) {
        vec2 from = (abs(curQ.x - rl.x) < abs(curQ.x - rr.x)) ? rl : rr;
        float gate = step(0.35, hash21(vec2(floor(time * 12.0), 5.0)));
        vec2 tend = jagArc(q, from, curQ, floor(time * 50.0) + 3.0, 0.012, pxl);
        color += (mix(hotWhite, plasmaColor, 0.35) * tend.x * 0.6 + plasmaColor * tend.y * 1.1) * gate;
        color += cyan * exp(-length(q - curQ) * 70.0) * 0.5 * gate;
    }

    // --- Layer 4: EMF Interference ---
    float bandY = uv.y * 80.0 + time * 2.0;
    float band = noise(vec2(0.0, bandY)) * noise(vec2(time * 0.5, bandY * 0.3));
    float burst = smoothstep(0.7, 0.9, noise(vec2(time * 0.3, uv.y * 2.0)));
    float emf = band * 0.04 + burst * 0.03;
    color += vec3(emf) * plasmaColor;

    // --- Layer 5: Vignette (CRT bezel + chamber walls) ---
    float vignetteDist = length(rawUV - 0.5);
    float vignette = smoothstep(0.75, 0.3, vignetteDist);
    vignette = mix(0.2, 1.0, vignette);
    color *= vignette;

    // --- Focus: power state — dim when down, surge on power-on ---
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

    // CRT edge fade — pixels outside the barrel curve go black
    float edgeFade = smoothstep(0.0, 0.01, uv.x) * smoothstep(1.0, 0.99, uv.x)
                   * smoothstep(0.0, 0.01, uv.y) * smoothstep(1.0, 0.99, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
