# Feline Homunculus Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Street Shaman Ghostty config with a new "Feline Homunculus Lost in Tokyo on a Rainy Night" theme and shader — rain-streaked glass, neon bleeds, wet pavement reflections, 40 Hz entrainment, crisp text.

**Architecture:** Three files — a Ghostty theme file (color palette), a GLSL custom shader (rain window effect with 6 layers), and the main config pointing to both. The shader is a single-pass fragment shader using Ghostty's `iChannel0` (terminal texture), `iTime`, and `iResolution` uniforms.

**Tech Stack:** Ghostty terminal config format, GLSL (OpenGL Shading Language), procedural noise functions.

---

### Task 1: Create the Color Theme File

**Files:**
- Create: `~/.config/ghostty/themes/feline-homunculus`
- Reference: `~/.config/ghostty/themes/street-shaman` (existing format example)

**Step 1: Write the theme file**

```
background = #0b0e14
foreground = #c5cdd9
cursor-color = #f0a500
cursor-text = #0b0e14
selection-background = #1a2435
selection-foreground = #e8dff0

# ANSI Normal (0-7)
palette = 0=#0b0e14
palette = 1=#e84a72
palette = 2=#59c98b
palette = 3=#f0a500
palette = 4=#4a9cd6
palette = 5=#b07adb
palette = 6=#45c8c2
palette = 7=#8892a0

# ANSI Bright (8-15)
palette = 8=#2a3040
palette = 9=#ff6b8a
palette = 10=#7aedaa
palette = 11=#ffc352
palette = 12=#6fbcf0
palette = 13=#d4a0f5
palette = 14=#6aeae4
palette = 15=#c5cdd9
```

**Step 2: Verify the file exists and has correct format**

Run: `cat ~/.config/ghostty/themes/feline-homunculus`
Expected: 27 lines, same format as street-shaman theme.

---

### Task 2: Write the Shader — Noise Utilities and Rain Streaks (Layer 1)

**Files:**
- Create: `~/.config/ghostty/shaders/feline-homunculus.glsl`

**Step 1: Write the shader file with constants, noise functions, and rain layer**

The complete shader is written as a single file across Tasks 2-4. Start with the foundation:

```glsl
// Feline Homunculus: Lost in Tokyo on a Rainy Night
// Rain window shader for Ghostty
// Layers: rain streaks, neon bleed, wet reflections, vignette, 40Hz entrainment, text protection

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// --- Noise utilities ---

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
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

// --- Rain streaks on glass ---
// Hash-based particle system: each rain drop is a cell in a grid.
// Cheap — no fbm needed.

float rainStreak(vec2 uv, float time) {
    float rain = 0.0;

    // Two layers of rain at different scales/speeds for depth
    for (int layer = 0; layer < 2; layer++) {
        float scale = (layer == 0) ? 30.0 : 50.0;
        float speed = (layer == 0) ? 1.2 : 1.8;
        float brightness = (layer == 0) ? 1.0 : 0.5;  // far layer is dimmer

        vec2 grid = uv * vec2(scale, 3.0);
        grid.y -= time * speed;

        vec2 cellId = floor(grid);
        vec2 cellUV = fract(grid);

        // Random offset per cell so drops don't align in a grid
        float xOffset = hash21(cellId) * 0.8 - 0.4;
        float dropSpeed = hash21(cellId + 100.0);

        // Only some cells have drops (sparse rain)
        float hasDrop = step(0.65, hash21(cellId + 200.0));

        // Drop shape: thin vertical line
        float xDist = abs(cellUV.x - 0.5 + xOffset);
        float drop = smoothstep(0.025, 0.01, xDist);

        // Vertical extent — shorter drops at top, longer streaks as they fall
        float yStretch = cellUV.y;
        drop *= smoothstep(0.0, 0.15, yStretch) * smoothstep(1.0, 0.7, yStretch);

        // Slight wobble
        float wobble = sin(cellUV.y * 15.0 + hash21(cellId) * 6.28) * 0.005;
        xDist = abs(cellUV.x - 0.5 + xOffset + wobble);
        drop = max(drop, smoothstep(0.02, 0.008, xDist) * yStretch);

        rain += drop * hasDrop * brightness;
    }

    return clamp(rain, 0.0, 1.0);
}
```

**Step 2: Verify file was created**

Run: `head -60 ~/.config/ghostty/shaders/feline-homunculus.glsl`
Expected: Constants, noise functions, and rainStreak function present.

---

### Task 3: Write the Shader — Main Function Layers 1-4

**Files:**
- Modify: `~/.config/ghostty/shaders/feline-homunculus.glsl` (append)

**Step 1: Append the mainImage function with layers 1-4**

Append after the rainStreak function:

