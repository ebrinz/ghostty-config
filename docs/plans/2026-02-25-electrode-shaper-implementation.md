# Electrode Shaper Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the `electrode-shaper` Ghostty theme — a CRT viewport into an unstable plasma chamber with electrode arcs, color-cycling plasma, and authentic CRT artifacts.

**Architecture:** Single-pass GLSL shader with 7 composited layers (CRT artifacts, plasma field, electrode arcs, EMF interference, vignette, 40 Hz gamma, text protection) plus a Ghostty color palette file. Same layered pattern as feline-homunculus and street-shaman.

**Tech Stack:** GLSL (Ghostty custom shader API: `iResolution`, `iTime`, `iChannel0`), Ghostty theme format

**Design doc:** `docs/plans/2026-02-25-electrode-shaper-design.md`

---

### Task 1: Create the color palette file

**Files:**
- Create: `themes/electrode-shaper`

**Step 1: Write the palette file**

```
background = #08080f
foreground = #c0c8d8
cursor-color = #e0e0ff
cursor-text = #08080f
selection-background = #1a1a3a
selection-foreground = #e8e0ff

# ANSI Normal (0-7)
palette = 0=#08080f
palette = 1=#c43060
palette = 2=#30c878
palette = 3=#c8a830
palette = 4=#3060d0
palette = 5=#9040d8
palette = 6=#20b8c8
palette = 7=#8088a0

# ANSI Bright (8-15)
palette = 8=#2a2a3f
palette = 9=#e84888
palette = 10=#50e898
palette = 11=#e8c850
palette = 12=#5080f0
palette = 13=#b060f8
palette = 14=#40d8e8
palette = 15=#c0c8d8
```

**Step 2: Verify the theme is discoverable**

Run: `~/.config/ghostty/ghostty-random.sh list`
Expected: `electrode-shaper` does NOT appear yet (no matching shader)

**Step 3: Commit**

```bash
git add themes/electrode-shaper
git commit -m "feat: add electrode-shaper color palette"
```

---

### Task 2: Scaffold the shader with noise utilities and CRT artifacts (Layer 1)

**Files:**
- Create: `shaders/electrode-shaper.glsl`

**Step 1: Write the shader file with header, noise utilities, and Layer 1 (CRT artifacts)**

The shader needs:
- File header comment with full theme title
- Constants: `PI`, `GAMMA_HZ`, `GAMMA_AMP` (same convention as other themes)
- `hash21(vec2)` and `noise(vec2)` — same utility functions as feline-homunculus
- `mainImage` function with:
  - UV setup
  - **Barrel distortion**: Apply to UV before any texture sampling. Distort edges outward using quadratic offset from center. Strength ~0.05 — enough to see curvature at screen edges without warping center text.
  - **Chromatic aberration**: Sample R, G, B channels at slightly different UVs (offset ~0.002 at edges, 0 at center). Offset direction = radial from center.
  - **Text detection**: Same as other themes — `smoothstep(0.05, 0.12, luma)`
  - **Scanlines**: `1.0 - 0.15 * mod(floor(fragCoord.y), 2.0)` — darken every other row by 15%

At this point the shader should compile and show: terminal text with visible scanlines, slight edge curvature, and chromatic fringing at corners. No plasma/arcs yet.

```glsl
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
// Noise utilities (same as other themes)
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

    // --- (Layers 2-6 go here in subsequent tasks) ---

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
```

**Step 2: Switch to the new theme and verify it renders**

Run: `~/.config/ghostty/ghostty-random.sh electrode-shaper`

Visually verify: terminal text visible with scanlines, slight barrel curvature at edges, subtle color fringing at corners.

**Step 3: Commit**

```bash
git add shaders/electrode-shaper.glsl
git commit -m "feat: scaffold electrode-shaper shader with CRT artifacts"
```

---

### Task 3: Add Layer 2 — Plasma Field

**Files:**
- Modify: `shaders/electrode-shaper.glsl` (insert between scanlines and text protection)

**Step 1: Implement the plasma field**

