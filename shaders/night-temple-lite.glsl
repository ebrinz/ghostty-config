// night-temple-lite.glsl
// Lite variant: torch flicker + stone vignette only.
// Drops: starfield, Nile reflections (0 noise saved — those were hash/sin based).
// Effects: torch flicker (2 noise calls), stone vignette, 40Hz gamma, text protection.

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
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // --- Layer 1: Torch Flicker ---
    vec3 leftTorchColor = vec3(0.95, 0.65, 0.20);
    float leftFlicker = 0.7 + 0.3 * noise(vec2(time * 3.0, 10.0));
    float leftFade = smoothstep(0.35, 0.0, uv.x);
    color += leftTorchColor * leftFade * leftFlicker * 0.08;

    vec3 rightTorchColor = vec3(0.90, 0.55, 0.15);
    float rightFlicker = 0.7 + 0.3 * noise(vec2(time * 3.0, 80.0));
    float rightFade = smoothstep(0.65, 1.0, uv.x);
    color += rightTorchColor * rightFade * rightFlicker * 0.08;

    // --- Layer 2: Stone Vignette ---
    vec2 vignetteCenter = vec2(0.50, 0.48);
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.75, 0.20, vignetteDist);
    vignette = mix(0.10, 1.0, vignette);
    color *= vignette;

    // --- Layer 5: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
