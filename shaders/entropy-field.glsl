// entropy-field.glsl
// Companion shader for ghostty-rng — a quantum-noise "entropy field" backdrop.
// Drifting digital foam, sparkling bit-flips, a turquoise/gold sampling lattice,
// and a luminance-based text guard so the TUI stays crisp.
// Single-pass Ghostty fragment shader. Palette tuned to the app's accent colors.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — the sampler. Lattice cells near the cursor sample far more
//            often, and a jump of 2+ cells flips the bits along its path
//            gold before they settle. Kept subtle so the charts stay honest.
//   focus  — unfocused, the field idles: bit-rain stops, the lattice goes
//            quiet, the backdrop dims. Regaining focus sends one sampling
//            ring out from the cursor.

const float PI = 3.14159265359;

// --- App-matched palette ----------------------------------------------------
const vec3 ACCENT = vec3(0.424, 0.941, 0.816); // #6cf0d0 turquoise
const vec3 GOLD   = vec3(0.949, 0.757, 0.306); // #f2c14e
const vec3 DEEP   = vec3(0.020, 0.043, 0.063); // near-black indigo

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

// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

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
    float idle      = 1.0 - focused;
    // sampling ring on focus gain: expands ~40 cells over 0.8 s
    float ringR     = focusAge * 50.0;
    float ring      = smoothstep(2.5, 0.0, abs(cursorD - ringR)) * smoothstep(0.8, 0.1, focusAge) * focused;
    // bit-flip path: distance (in cells) from the prev -> cur segment
    vec2  ab        = curC - prevC;
    float h         = clamp(dot(fragCoord - prevC, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    float pathD     = length(fragCoord - prevC - ab * h) / cell;
    float flip      = smoothstep(0.9, 0.2, pathD) * smoothstep(0.7, 0.0, moveAge) * jumpGate;

    // -----------------------------------------------------------------------
    // Layer 1 — Entropy haze: slow, drifting fractal foam.
    // -----------------------------------------------------------------------
    vec2 fp = uv * vec2(aspect, 1.0) * 3.0;
    float haze = fbm(fp + vec2(time * 0.05, time * 0.03));
    haze = pow(haze, 1.6);
    vec3 hazeCol = mix(DEEP, ACCENT * 0.5, haze);
    color += hazeCol * 0.06;

    // -----------------------------------------------------------------------
    // Layer 2 — Sampling lattice: a faint grid of "entropy cells" that pulse,
    // evoking the byte-distribution panel sampling the stream.
    // -----------------------------------------------------------------------
    vec2 cells = uv * vec2(60.0 * aspect, 34.0);
    vec2 cid = floor(cells);
    float cellRand = hash21(cid);
    // Each cell flickers on its own clock — like bits being sampled.
    // The sampler (cursor) drives nearby cells much harder; the whole lattice
    // goes quiet when the window is idle.
    float near = exp(-cursorD * 0.35) * focused;
    float thresh = mix(0.985, 0.7, near) + idle * 0.012;
    float flick = step(thresh, fract(sin(cellRand * 91.7 + time * (0.6 + cellRand)) * 0.5 + 0.5));
    vec2 cf = fract(cells) - 0.5;
    float dot2 = smoothstep(0.42, 0.0, length(cf));
    vec3 sparkCol = mix(ACCENT, GOLD, cellRand);
    color += sparkCol * dot2 * flick * 0.55;
    // bits flipped along the cursor's path light gold, then settle
    float flipped = step(0.5, hash21(cid + floor(moveAge * 30.0)));
    color += GOLD * dot2 * flip * flipped * 0.7;
    // focus-gain sampling ring lights the cells it passes through
    color += ACCENT * dot2 * ring * 0.8;

    // -----------------------------------------------------------------------
    // Layer 3 — Bit-rain: sparse vertical streaks of falling random bits.
    // -----------------------------------------------------------------------
    float colId = floor(uv.x * 120.0);
    float colRand = hash21(vec2(colId, 7.0));
    float speed = 0.15 + colRand * 0.5;
    float phase = fract(time * speed - uv.y + colRand);   // heads travel down the screen (y down)
    float streak = smoothstep(0.0, 0.02, phase) * smoothstep(0.35, 0.0, phase);
    float gate = step(0.6, colRand) * focused; // only some columns rain, and only when focused
    color += ACCENT * streak * gate * 0.10;

    // -----------------------------------------------------------------------
    // Layer 4 — Baseline glow: a luminous turquoise band near the bottom,
    // echoing the 8.0 bits/byte ideal line in the entropy chart.
    // -----------------------------------------------------------------------
    float baseY = 0.94;   // near the bottom of the screen (y down)
    float band = smoothstep(0.02, 0.0, abs(uv.y - baseY));
    float shimmer = 0.7 + 0.3 * sin(uv.x * 40.0 - time * 2.0);
    color += GOLD * band * shimmer * 0.08;

    // -----------------------------------------------------------------------
    // Layer 5 — Vignette to sink the periphery into indigo.
    // -----------------------------------------------------------------------
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * 1.1;
    color *= clamp(vig, 0.0, 1.0);

    // --- Focus: the field idles in the background ---
    color *= mix(1.0, 0.7, idle);

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
