// ghost-in-the-machine-lite.glsl
// Lite variant: ectoplasmic vapor (3-octave, no domain warp) + matrix
// code-rain only. Drops the geodesic lattice and Snow Crash burst.

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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float time = iTime;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.14, luma);

    vec3 color = clean.rgb;

    // --- Ectoplasmic vapor: slow-drifting mist ---
    vec2 fp = uv * vec2(aspect, 1.0) * 2.5;
    float vapor = fbm(fp + vec2(time * 0.04, time * 0.02));
    vapor = pow(vapor, 1.5);
    color += mix(DEEP, ECTO * 0.45, vapor) * 0.12;

    // --- Matrix code-rain: sparse glyph-blocky streaks ---
    float colId = floor(uv.x * 80.0);
    float colRand = hash21(vec2(colId, 3.7));
    float gate = step(0.72, colRand);
    float speed = 0.25 + colRand * 0.6;
    float phase = fract(uv.y + time * speed + colRand);
    float streak = smoothstep(0.0, 0.05, phase) * smoothstep(0.45, 0.0, phase);
    float rowId = floor(uv.y * 45.0);
    float glyph = step(0.4, hash21(vec2(colId, rowId) + floor(time * 6.0)));
    streak *= (0.45 + 0.55 * glyph) * gate;
    color += PHOS * streak * 0.16;

    // --- Vignette ---
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * 1.1;
    color *= clamp(vig, 0.0, 1.0);

    // --- Text protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