Insert after the scanline code, before the Layer 7 comment. The plasma field:
- Three color anchors: violet `vec3(0.56, 0.25, 0.85)`, cyan `vec3(0.13, 0.72, 0.78)`, hot white `vec3(0.9, 0.88, 1.0)`
- Mix between them using slow noise-driven oscillation (~8-12s cycle)
- Mask to edges/corners: `smoothstep(0.3, 0.6, edgeDist)` so center stays clean
- Subtle flickering via high-frequency noise
- Intensity: ~0.08 multiplier (background glow, not overpowering)

```glsl
    // --- Layer 2: Plasma Field ---
    // Unstable plasma cycling through violet, cyan, hot white
    vec3 violet = vec3(0.56, 0.25, 0.85);
    vec3 cyan   = vec3(0.13, 0.72, 0.78);
    vec3 hotWhite = vec3(0.9, 0.88, 1.0);

    // Slow color cycling — three-phase oscillation
    float phase = noise(vec2(time * 0.08, 0.0));
    float phase2 = noise(vec2(time * 0.06, 100.0));
    vec3 plasmaColor = mix(violet, cyan, phase);
    plasmaColor = mix(plasmaColor, hotWhite, phase2 * 0.4);

    // Concentrate at edges — plasma pools against the glass
    float plasmaMask = smoothstep(0.25, 0.55, edgeDist);

    // Organic flicker
    float plasmaFlicker = 0.7 + 0.3 * noise(vec2(time * 2.5, uv.x * 8.0 + uv.y * 8.0));

    color += plasmaColor * plasmaMask * plasmaFlicker * 0.08;
```

**Step 2: Verify visually**

Run: `~/.config/ghostty/ghostty-random.sh electrode-shaper`

Verify: soft colored glow at screen edges that slowly cycles between violet/cyan/white. Center text area stays clean.

**Step 3: Commit**

```bash
git add shaders/electrode-shaper.glsl
git commit -m "feat: add plasma field layer to electrode-shaper"
```

---

### Task 4: Add Layer 3 — Electrode Arcs

**Files:**
- Modify: `shaders/electrode-shaper.glsl` (insert after plasma, before text protection)

**Step 1: Write the electrode arc function and layer**

Add an `electrodeArc` function above `mainImage` and call it in the layer stack. The arcs:
- Use time-cells: divide time into ~4s windows, hash each window to decide if/where an arc fires
- Each arc is a bright line from one edge to the other, with a sine-based "branching" wobble
- Fade in over ~0.1s, hold ~0.2s, fade out ~0.3s
- Thin (smoothstep falloff from a center line)
- Color inherits from current plasma state

```glsl
// Above mainImage:

float electrodeArc(vec2 uv, float time) {
    // Time cell: one potential arc every ~4 seconds
    float cellSize = 4.0;
    float cell = floor(time / cellSize);
    float localTime = fract(time / cellSize);

    // Does this cell fire an arc? ~40% chance
    float fires = step(0.6, hash21(vec2(cell, 0.0)));
    if (fires < 0.5) return 0.0;

    // Arc timing: fade in 0-0.05, hold 0.05-0.12, fade out 0.12-0.2 (of cell)
    float envelope = smoothstep(0.0, 0.05, localTime)
                   * smoothstep(0.2, 0.12, localTime);

    // Arc path: horizontal or vertical based on cell hash
    float orientation = hash21(vec2(cell, 10.0));
    float pathPos = hash21(vec2(cell, 20.0)) * 0.6 + 0.2; // 0.2-0.8 range

    float arcLine;
    if (orientation > 0.5) {
        // Horizontal arc — wobbles along x
        float wobble = sin(uv.x * 15.0 + hash21(vec2(cell, 30.0)) * 6.28) * 0.03;
        arcLine = abs(uv.y - pathPos + wobble);
    } else {
        // Vertical arc
        float wobble = sin(uv.y * 15.0 + hash21(vec2(cell, 40.0)) * 6.28) * 0.03;
        arcLine = abs(uv.x - pathPos + wobble);
    }

    // Thin bright line with glow falloff
    float core = smoothstep(0.008, 0.0, arcLine);    // bright core
    float glow = smoothstep(0.06, 0.0, arcLine) * 0.3; // soft glow

    return (core + glow) * envelope;
}
```

