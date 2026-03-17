// feline-homunculus-lite.glsl
// Lite variant: single-layer rain only.
// Drops: neon bleed, pavement reflections, bottom glow (7 noise calls removed).
// Effects: rain streaks (1 layer), vignette, 40Hz gamma entrainment, text protection.

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

// ---------------------------------------------------------------------------
// Rain streak function — single layer only (foreground rain)
// ---------------------------------------------------------------------------

float rainStreak(vec2 uv, float time) {
    float rain = 0.0;

    // Single foreground layer only (lite: dropped far rain layer)
    float scale = 14.0;
    float speed = 1.4;

    vec2 st = uv * scale;
    st.y += time * speed * scale;

    vec2 cell = floor(st);
    vec2 local = fract(st);

    float cellHash = hash21(cell);
    if (cellHash < 0.65) return 0.0;

    float xOff = hash21(cell + 0.5);

    float wind = sin(cell.y * 0.8 + time * 2.0 + xOff * 6.28);
    float wobbleHead = wind * 0.08;
    float wobbleTail = wind * 0.16;
    float wobble = mix(wobbleTail, wobbleHead, smoothstep(0.0, 0.8, local.y));

    float dropX = fract(xOff + wobble);

    float taper = 0.3 + 0.7 * smoothstep(0.0, 0.7, local.y);
    float dx = abs(local.x - dropX);
    float baseWidth = 0.018;
    float lineWidth = (baseWidth + 0.01 * hash21(cell + 99.0)) * taper;
    float streak = smoothstep(lineWidth, 0.0, dx);

    float trail = pow(smoothstep(0.0, 0.85, local.y), 1.8);
    float headCap = smoothstep(1.0, 0.93, local.y);
    streak *= trail * headCap;

    return clamp(streak, 0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Main image
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Text detection ---
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // --- Layer 1: Rain Streaks (single layer) ---
    float rain = rainStreak(uv, time);
    vec3 rainColor = vec3(0.6, 0.75, 0.9);
    color += rainColor * rain * 0.18;

    // --- Layer 4: Asymmetric Vignette ---
    vec2 vignetteCenter = vec2(0.55, 0.45);
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.8, 0.35, vignetteDist);
    vignette = mix(0.3, 1.0, vignette);
    color *= vignette;

    // --- Layer 5: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float centerDist = length(uv - vec2(0.5));
    float peripheryWeight = smoothstep(0.15, 0.5, centerDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Layer 6: Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
