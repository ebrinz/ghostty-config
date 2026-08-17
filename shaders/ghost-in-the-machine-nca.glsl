// ghost-in-the-machine-nca.glsl
// Emergent cellular-automata variant. Ghostty shaders are stateless (no
// previous-frame buffer), so this runs TRUE Conway Life (B3/S23) via the
// light-cone trick: each frame recomputes N generations from a hash-seeded
// initial grid. Each ~24s epoch reseeds; you watch real structures emerge,
// evolve, and fade. Births flash white, deaths ghost out magenta.
// This is the heaviest shader in the collection — real rule iteration
// happens per pixel. Not neural: a feedback buffer upstream is required
// before actual NCA is possible.

const float PI = 3.14159265359;

// --- Palette -----------------------------------------------------------------
const vec3 ECTO    = vec3(0.490, 1.000, 0.769); // #7dffc4 spectral green
const vec3 MAGENTA = vec3(1.000, 0.373, 0.824); // #ff5fd2 Snow Crash neon
const vec3 DEEP    = vec3(0.024, 0.039, 0.035); // #060a09 near-black green

// --- CA configuration ---------------------------------------------------------
const int   GMAX  = 6;             // generations per epoch
const int   W     = 13;            // light-cone window = 2*GMAX+1
const float EPOCH = 24.0;          // seconds per reseed
const float STEP  = 1.8;           // seconds per generation

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

// ---------------------------------------------------------------------------
// Initial condition: hash-random cells, clumped by low-frequency noise so
// each epoch seeds distinct colonies instead of uniform static.
// ---------------------------------------------------------------------------
float aliveInit(vec2 cell, float seed) {
    float h = hash21(cell + seed * 173.0);
    float clump = noise(cell * 0.18 + seed * 41.0);
    return step(0.78 - clump * 0.28, h);
}

// ---------------------------------------------------------------------------
// Light-cone Life: evolve the (2*GMAX+1)^2 window around `cell` from the
// epoch seed, shrinking the valid radius each generation. Returns the
// center cell's state at generation `gen` and `gen+1` for crossfading.
// ---------------------------------------------------------------------------
vec2 lifeStates(vec2 cell, float seed, int gen) {
    float buf[W * W];
    float nxt[W * W];
    for (int i = 0; i < W * W; i++) {
        int x = i - (i / W) * W;
        int y = i / W;
        buf[i] = aliveInit(cell + vec2(float(x - GMAX), float(y - GMAX)), seed);
    }
    float sPrev = buf[GMAX * W + GMAX];
    float sNext = sPrev;
    for (int g = 1; g <= GMAX; g++) {
        if (g > gen + 1) break;
        int r = GMAX - g;
        for (int y = GMAX - r; y <= GMAX + r; y++) {
            for (int x = GMAX - r; x <= GMAX + r; x++) {
                float n =
                    buf[(y - 1) * W + x - 1] + buf[(y - 1) * W + x] + buf[(y - 1) * W + x + 1] +
                    buf[ y      * W + x - 1]                        + buf[ y      * W + x + 1] +
                    buf[(y + 1) * W + x - 1] + buf[(y + 1) * W + x] + buf[(y + 1) * W + x + 1];
                float alive = buf[y * W + x];
                // Conway B3/S23
                nxt[y * W + x] = (alive > 0.5)
                    ? ((n > 1.5 && n < 3.5) ? 1.0 : 0.0)
                    : ((n > 2.5 && n < 3.5) ? 1.0 : 0.0);
            }
        }
        for (int y = GMAX - r; y <= GMAX + r; y++)
            for (int x = GMAX - r; x <= GMAX + r; x++)
                buf[y * W + x] = nxt[y * W + x];
        if (g == gen)     sPrev = buf[GMAX * W + GMAX];
        if (g == gen + 1) sNext = buf[GMAX * W + GMAX];
    }
    return vec2(sPrev, sNext);
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

    // --- Faint ectoplasmic haze under the colony ---
    vec2 fp = uv * vec2(aspect, 1.0) * 2.5;
    float haze = noise(fp + vec2(time * 0.04, time * 0.02));
    color += mix(DEEP, ECTO * 0.4, haze * haze) * 0.08;

    // --- Epoch clock: reseed, evolve, hold, fade out ---
    float epochId = floor(time / EPOCH);
    float et = mod(time, EPOCH);
    float seed = hash21(vec2(epochId, 11.3));
    float gf = min(et / STEP, float(GMAX));
    int gen = int(min(floor(gf), float(GMAX - 1)));
    float frac = clamp(gf - float(gen), 0.0, 1.0);
    float vis = smoothstep(0.0, 1.5, et) * (1.0 - smoothstep(EPOCH - 4.0, EPOCH - 0.5, et));

    if (vis > 0.003) {
        vec2 cellCoord = uv * vec2(aspect, 1.0) * 24.0;
        vec2 cell = floor(cellCoord);
        vec2 states = lifeStates(cell, seed, gen);
        float blend = smoothstep(0.0, 1.0, frac);
        float a = mix(states.x, states.y, blend);

        // soft rounded cell body
        vec2 cf = fract(cellCoord) - 0.5;
        float shape = smoothstep(0.46, 0.18, length(cf));

        color += ECTO * shape * a * 0.14 * vis;
        // births flash bright white-green
        float birth = max(states.y - states.x, 0.0) * blend;
        color += vec3(0.85, 1.0, 0.92) * shape * birth * 0.20 * vis;
        // deaths ghost out magenta
        float death = max(states.x - states.y, 0.0) * blend;
        color += MAGENTA * shape * death * (1.0 - blend * 0.5) * 0.12 * vis;
    }

    // --- Vignette ---
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * 1.1;
    color *= clamp(vig, 0.0, 1.0);

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