```glsl
    // In mainImage, after plasma:

    // --- Layer 3: Electrode Arcs ---
    float arc = electrodeArc(uv, time);
    vec3 arcColor = mix(plasmaColor, hotWhite, 0.6); // biased toward white-hot
    color += arcColor * arc * 0.35;
```

**Step 2: Verify visually**

Run: `~/.config/ghostty/ghostty-random.sh electrode-shaper`

Wait 10-15 seconds. Verify: occasional bright arcs crackle across the screen (horizontal or vertical), hold briefly, fade. Should see 2-3 in a 15s window.

**Step 3: Commit**

```bash
git add shaders/electrode-shaper.glsl
git commit -m "feat: add electrode arc layer to electrode-shaper"
```

---

### Task 5: Add Layer 4 — EMF Interference

**Files:**
- Modify: `shaders/electrode-shaper.glsl` (insert after arcs, before text protection)

**Step 1: Implement EMF interference bands**

Horizontal noise bands that drift vertically, like analog TV interference.

```glsl
    // --- Layer 4: EMF Interference ---
    float bandY = uv.y * 80.0 + time * 2.0;
    float band = noise(vec2(0.0, bandY)) * noise(vec2(time * 0.5, bandY * 0.3));
    // Occasional bright burst
    float burst = smoothstep(0.7, 0.9, noise(vec2(time * 0.3, uv.y * 2.0)));
    float emf = band * 0.04 + burst * 0.03;
    color += vec3(emf) * plasmaColor;
```

**Step 2: Verify**

Run: `~/.config/ghostty/ghostty-random.sh electrode-shaper`

Verify: subtle horizontal texture/movement in the background. Occasional slightly brighter horizontal band sweeps through.

**Step 3: Commit**

```bash
git add shaders/electrode-shaper.glsl
git commit -m "feat: add EMF interference layer to electrode-shaper"
```

---

### Task 6: Add Layers 5-6 — Vignette and Gamma Entrainment

**Files:**
- Modify: `shaders/electrode-shaper.glsl` (insert after EMF, before text protection)

**Step 1: Implement vignette and gamma**

```glsl
    // --- Layer 5: Vignette (CRT bezel + chamber walls) ---
    float vignetteDist = length(rawUV - 0.5);  // use raw UV, not barrel-distorted
    float vignette = smoothstep(0.75, 0.3, vignetteDist);
    vignette = mix(0.2, 1.0, vignette);  // heavier than other themes — CRT darkens at edges
    color *= vignette;

    // --- Layer 6: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;
```

**Step 2: Verify**

Run: `~/.config/ghostty/ghostty-random.sh electrode-shaper`

Verify: darker edges (heavier than other themes), center text remains bright and readable.

**Step 3: Commit**

```bash
git add shaders/electrode-shaper.glsl
git commit -m "feat: add vignette and gamma entrainment to electrode-shaper"
```

---

### Task 7: Final integration and visual tuning

**Files:**
- Modify: `shaders/electrode-shaper.glsl` (tuning pass)

**Step 1: Switch to theme and visually verify all layers work together**

Run: `~/.config/ghostty/ghostty-random.sh electrode-shaper`

Check:
- [ ] Scanlines visible but not harsh
- [ ] Barrel distortion visible at edges, center text undistorted
- [ ] Chromatic aberration at corners only
- [ ] Plasma glow cycles through colors over ~10s
- [ ] Electrode arcs fire every few seconds, fade smoothly
- [ ] EMF bands provide subtle texture
- [ ] Vignette darkens edges
- [ ] Text is razor-sharp and fully readable
- [ ] No performance issues (smooth 60fps)

**Step 2: Tune any values that feel off** (adjust multipliers, timing, etc.)

**Step 3: Verify theme appears in the random rotation**

Run: `~/.config/ghostty/ghostty-random.sh list`
Expected output includes `electrode-shaper`

**Step 4: Commit the final version**

```bash
git add shaders/electrode-shaper.glsl themes/electrode-shaper
git commit -m "feat: complete electrode-shaper theme — CRT plasma viewport"
```
