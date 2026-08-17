// entropy-field-lite.glsl
// Reduced-power variant of entropy-field — fewer octaves, no bit-rain,
// gentler motion. Same palette and text guard. For battery / low-GPU use.

const vec3 ACCENT = vec3(0.424, 0.941, 0.816);
const vec3 GOLD   = vec3(0.949, 0.757, 0.306);
const vec3 DEEP   = vec3(0.020, 0.043, 0.063);

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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float time = iTime;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.14, luma);

    vec3 color = clean.rgb;

    // Entropy haze (2 octaves only).
    vec2 fp = uv * vec2(aspect, 1.0) * 3.0 + vec2(time * 0.03, time * 0.02);
    float haze = noise(fp) * 0.6 + noise(fp * 2.0) * 0.4;
    color += mix(DEEP, ACCENT * 0.5, pow(haze, 1.6)) * 0.05;

    // Sparse sampling lattice (slower flicker).
    vec2 cells = uv * vec2(48.0 * aspect, 28.0);
    vec2 cid = floor(cells);
    float cellRand = hash21(cid);
    float flick = step(0.99, fract(sin(cellRand * 91.7 + time * 0.4) * 0.5 + 0.5));
    float dot2 = smoothstep(0.42, 0.0, length(fract(cells) - 0.5));
    color += mix(ACCENT, GOLD, cellRand) * dot2 * flick * 0.4;

    // Baseline glow.
    float band = smoothstep(0.02, 0.0, abs(uv.y - 0.06));
    color += GOLD * band * 0.06;

    vec2 vd = uv - 0.5;
    color *= clamp(1.0 - dot(vd, vd) * 1.1, 0.0, 1.0);

    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);
    fragColor = vec4(color, clean.a);
}
