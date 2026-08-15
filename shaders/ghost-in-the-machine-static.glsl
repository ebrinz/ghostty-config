// ghost-in-the-machine-static.glsl
// Static variant: frozen ectoplasmic vapor + geodesic lattice with fixed
// per-vertex jitter. No time dependence — pair with
// custom-shader-animation = false so idle power drops to zero.

const vec3 ECTO = vec3(0.490, 1.000, 0.769); // #7dffc4 spectral green
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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Fixed per-vertex displacement — the jitter frozen mid-tremor.
vec2 jitterVert(vec2 v) {
    float h1 = hash21(v);
    float h2 = hash21(v + 31.7);
    return (vec2(h1, h2) - 0.5) * 0.12;
}

vec2 geodesicLattice(vec2 uv, float aspect) {
    vec2 p = uv * vec2(aspect, 1.0) * 6.0;
    mat2 toTri = mat2(1.0, 0.0, -0.57735, 1.15470);
    mat2 fromTri = mat2(1.0, 0.0, 0.5, 0.866025);
    vec2 g = toTri * p;
    vec2 gi = floor(g);
    vec2 gf = fract(g);
    float upper = step(1.0, gf.x + gf.y);
    vec2 v0 = gi + vec2(upper, upper);
    vec2 v1 = gi + vec2(1.0, 0.0);
    vec2 v2 = gi + vec2(0.0, 1.0);
    vec2 w0 = fromTri * v0 + jitterVert(v0);
    vec2 w1 = fromTri * v1 + jitterVert(v1);
    vec2 w2 = fromTri * v2 + jitterVert(v2);
    float d = min(segDist(p, w0, w1), min(segDist(p, w1, w2), segDist(p, w2, w0)));
    float edge = smoothstep(0.025, 0.0, d);
    float nd = min(length(p - w0), min(length(p - w1), length(p - w2)));
    float node = smoothstep(0.06, 0.0, nd);
    return vec2(edge, node);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.14, luma);

    vec3 color = clean.rgb;

    // --- Frozen ectoplasmic vapor ---
    vec2 fp = uv * vec2(aspect, 1.0) * 2.5;
    float vapor = fbm(fp);
    vapor = pow(vapor, 1.5);
    color += mix(DEEP, ECTO * 0.45, vapor) * 0.12;

    // --- Geodesic lattice, jitter frozen ---
    vec2 lat = geodesicLattice(uv, aspect);
    color += ECTO * lat.x * 0.07;
    color += ECTO * lat.y * 0.18;

    // --- Vignette ---
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * 1.1;
    color *= clamp(vig, 0.0, 1.0);

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
