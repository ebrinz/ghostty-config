// night-temple.glsl
// Theme: Egyptian Night Ritual — Torchlit Temple Open to the Stars
// Deep indigo, gold, turquoise. Tutankhamun's death mask palette.
// Single-pass fragment shader for Ghostty with 5 composited layers.
// Torch flicker, stone vignette, starfield, Nile reflections,
// 40 Hz gamma entrainment, and luminance-based text protection.

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

    // --- Text detection ---
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // -----------------------------------------------------------------------
    // Layer 1 — Torch Flicker (two wall-mounted braziers)
    // -----------------------------------------------------------------------

    // Left torch — warm amber
    vec3 leftTorchColor = vec3(0.95, 0.65, 0.20);
    float leftFlicker = 0.7 + 0.3 * noise(vec2(time * 3.0, 10.0));
    float leftFade = smoothstep(0.35, 0.0, uv.x);
    color += leftTorchColor * leftFade * leftFlicker * 0.08;

    // Right torch — slightly cooler gold
    vec3 rightTorchColor = vec3(0.90, 0.55, 0.15);
    float rightFlicker = 0.7 + 0.3 * noise(vec2(time * 3.0, 80.0));
    float rightFade = smoothstep(0.65, 1.0, uv.x);
    color += rightTorchColor * rightFade * rightFlicker * 0.08;

    // -----------------------------------------------------------------------
    // Layer 2 — Stone Vignette (recessed niche)
    // -----------------------------------------------------------------------
    vec2 vignetteCenter = vec2(0.50, 0.48);
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.75, 0.20, vignetteDist);
    vignette = mix(0.10, 1.0, vignette);
    color *= vignette;

    // -----------------------------------------------------------------------
    // Layer 3 — Starfield (through open temple roof)
    // -----------------------------------------------------------------------
    float starMask = smoothstep(0.6, 0.85, uv.y);

    if (starMask > 0.01) {
        float starDensity = 400.0;
        vec2 starCell = floor(uv * starDensity);
        float starHash = hash21(starCell);

        if (starHash > 0.985) {
            // Per-star twinkle speed (0.5-2.0)
            float twinkleSpeed = 0.5 + 1.5 * hash21(starCell + 77.0);
            float twinkle = 0.5 + 0.5 * sin(time * twinkleSpeed + starHash * 6.28);

            // Occasional blue tint
            float blueTint = step(0.5, hash21(starCell + 33.0));
            vec3 starColor = mix(vec3(0.9, 0.88, 0.95), vec3(0.7, 0.8, 1.0), blueTint * 0.3);

            color += starColor * twinkle * starMask * 0.5;
        }
    }

    // -----------------------------------------------------------------------
    // Layer 4 — Nile Reflections (bottom 25%)
    // -----------------------------------------------------------------------
    float nileMask = smoothstep(0.25, 0.0, uv.y);

    if (nileMask > 0.01) {
        float ripple1 = sin(uv.x * 35.0 + time * 2.5 + uv.y * 15.0) * 0.5 + 0.5;
        float ripple2 = sin(uv.x * 20.0 - time * 1.8 + uv.y * 10.0) * 0.5 + 0.5;
        float ripple = ripple1 * 0.6 + ripple2 * 0.4;

        // Blend torch gold and lapis blue
        vec3 torchGold = vec3(0.95, 0.65, 0.20);
        vec3 lapisBlue = vec3(0.18, 0.37, 0.66);
        float colorShift = sin(uv.x * 3.0 + time * 0.2) * 0.5 + 0.5;
        vec3 nileColor = mix(torchGold, lapisBlue, colorShift);

        color += nileColor * ripple * nileMask * 0.06;
    }

    // -----------------------------------------------------------------------
    // Layer 5 — 40 Hz Gamma Entrainment
    // -----------------------------------------------------------------------
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // -----------------------------------------------------------------------
    // Text Protection
    // -----------------------------------------------------------------------
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
