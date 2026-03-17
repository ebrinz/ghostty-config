// electrode-shaper-lite.glsl
// Lite variant: CRT artifacts only, no plasma/arcs/EMF.
// Drops: plasma field, electrode arcs, EMF interference (all noise removed).
// Effects: barrel distortion, chromatic aberration, scanlines, vignette,
//          40Hz gamma entrainment, text protection.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// ---------------------------------------------------------------------------
// CRT barrel distortion
// ---------------------------------------------------------------------------

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Layer 1: CRT Screen Artifacts ---

    // Barrel distortion
    float barrelStrength = 0.05;
    vec2 uv = barrelDistort(rawUV, barrelStrength);

    // Chromatic aberration
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

    // Scanlines
    float scanline = 1.0 - 0.15 * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // --- Layer 5: Vignette ---
    float vignetteDist = length(rawUV - 0.5);
    float vignette = smoothstep(0.75, 0.3, vignetteDist);
    vignette = mix(0.2, 1.0, vignette);
    color *= vignette;

    // --- Layer 6: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Layer 7: Text Protection ---
    color = clamp(color, 0.0, 1.0);
    vec3 cleanText = texture(iChannel0, uv).rgb;
    color = mix(color, cleanText, textMask);

    // CRT edge fade
    float edgeFade = smoothstep(0.0, 0.01, uv.x) * smoothstep(1.0, 0.99, uv.x)
                   * smoothstep(0.0, 0.01, uv.y) * smoothstep(1.0, 0.99, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
