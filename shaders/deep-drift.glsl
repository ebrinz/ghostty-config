// deep-drift.glsl
// Theme: USS Erebus Terminal — 30 Years Adrift in Deep Space
// A degraded amber phosphor CRT on a 1996-era deep space vessel.
// Single-pass fragment shader for Ghostty with 7 composited layers.
// CRT artifacts, phosphor burn-in, power supply flicker, radiation static,
// H-sync wobble, vignette, 40 Hz gamma entrainment, and text protection.

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
// CRT barrel distortion — heavier than electrode-shaper (old tube)
// ---------------------------------------------------------------------------

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

// ---------------------------------------------------------------------------
// Layer 2: Phosphor burn-in — permanent damage from decades of static UI
// ---------------------------------------------------------------------------

float burnIn(vec2 uv) {
    float burn = 0.0;

    // Old status bar — horizontal line at ~20% from top
    float statusBar = smoothstep(0.005, 0.0, abs(uv.y - 0.82));
    burn += statusBar * 0.04;

    // Old window border — faint rectangular outline near edges
    float borderL = smoothstep(0.006, 0.0, abs(uv.x - 0.05));
    float borderR = smoothstep(0.006, 0.0, abs(uv.x - 0.95));
    float borderT = smoothstep(0.006, 0.0, abs(uv.y - 0.95));
    float borderB = smoothstep(0.006, 0.0, abs(uv.y - 0.05));
    float vertRange = step(0.05, uv.y) * step(uv.y, 0.95);
    float horizRange = step(0.05, uv.x) * step(uv.x, 0.95);
    burn += (borderL + borderR) * vertRange * 0.03;
    burn += (borderT + borderB) * horizRange * 0.03;

    // Old cursor position — a small bright rectangle, permanently etched
    float cursorX = smoothstep(0.02, 0.0, abs(uv.x - 0.12));
    float cursorY = smoothstep(0.008, 0.0, abs(uv.y - 0.50));
    burn += cursorX * cursorY * 0.05;

    return burn;
}

// ---------------------------------------------------------------------------
// Layer 4: Radiation static — cosmic ray bursts
// ---------------------------------------------------------------------------

float radiationBurst(vec2 uv, float time) {
    // Time cell for burst events — each cell ~7 seconds
    float cellSize = 7.0;
    float cell = floor(time / cellSize);
    float localTime = fract(time / cellSize);

    // Only fire ~40% of cells
    float fires = step(0.6, hash21(vec2(cell, 77.0)));
    if (fires < 0.5) return 0.0;

    // Burst envelope: quick on, quick off (0.1-0.3s within the cell)
    float burstStart = hash21(vec2(cell, 88.0)) * 0.5;
    float burstDuration = 0.015 + hash21(vec2(cell, 99.0)) * 0.03;
    float envelope = smoothstep(burstStart, burstStart + 0.005, localTime)
                   * smoothstep(burstStart + burstDuration, burstStart + burstDuration - 0.005, localTime);

    if (envelope < 0.01) return 0.0;

    // Random rectangular patch position and size
    vec2 patchCenter = vec2(hash21(vec2(cell, 111.0)), hash21(vec2(cell, 222.0)));
    vec2 patchSize = vec2(0.08 + hash21(vec2(cell, 333.0)) * 0.15,
                          0.05 + hash21(vec2(cell, 444.0)) * 0.10);

    // Is this pixel inside the patch?
    vec2 d = abs(uv - patchCenter);
    float inPatch = step(d.x, patchSize.x * 0.5) * step(d.y, patchSize.y * 0.5);
    if (inPatch < 0.5) return 0.0;

    // Sparse pixel noise within the patch (~3% density)
    float pixelNoise = hash21(floor(uv * 800.0) + vec2(cell * 13.7, cell * 7.3));
    float sparsePixel = step(0.97, pixelNoise);

    return sparsePixel * envelope;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Layer 5: H-Sync Wobble (applied to UV before sampling) ---
    // A band of horizontal displacement that drifts vertically
    float wobbleZoneCenter = 0.5 + 0.4 * sin(time * 0.15);
    float wobbleZoneWidth = 0.08;
    float wobbleMask = smoothstep(wobbleZoneWidth, 0.0,
                                  abs(rawUV.y - wobbleZoneCenter));
    float wobbleAmount = sin(rawUV.y * 60.0 + time * 2.0) * 0.002 * wobbleMask;
    vec2 wobbledUV = rawUV + vec2(wobbleAmount, 0.0);

    // --- Layer 1: CRT Screen Artifacts ---

    // Barrel distortion — stronger than electrode-shaper (old tube)
    float barrelStrength = 0.08;
    vec2 uv = barrelDistort(wobbledUV, barrelStrength);

    // Chromatic aberration — warm-shifted (red drifts more than blue)
    vec2 fromCenter = uv - 0.5;
    float edgeDist = length(fromCenter);
    float aberration = edgeDist * 0.004;
    vec2 aberrationDir = normalize(fromCenter + 0.0001);

    float r = texture(iChannel0, uv + aberrationDir * aberration * 1.3).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - aberrationDir * aberration * 0.7).b;
    float a = texture(iChannel0, uv).a;

    vec4 clean = vec4(r, g, b, a);
    vec3 color = clean.rgb;

    // Text detection — protect text from effects
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // Scanlines — thick, old hardware (20% darkening)
    float scanline = 1.0 - 0.20 * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // --- Layer 2: Phosphor Burn-In ---
    vec3 amberBurn = vec3(0.76, 0.64, 0.28); // amber tint
    float burn = burnIn(uv);
    color += amberBurn * burn;

    // --- Layer 3: Power Supply Flicker ---
    // Low-frequency noise creates organic brightness dips
    float flickerNoise = noise(vec2(time * 0.3, 0.0));
    float flickerNoise2 = noise(vec2(time * 0.17, 50.0));
    float combined = flickerNoise * flickerNoise2;
    // Threshold to create occasional dips rather than constant modulation
    float dip = smoothstep(0.15, 0.05, combined) * 0.15;
    color *= (1.0 - dip);

    // --- Layer 4: Deep Space Radiation Static ---
    float radiation = radiationBurst(uv, time);
    color += vec3(radiation) * 0.8;

    // --- Layer 6: Vignette (Aggressive, asymmetric) ---
    // Bottom-left is worse — gravity + heat degradation over 30 years
    vec2 vignetteCenter = vec2(0.52, 0.53); // shifted slightly from true center
    float vignetteDist = length(rawUV - vignetteCenter);
    float vignette = smoothstep(0.78, 0.25, vignetteDist);
    vignette = mix(0.15, 1.0, vignette);
    color *= vignette;

    // --- Layer 7a: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Layer 7b: Text Protection ---
    color = clamp(color, 0.0, 1.0);
    vec3 cleanText = texture(iChannel0, uv).rgb;
    color = mix(color, cleanText, textMask);

    // CRT edge fade — pixels outside the barrel curve go black
    float edgeFade = smoothstep(0.0, 0.015, uv.x) * smoothstep(1.0, 0.985, uv.x)
                   * smoothstep(0.0, 0.015, uv.y) * smoothstep(1.0, 0.985, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