```glsl

// --- Main ---

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;
    float aspect = iResolution.x / iResolution.y;

    // Clean sample for text protection
    vec4 clean = texture(iChannel0, uv);

    // Text detection — background is #0b0e14 (luma ~0.05)
    float luma = dot(clean.rgb, vec3(0.299, 0.587, 0.114));
    float textMask = smoothstep(0.05, 0.12, luma);

    // Base terminal color
    vec4 color = clean;

    // Geometry helpers
    vec2 center = uv - 0.5;
    float dist = length(center);

    // --- Layer 1: Rain Streaks on Glass ---
    float rain = rainStreak(uv, time);
    // Rain is a cool white-blue, very subtle
    vec3 rainColor = vec3(0.6, 0.75, 0.9);
    color.rgb += rainColor * rain * 0.06;

    // --- Layer 2: Neon Glow Bleed ---
    // Warm from left (pink/amber), cool from right (cyan/blue)
    // Organic flickering via noise-modulated intensity
    float leftGlow = smoothstep(0.35, 0.0, uv.x);
    float rightGlow = smoothstep(0.65, 1.0, uv.x);

    float flickerL = noise(vec2(time * 1.5, uv.y * 3.0));
    float flickerR = noise(vec2(time * 1.2 + 50.0, uv.y * 2.5));

    // Warm side: pink + amber
    vec3 warmNeon = mix(
        vec3(0.91, 0.29, 0.45),  // #e84a72 hot pink
        vec3(0.94, 0.65, 0.0),   // #f0a500 amber
        noise(vec2(time * 0.3, uv.y * 2.0))
    );
    // Cool side: cyan + blue
    vec3 coolNeon = mix(
        vec3(0.27, 0.78, 0.76),  // #45c8c2 teal
        vec3(0.29, 0.61, 0.84),  // #4a9cd6 blue
        noise(vec2(time * 0.25 + 30.0, uv.y * 1.8))
    );

    color.rgb += warmNeon * leftGlow * flickerL * 0.08;
    color.rgb += coolNeon * rightGlow * flickerR * 0.08;

    // --- Layer 3: Wet Pavement Reflections (bottom) ---
    float puddleZone = smoothstep(0.3, 0.0, uv.y);  // bottom 30%, strongest at very bottom

    // Ripple distortion — rain hitting puddle
    float ripple1 = sin(uv.x * 40.0 + time * 2.0 + noise(uv * 10.0 + time) * 5.0) * 0.5 + 0.5;
    float ripple2 = sin(uv.x * 25.0 - time * 1.5 + noise(uv * 8.0 + time * 0.7) * 4.0) * 0.5 + 0.5;
    float ripples = (ripple1 + ripple2) * 0.5;

    // Reflected neon colors shift and blend in the puddle
    vec3 puddleColor = mix(warmNeon, coolNeon, sin(uv.x * 3.0 + time * 0.4) * 0.5 + 0.5);
    puddleColor = mix(puddleColor, vec3(0.94, 0.65, 0.0), ripples * 0.3);  // amber lantern ripples

    color.rgb += puddleColor * puddleZone * ripples * 0.07;

    // --- Layer 4: Vignette ---
    // Asymmetric: darker top-left (deep alley), lighter bottom-right (neon spill)
    vec2 vignetteCenter = vec2(0.55, 0.45);  // offset toward bottom-right
    float vignetteDist = length((uv - vignetteCenter) * vec2(1.0, aspect * 0.7));
    float vignette = smoothstep(0.8, 0.35, vignetteDist);
    color.rgb *= mix(0.3, 1.0, vignette);
```

**Step 2: Verify the mainImage function is started correctly**

Run: `grep -n "Layer" ~/.config/ghostty/shaders/feline-homunculus.glsl`
Expected: Lines showing Layer 1 through Layer 4 comments.

---

### Task 4: Write the Shader — Layers 5-6 and Close

**Files:**
- Modify: `~/.config/ghostty/shaders/feline-homunculus.glsl` (append)

**Step 1: Append layers 5-6 and close the function**

Append after Layer 4:

```glsl

    // --- Layer 5: 40 Hz Gamma Entrainment ---
    // Subliminal sinusoidal pulse at gamma frequency.
    // Carried on the neon bleed and puddle reflections (peripheral vision).
    // Rain provides conscious camouflage.
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float gammaModulation = 1.0 + gamma * GAMMA_AMP;
    float gammaZone = smoothstep(0.15, 0.5, dist);
    color.rgb *= mix(1.0, gammaModulation, gammaZone);

    // --- Layer 6: Text Protection ---
    // All atmosphere on background only. Text stays razor-sharp.
    color.rgb = mix(color.rgb, clean.rgb, textMask);

    fragColor = color;
}
```

**Step 2: Verify shader is complete and well-formed**

Run: `tail -20 ~/.config/ghostty/shaders/feline-homunculus.glsl`
Expected: Layers 5-6, closing brace, no syntax issues visible.

Run: `grep -c "}" ~/.config/ghostty/shaders/feline-homunculus.glsl`
Expected: Braces should be balanced. Count opening and closing.

---

### Task 5: Update Ghostty Config

**Files:**
- Modify: `~/.config/ghostty/config`

**Step 1: Update config to point to new theme and shader**

Replace full contents with:

```
# Feline Homunculus: Lost in Tokyo on a Rainy Night
theme = feline-homunculus
custom-shader = /Users/crashy/.config/ghostty/shaders/feline-homunculus.glsl
custom-shader-animation = true
```

**Step 2: Verify config is correct**

Run: `cat ~/.config/ghostty/config`
Expected: 4 lines — comment, theme, shader path, animation flag.

---

### Task 6: Visual Verification

**Step 1: Reload Ghostty and verify**

Relaunch Ghostty (or open a new window) to pick up the new config.

Check:
- [ ] Background is deep blue-black (#0b0e14), not the old void-black
- [ ] Cursor is amber, not green
- [ ] Rain streaks are visible — thin lines drifting down the screen
- [ ] Left edge has warm pink/amber glow
- [ ] Right edge has cool cyan/blue glow
- [ ] Bottom of screen has rippled neon reflections
- [ ] Text is razor-sharp — no fading, no color tinting on characters
- [ ] Vignette darkens corners without crushing center
- [ ] Animation is smooth (no stuttering)

**Step 2: Tweak if needed**

If rain is too bright/dim: adjust `rain * 0.06` multiplier in Layer 1.
If neon bleed is too strong: adjust `* 0.08` multipliers in Layer 2.
If puddle reflections are too much: adjust `* 0.07` multiplier in Layer 3.
If vignette is too dark: adjust `mix(0.3, 1.0, vignette)` — raise 0.3 to lighten corners.
