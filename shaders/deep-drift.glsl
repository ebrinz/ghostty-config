// deep-drift.glsl
// Theme: USS Erebus Terminal — 30 Years Adrift in Deep Space
// A degraded amber phosphor CRT on a 1996-era deep space vessel.
// Single-pass fragment shader for Ghostty with 7 composited layers.
// CRT artifacts, phosphor burn-in, power supply flicker, radiation static,
// H-sync wobble, vignette, 40 Hz gamma entrainment, and text protection.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — slow amber phosphor. The cursor leaves a ghost of itself at its
//            previous position that decays over ~1.4 s, with a faint smear
//            between the two on jumps of 2+ cells. A soft phosphor bloom
//            haloes the resting cursor.
//   focus  — unfocused, the console drops to standby: half brightness,
//            deeper scanlines, heavier power-supply dips. Regaining focus is
//            a CRT power-on: the raster collapses to a bright line and
//            unfolds vertically over ~0.45 s.

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
// Interaction helpers
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
// ---------------------------------------------------------------------------

vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// Soft box: 1 inside the cursor rect, feathering out by `soft` pixels.
float cursorBox(vec2 p, vec4 c, float soft) {
    vec2 center = cursorCenter(c);
    vec2 halfSize = max(c.zw * 0.5, vec2(1.0));
    vec2 d = abs(p - center) - halfSize;
    float outside = length(max(d, 0.0));
    return 1.0 - smoothstep(0.0, soft, outside);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Interaction state ---
    float focused   = float(iFocus > 0);
    float focusAge  = iTime - iTimeFocus;
    vec2  curC      = cursorCenter(iCurrentCursor);
    vec2  prevC     = cursorCenter(iPreviousCursor);
    float cell      = max(max(iCurrentCursor.z, iCurrentCursor.w), 4.0);
    float moveAge   = iTime - iTimeCursorChange;
    // move measured in columns/rows (a bar cursor's z is only the bar width
    // and an underline's w only its thickness, so each axis has a fallback)
    vec2  cellWH    = vec2(iCurrentCursor.z > 4.0 ? iCurrentCursor.z : max(iCurrentCursor.w * 0.5, 2.0),
                           max(max(iCurrentCursor.w, iCurrentCursor.z * 2.0), 4.0));
    float moveCells = length((curC - prevC) / cellWH);
    float hasPrev   = step(0.5, iPreviousCursor.w);
    float jumpGate  = hasPrev * smoothstep(1.2, 3.0, moveCells);
    float cursorD   = length(fragCoord - curC) / cell;
    float standby   = 1.0 - focused;

    // --- Power-on: raster unfolds from a horizontal line over 0.45 s ---
    const float POWER_DUR = 0.45;
    float unfold = focused * (1.0 - smoothstep(0.0, POWER_DUR, focusAge)); // 1 -> 0
    float vScale = max(1.0 - unfold * unfold, 0.015);
    rawUV.y = 0.5 + (rawUV.y - 0.5) / vScale;
    float rasterLine = unfold * smoothstep(0.02, 0.0, abs(fragCoord.y / iResolution.y - 0.5))
                     * smoothstep(0.0, 0.1, unfold);
    float rasterMask = step(0.0, rawUV.y) * step(rawUV.y, 1.0);

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

    // Scanlines — thick, old hardware (20% darkening; 35% in standby)
    float scanline = 1.0 - mix(0.20, 0.35, standby) * mod(floor(fragCoord.y), 2.0);
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
    float dip = smoothstep(0.15, 0.05, combined) * mix(0.15, 0.35, standby);
    color *= (1.0 - dip);

    // --- Layer 3b: Phosphor persistence — the cursor's ghost and bloom ---
    vec3 phosphor = vec3(0.91, 0.63, 0.06); // #e8a010 cursor amber
    // ghost of the previous cursor block, decaying over ~1.4 s
    float ghostAge = clamp(moveAge / 1.4, 0.0, 1.0);
    float ghost = cursorBox(fragCoord, iPreviousCursor, cell * 0.35)
                * pow(1.0 - ghostAge, 1.6) * hasPrev * smoothstep(1.0, 2.0, moveCells);
    color += phosphor * ghost * 0.55;
    // smear between old and new position on jumps
    if (jumpGate > 0.001) {
        vec2 ab = curC - prevC;
        float h = clamp(dot(fragCoord - prevC, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
        float dSmear = length(fragCoord - prevC - ab * h);
        float smear = smoothstep(cell * 0.45, 0.0, dSmear) * pow(1.0 - clamp(moveAge / 0.7, 0.0, 1.0), 2.0);
        color += phosphor * smear * jumpGate * 0.25;
    }
    // bloom around the resting cursor
    float bloom = exp(-cursorD * 1.7) * (0.92 + 0.08 * noise(vec2(time * 8.0, 2.0)));
    color += phosphor * bloom * 0.16 * mix(0.4, 1.0, focused);

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

    // --- Focus: standby brightness, power-on raster ---
    color *= mix(1.0, 0.5, standby);
    color *= rasterMask;
    color += phosphor * rasterLine * 1.2 + vec3(1.0, 0.95, 0.85) * rasterLine * 0.6;

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
