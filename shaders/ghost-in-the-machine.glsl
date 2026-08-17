// ghost-in-the-machine.glsl
// Spectral ectoplasm drifting through a jittering Fuller geodesic lattice,
// sparse matrix code-rain, and a rare magenta Snow Crash glitch burst.
// Ecto-green leads; magenta is the neon twang. Luma text guard keeps
// glyphs crisp. Single-pass Ghostty fragment shader.

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

vec2 jitterVert(vec2 v, float t) {
    float h1 = hash21(v);
    float h2 = hash21(v + 31.7);
    // slow drift plus a fast nervous tremor, both per-vertex
    vec2 drift  = vec2(sin(t * (0.6 + h1) + h1 * 2.0 * PI),
                       cos(t * (0.7 + h2) + h2 * 2.0 * PI)) * 0.06;
    vec2 tremor = vec2(sin(t * (5.0 + h2 * 3.0)),
                       cos(t * (4.3 + h1 * 3.0))) * 0.015;
    return drift + tremor;
}

vec2 geodesicLattice(vec2 uv, float aspect, float t) {
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
    vec2 w0 = fromTri * v0 + jitterVert(v0, t);
    vec2 w1 = fromTri * v1 + jitterVert(v1, t);
    vec2 w2 = fromTri * v2 + jitterVert(v2, t);
    float d = min(segDist(p, w0, w1), min(segDist(p, w1, w2), segDist(p, w2, w0)));
    float edge = smoothstep(0.025, 0.0, d);
    float nd = min(length(p - w0), min(length(p - w1), length(p - w2)));
    float node = smoothstep(0.06, 0.0, nd);
    return vec2(edge, node);
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
    // Layer 1 — Ectoplasmic vapor: domain-warped fbm mist that curls.
    // -----------------------------------------------------------------------
    vec2 fp = uv * vec2(aspect, 1.0) * 2.5;
    vec2 warp = vec2(fbm(fp + time * 0.04),
                     fbm(fp + vec2(5.2, 1.3) - time * 0.03));
    float vapor = fbm(fp + 1.8 * warp + vec2(0.0, time * 0.02));
    vapor = pow(vapor, 1.5);
    color += mix(DEEP, ECTO * 0.45, vapor) * 0.12;

    // -----------------------------------------------------------------------
    // Layer 2 — Geodesic lattice: faint jittering mesh, brighter nodes.
    // -----------------------------------------------------------------------
    vec2 lat = geodesicLattice(uv, aspect, time);
    color += ECTO * lat.x * 0.07;
    color += ECTO * lat.y * 0.18;

    // -----------------------------------------------------------------------
    // Layer 3 — Matrix code-rain: sparse columns of glyph-blocky streaks.
    // -----------------------------------------------------------------------
    float colId = floor(uv.x * 80.0);
    float colRand = hash21(vec2(colId, 3.7));
    float gate = step(0.72, colRand); // only some columns rain
    float speed = 0.25 + colRand * 0.6;
    float phase = fract(uv.y + time * speed + colRand);
    float streak = smoothstep(0.0, 0.05, phase) * smoothstep(0.45, 0.0, phase);
    // glyph flicker: cells wink as the trail passes, like changing characters
    float rowId = floor(uv.y * 45.0);
    float glyph = step(0.4, hash21(vec2(colId, rowId) + floor(time * 6.0)));
    streak *= (0.45 + 0.55 * glyph) * gate;
    color += PHOS * streak * 0.16;
    // bright head at the leading edge of each trail
    float head = smoothstep(0.05, 0.0, phase) * gate * glyph;
    color += vec3(0.85, 1.0, 0.92) * head * 0.22;

    // -----------------------------------------------------------------------
    // Layer 4 — Snow Crash burst: rare magenta static band with glitch offset.
    // -----------------------------------------------------------------------
    const float CYCLE = 13.0;
    float ct = mod(time, CYCLE);
    float burst = smoothstep(0.0, 0.06, ct) * smoothstep(0.55, 0.30, ct);
    if (burst > 0.001) {
        float bandY = hash21(vec2(floor(time / CYCLE), 2.0)) * 0.8 + 0.1;
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

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
