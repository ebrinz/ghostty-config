// electrode-shaper.glsl
// Theme: Cyberpunk CRT Electrode Shaper
// A Curious Experiment in EMF Effects on Plasma and Psionic Attenuation
// Single-pass fragment shader for Ghostty with 7 composited layers.
// CRT artifacts, plasma field, electrode arcs, EMF interference,
// vignette, 40 Hz gamma entrainment, and luminance-based text protection.

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
// CRT barrel distortion
// ---------------------------------------------------------------------------

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

// ---------------------------------------------------------------------------
// Electrode arc — hash-based time-cell discharge
// ---------------------------------------------------------------------------

float electrodeArc(vec2 uv, float time) {
    float cellSize = 4.0;
    float cell = floor(time / cellSize);
    float localTime = fract(time / cellSize);

    float fires = step(0.6, hash21(vec2(cell, 0.0)));
    if (fires < 0.5) return 0.0;

    float envelope = smoothstep(0.0, 0.05, localTime)
                   * smoothstep(0.2, 0.12, localTime);

    float orientation = hash21(vec2(cell, 10.0));
    float pathPos = hash21(vec2(cell, 20.0)) * 0.6 + 0.2;

    float arcLine;
    if (orientation > 0.5) {
        float wobble = sin(uv.x * 15.0 + hash21(vec2(cell, 30.0)) * 6.28) * 0.03;
        arcLine = abs(uv.y - pathPos + wobble);
    } else {
        float wobble = sin(uv.y * 15.0 + hash21(vec2(cell, 40.0)) * 6.28) * 0.03;
        arcLine = abs(uv.x - pathPos + wobble);
    }

    float core = smoothstep(0.008, 0.0, arcLine);
    float glow = smoothstep(0.06, 0.0, arcLine) * 0.3;

    return (core + glow) * envelope;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Layer 1: CRT Screen Artifacts ---

    // Barrel distortion — apply before all sampling
    float barrelStrength = 0.05;
    vec2 uv = barrelDistort(rawUV, barrelStrength);

    // Chromatic aberration — separate R/G/B sampling at edges
    vec2 fromCenter = uv - 0.5;
    float edgeDist = length(fromCenter);
    float aberration = edgeDist * 0.003;
    vec2 aberrationDir = normalize(fromCenter + 0.0001);

    float r = texture(iChannel0, uv + aberrationDir * aberration).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - aberrationDir * aberration).b;
    float a = texture(iChannel0, uv).a;

    vec4 clean = vec4(r, g, b, a);
    vec3 color = clean.rgb;

    // Text detection
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // Scanlines — darken every other pixel row
    float scanline = 1.0 - 0.15 * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // --- Layer 2: Plasma Field ---
    vec3 violet = vec3(0.56, 0.25, 0.85);
    vec3 cyan   = vec3(0.13, 0.72, 0.78);
    vec3 hotWhite = vec3(0.9, 0.88, 1.0);

    float phase = noise(vec2(time * 0.08, 0.0));
    float phase2 = noise(vec2(time * 0.06, 100.0));
    vec3 plasmaColor = mix(violet, cyan, phase);
    plasmaColor = mix(plasmaColor, hotWhite, phase2 * 0.4);

    float plasmaMask = smoothstep(0.25, 0.55, edgeDist);
    float plasmaFlicker = 0.7 + 0.3 * noise(vec2(time * 2.5, uv.x * 8.0 + uv.y * 8.0));

    color += plasmaColor * plasmaMask * plasmaFlicker * 0.08;

    // --- Layer 3: Electrode Arcs ---
    float arc = electrodeArc(uv, time);
    vec3 arcColor = mix(plasmaColor, hotWhite, 0.6);
    color += arcColor * arc * 0.35;

    // --- Layer 4: EMF Interference ---
    float bandY = uv.y * 80.0 + time * 2.0;
    float band = noise(vec2(0.0, bandY)) * noise(vec2(time * 0.5, bandY * 0.3));
    float burst = smoothstep(0.7, 0.9, noise(vec2(time * 0.3, uv.y * 2.0)));
    float emf = band * 0.04 + burst * 0.03;
    color += vec3(emf) * plasmaColor;

    // --- Layers 5-6 will be inserted here ---

    // --- Layer 7: Text Protection ---
    color = clamp(color, 0.0, 1.0);
    vec3 cleanText = texture(iChannel0, uv).rgb;
    color = mix(color, cleanText, textMask);

    // CRT edge fade — pixels outside the barrel curve go black
    float edgeFade = smoothstep(0.0, 0.01, uv.x) * smoothstep(1.0, 0.99, uv.x)
                   * smoothstep(0.0, 0.01, uv.y) * smoothstep(1.0, 0.99, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
