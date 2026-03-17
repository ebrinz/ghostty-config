// street-shaman-lite.glsl
// Lite variant: firelight flicker + bottom glow only.
// Drops: fbm smoke, azure wisps, heat distortion (26 -> 1 noise eval).
// Effects: firelight flicker, bottom glow, vignette, 40Hz gamma entrainment, text protection.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// --- Noise functions ---

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// --- Main ---

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // Sample the clean terminal texture
    vec4 clean = texture(iChannel0, uv);

    // --- Text detection ---
    float luma = dot(clean.rgb, vec3(0.299, 0.587, 0.114));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec4 color = clean;

    // --- 2. Firelight Flicker + Vignette ---
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vignette = smoothstep(0.78, 0.45, dist);

    float flickerNoise = noise(vec2(time * 3.0, uv.y * 5.0));
    float flicker = mix(0.6, 1.0, flickerNoise);

    float edgeFactor = mix(flicker * 0.35, 1.0, vignette);
    color.rgb *= edgeFactor;

    // --- 5. Green ambient glow at bottom edge (fire below) ---
    float bottomGlow = (1.0 - uv.y) * (1.0 - uv.y);
    float glowPulse = 0.5 + 0.5 * sin(time * 1.2);
    vec3 fireGlow = vec3(0.0, 0.12, 0.03) * bottomGlow * mix(0.3, 0.6, glowPulse);
    color.rgb += fireGlow;

    // --- 6. 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float gammaModulation = 1.0 + gamma * GAMMA_AMP;
    float gammaZone = smoothstep(0.15, 0.5, dist);
    color.rgb *= mix(1.0, gammaModulation, gammaZone);

    // --- 7. Text Protection ---
    color.rgb = mix(color.rgb, clean.rgb, textMask);

    fragColor = color;
}
