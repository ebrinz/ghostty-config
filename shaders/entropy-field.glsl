// entropy-field.glsl
// Companion shader for ghostty-rng — a quantum-noise "entropy field" backdrop.
// Drifting digital foam, sparkling bit-flips, a turquoise/gold sampling lattice,
// and a luminance-based text guard so the TUI stays crisp.
// Single-pass Ghostty fragment shader. Palette tuned to the app's accent colors.

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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float time = iTime;

    // --- Text detection: protect bright glyphs from any overlay ---
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.14, luma);

    vec3 color = clean.rgb;

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
    float flick = step(0.985, fract(sin(cellRand * 91.7 + time * (0.6 + cellRand)) * 0.5 + 0.5));
    vec2 cf = fract(cells) - 0.5;
    float dot2 = smoothstep(0.42, 0.0, length(cf));
    vec3 sparkCol = mix(ACCENT, GOLD, cellRand);
    color += sparkCol * dot2 * flick * 0.55;

    // -----------------------------------------------------------------------
    // Layer 3 — Bit-rain: sparse vertical streaks of falling random bits.
    // -----------------------------------------------------------------------
    float colId = floor(uv.x * 120.0);
    float colRand = hash21(vec2(colId, 7.0));
    float speed = 0.15 + colRand * 0.5;
    float phase = fract(uv.y + time * speed + colRand);
    float streak = smoothstep(0.0, 0.02, phase) * smoothstep(0.35, 0.0, phase);
    float gate = step(0.6, colRand); // only some columns rain
    color += ACCENT * streak * gate * 0.10;

    // -----------------------------------------------------------------------
    // Layer 4 — Baseline glow: a luminous turquoise band near the bottom,
    // echoing the 8.0 bits/byte ideal line in the entropy chart.
    // -----------------------------------------------------------------------
    float baseY = 0.06;
    float band = smoothstep(0.02, 0.0, abs(uv.y - baseY));
    float shimmer = 0.7 + 0.3 * sin(uv.x * 40.0 - time * 2.0);
    color += GOLD * band * shimmer * 0.08;

    // -----------------------------------------------------------------------
    // Layer 5 — Vignette to sink the periphery into indigo.
    // -----------------------------------------------------------------------
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * 1.1;
    color *= clamp(vig, 0.0, 1.0);

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
