// electrode-shaper.glsl
// Theme: Cyberpunk CRT Electrode Shaper
// A Curious Experiment in EMF Effects on Plasma and Psionic Attenuation
// Single-pass fragment shader for Ghostty with 7 composited layers.
// CRT artifacts, plasma field, electrode arcs, EMF interference,
// vignette, 40 Hz gamma entrainment, and luminance-based text protection.
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
// Electrode arc — hash-based time-cell discharge
// ---------------------------------------------------------------------------

float electrodeArc(vec2 uv, float time) {
    float cellSize = 4.0;
    float cell = floor(time / cellSize);
    float localTime = fract(time / cellSize);

    float fires = step(0.6, hash21(vec2(cell, 0.0)));
    if (fires < 0.5) return 0.0;

    float envelope = smoothstep(0.0, 0.05, localTime)
                   * smoothstep(0.2, 0.12, localTime);

    float orientation = hash21(vec2(cell, 10.0));
    float pathPos = hash21(vec2(cell, 20.0)) * 0.6 + 0.2;

    float arcLine;
    if (orientation > 0.5) {
        float wobble = sin(uv.x * 15.0 + hash21(vec2(cell, 30.0)) * 6.28) * 0.03;
        arcLine = abs(uv.y - pathPos + wobble);
    } else {
        float wobble = sin(uv.y * 15.0 + hash21(vec2(cell, 40.0)) * 6.28) * 0.03;
        arcLine = abs(uv.x - pathPos + wobble);
    }

    float core = smoothstep(0.008, 0.0, arcLine);
    float glow = smoothstep(0.06, 0.0, arcLine) * 0.3;

    return (core + glow) * envelope;
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

    // --- Layer 3: Electrode Arcs (ambient arcs only while powered) ---
    float arc = electrodeArc(uv, time) * focused;
    vec3 arcColor = mix(plasmaColor, hotWhite, 0.6);
    color += arcColor * arc * 0.35;

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
