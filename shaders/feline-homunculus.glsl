// feline-homunculus.glsl
// Theme: Feline Homunculus Lost in Tokyo on a Rainy Night
// A single-pass fragment shader for Ghostty with 6 composited layers.
// Rain on glass, neon glow bleed, wet pavement reflections, asymmetric
// vignette, 40 Hz gamma entrainment, and luminance-based text protection.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;     // gamma brainwave entrainment frequency
const float GAMMA_AMP = 0.035;   // +-3.5% brightness — subliminal

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
    // Smooth interpolation (Hermite)
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x),
               mix(c, d, u.x), u.y);
}

// ---------------------------------------------------------------------------
// Rain streak function — hash-based particle system (NOT fbm)
// ---------------------------------------------------------------------------

float rainStreak(vec2 uv, float time) {
    float rain = 0.0;

    // Two layers for depth parallax
    // Layer 0: close rain  — scale 30, speed 1.2, full brightness
    // Layer 1: far rain    — scale 50, speed 1.8, half brightness
    for (int layer = 0; layer < 2; layer++) {
        float scale     = (layer == 0) ? 14.0 : 24.0;
        float speed     = (layer == 0) ? 1.4  : 2.0;
        float brightness = (layer == 0) ? 1.0  : 0.5;

        vec2 st = uv * scale;
        st.y += time * speed * scale;          // scroll downward

        vec2 cell = floor(st);
        vec2 local = fract(st);

        // Per-cell random: does this cell have a drop?
        float cellHash = hash21(cell + float(layer) * 137.0);
        if (cellHash < 0.65) continue;          // sparsity gate: step(0.65, hash)

        // Random x-offset so drops don't align on a grid
        float xOff = hash21(cell + 0.5 + float(layer) * 73.0);

        // Wind sway — shifts the whole streak, bending more at the tail
        float wind = sin(cell.y * 0.8 + time * 2.0 + xOff * 6.28);
        float wobbleHead = wind * 0.08;
        float wobbleTail = wind * 0.16;  // tail drifts further in the wind
        float wobble = mix(wobbleTail, wobbleHead, smoothstep(0.0, 0.8, local.y));

        float dropX = fract(xOff + wobble);

        // Tapered streak: wider at the bright head, thinner at the fading tail
        float taper = 0.3 + 0.7 * smoothstep(0.0, 0.7, local.y);
        float dx = abs(local.x - dropX);
        float baseWidth = (layer == 0) ? 0.018 : 0.03;  // foreground thinner
        float lineWidth = (baseWidth + 0.01 * hash21(cell + 99.0)) * taper;
        float streak = smoothstep(lineWidth, 0.0, dx);

        // Streak fade: bright head at bottom, long trail fading above
        float trail = pow(smoothstep(0.0, 0.85, local.y), 1.8);
        float headCap = smoothstep(1.0, 0.93, local.y);  // tiny fade at leading edge
        streak *= trail * headCap;

        rain += streak * brightness;
    }

    return clamp(rain, 0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Main image — 6 layers
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // -----------------------------------------------------------------------
    // --- Text detection (sampled before effects) ---
    // -----------------------------------------------------------------------
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);   // 1 on text, 0 on bg

    // Start compositing on top of the terminal background
    vec3 color = clean.rgb;

    // -----------------------------------------------------------------------
    // Layer 1 — Rain Streaks on Glass
    // -----------------------------------------------------------------------
    float rain = rainStreak(uv, time);
    vec3 rainColor = vec3(0.6, 0.75, 0.9);           // cool white-blue
    color += rainColor * rain * 0.18;

    // -----------------------------------------------------------------------
    // Layer 2 — Neon Glow Bleed (left warm, right cool)
    // -----------------------------------------------------------------------
    // Warm neon: pink #e84a72 <-> amber #f0a500
    vec3 pink  = vec3(0.910, 0.290, 0.447);
    vec3 amber = vec3(0.941, 0.647, 0.000);
    float warmMix = noise(vec2(time * 0.15, 1.0));    // slow shift
    vec3 warmNeon = mix(pink, amber, warmMix);
    float warmFlicker = 0.7 + 0.3 * noise(vec2(time * 3.0, 10.0));
    float warmFade = smoothstep(0.35, 0.0, uv.x);
    color += warmNeon * warmFade * warmFlicker * 0.08;

    // Cool neon: teal #45c8c2 <-> blue #4a9cd6
    vec3 teal = vec3(0.271, 0.784, 0.761);
    vec3 blue = vec3(0.290, 0.612, 0.839);
    float coolMix = noise(vec2(time * 0.12, 50.0));   // independent seed
    vec3 coolNeon = mix(teal, blue, coolMix);
    float coolFlicker = 0.7 + 0.3 * noise(vec2(time * 2.7, 80.0));
    float coolFade = smoothstep(0.65, 1.0, uv.x);
    color += coolNeon * coolFade * coolFlicker * 0.08;

    // -----------------------------------------------------------------------
    // Layer 3 — Wet Pavement Reflections (bottom 30%)
    // -----------------------------------------------------------------------
    float pavementMask = smoothstep(0.3, 0.0, uv.y);

    // Two sine-wave ripples at different frequencies
    float ripple1 = sin(uv.x * 40.0 + time * 3.0 + uv.y * 20.0) * 0.5 + 0.5;
    float ripple2 = sin(uv.x * 25.0 - time * 2.3 + uv.y * 15.0) * 0.5 + 0.5;
    float ripple = ripple1 * 0.6 + ripple2 * 0.4;

    // Reflected colors: warm/cool neon shifting across x with time
    float refShift = noise(vec2(uv.x * 2.0 + time * 0.1, 200.0));
    vec3 reflected = mix(warmNeon, coolNeon, refShift);

    // Amber lantern ripples mixed at 0.3 weight
    vec3 lantern = amber * ripple;
    vec3 pavementColor = mix(reflected * ripple, lantern, 0.3);

    color += pavementColor * pavementMask * 0.07;

    // -----------------------------------------------------------------------
    // Layer 3b — Bottom Glow (city light washing upward)
    // -----------------------------------------------------------------------
    float glowMask = smoothstep(0.35, 0.0, uv.y);      // fades out by 35% up
    float glowPulse = 0.85 + 0.15 * noise(vec2(time * 0.2, 300.0));
    // Warm amber-pink blend that shifts slowly
    float glowShift = noise(vec2(uv.x * 1.5 + time * 0.08, 400.0));
    vec3 glowColor = mix(amber * 0.7 + pink * 0.3,
                         teal  * 0.5 + amber * 0.5, glowShift);
    color += glowColor * glowMask * glowPulse * 0.10;

    // -----------------------------------------------------------------------
    // Layer 4 — Asymmetric Vignette
    // -----------------------------------------------------------------------
    vec2 vignetteCenter = vec2(0.55, 0.45);           // darker top-left, lighter bottom-right
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.8, 0.35, vignetteDist);
    vignette = mix(0.3, 1.0, vignette);               // corner darkness floor
    color *= vignette;

    // -----------------------------------------------------------------------
    // Layer 5 — 40 Hz Gamma Entrainment (subliminal)
    // -----------------------------------------------------------------------
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    // Weight toward periphery — peripheral retina is most flicker-sensitive
    float centerDist = length(uv - vec2(0.5));
    float peripheryWeight = smoothstep(0.15, 0.5, centerDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // -----------------------------------------------------------------------
    // Layer 6 — Text Protection (applied last)
    // -----------------------------------------------------------------------
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
