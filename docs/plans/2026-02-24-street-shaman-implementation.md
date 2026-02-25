# Street Shaman Ghostty Theme — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Configure Ghostty with a "street shaman: fighting demons with magic" aesthetic — occult neon-green color scheme + ritual fire/smoke shader.

**Architecture:** Three files: a Ghostty theme file defining the "Sigil" color palette, a single unified GLSL shader combining heat distortion, edge flicker, and smoke haze, and a main config file tying them together.

**Tech Stack:** Ghostty terminal config format, GLSL (Shadertoy-compatible uniforms)

---

### Task 1: Create the "Sigil" Color Theme

**Files:**
- Create: `~/.config/ghostty/themes/street-shaman`

**Step 1: Create the themes directory**

Run: `mkdir -p ~/.config/ghostty/themes`

**Step 2: Write the theme file**

Ghostty theme files are plain key-value configs (no file extension). Create `~/.config/ghostty/themes/street-shaman` with this exact content:

```
background = #0a0a0f
foreground = #b8c4b8
cursor-color = #00ff41
cursor-text = #0a0a0f
selection-background = #1a3a1a
selection-foreground = #e0ffe0

# ANSI Normal (0-7)
palette = 0=#0a0a0f
palette = 1=#8b1a1a
palette = 2=#00ff41
palette = 3=#9b8a2f
palette = 4=#2a6e4f
palette = 5=#6b2fa5
palette = 6=#1abc9c
palette = 7=#8a9a8a

# ANSI Bright (8-15)
palette = 8=#3a4a3a
palette = 9=#c43c3c
palette = 10=#39ff14
palette = 11=#d4a017
palette = 12=#3cb99e
palette = 13=#9b59b6
palette = 14=#2ecc71
palette = 15=#c8d8c8
```

**Step 3: Verify the file exists and is well-formed**

Run: `cat ~/.config/ghostty/themes/street-shaman`
Expected: The theme content above, no syntax errors.

---

### Task 2: Write the Street Shaman GLSL Shader

**Files:**
- Create: `~/.config/ghostty/shaders/street-shaman.glsl`

**Step 1: Create the shaders directory**

Run: `mkdir -p ~/.config/ghostty/shaders`

**Step 2: Write the shader file**

Create `~/.config/ghostty/shaders/street-shaman.glsl` with the full GLSL shader. The shader must:

1. Sample the terminal texture at UV coordinates
2. Apply heat distortion: sine-wave UV displacement, stronger at bottom, ~2-3px amplitude, slow oscillation via `iTime`
3. Apply edge flicker: breathing vignette using noise, firelight at periphery, center stays stable
4. Apply smoke haze: fractal noise (fBm) with 4-5 octaves, green-tinted (`vec3(0.0, 0.15, 0.05)`), low opacity (0.03-0.05), drifts upward-right

Key implementation details:
- Use Shadertoy-compatible interface: `void mainImage(out vec4 fragColor, in vec2 fragCoord)`
- Uniforms available: `iTime`, `iResolution`, `iChannel0` (terminal texture)
- Hash-based noise function (no external textures needed)
- fBm built from the noise function with 5 octaves
- Heat distortion displacement: `sin(uv.y * 15.0 + iTime * 0.8) * (1.0 - uv.y) * 0.002`
- Vignette flicker: multiply by `smoothstep(0.0, 0.4, ...)` with noise-modulated edges
- Smoke: additive blend of green-tinted fBm noise at ~0.04 opacity, UV scrolled by `iTime * 0.02`

```glsl
// Street Shaman: Fighting Demons with Magic
// Ritual fire + smoke shader for Ghostty
// Effects: heat distortion, edge flicker, smoke haze

// --- Noise functions ---

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
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

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// --- Main ---

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // --- 1. Heat Distortion ---
    // Sine-wave displacement, stronger at bottom (heat rises)
    float heatStrength = (1.0 - uv.y) * 0.002;
    float distortX = sin(uv.y * 15.0 + time * 0.8) * heatStrength;
    float distortY = cos(uv.x * 12.0 + time * 0.6) * heatStrength * 0.5;
    vec2 distortedUV = uv + vec2(distortX, distortY);

    // Clamp to prevent sampling outside the texture
    distortedUV = clamp(distortedUV, 0.0, 1.0);

    // Sample the terminal texture with distortion applied
    vec4 color = texture(iChannel0, distortedUV);

    // --- 2. Edge Flicker ---
    // Breathing vignette with noise-driven firelight
    vec2 center = uv - 0.5;
    float dist = length(center);

    // Base vignette
    float vignette = smoothstep(0.7, 0.3, dist);

    // Noise-driven flicker at edges
    float flickerNoise = noise(vec2(time * 2.0, uv.y * 5.0));
    float flicker = mix(0.85, 1.0, flickerNoise);

    // Apply vignette + flicker (edges darken and flicker, center stays bright)
    float edgeFactor = mix(flicker * 0.7, 1.0, vignette);
    color.rgb *= edgeFactor;

    // --- 3. Smoke Haze ---
    // Fractal noise smoke drifting upward-right, green-tinted
    vec2 smokeUV = uv * 3.0;
    smokeUV.y -= time * 0.02;  // drift upward
    smokeUV.x += time * 0.01;  // drift right

    float smoke = fbm(smokeUV);
    // Second layer at different scale for depth
    float smoke2 = fbm(smokeUV * 1.8 + vec2(time * 0.015, -time * 0.01));
    float smokeFinal = (smoke + smoke2) * 0.5;

    // Green-tinted smoke, very low opacity
    vec3 smokeColor = vec3(0.0, 0.15, 0.05);
    color.rgb += smokeColor * smokeFinal * 0.04;

    fragColor = color;
}
```

**Step 3: Verify the file exists**

Run: `cat ~/.config/ghostty/shaders/street-shaman.glsl | head -5`
Expected: First 5 lines of the shader file.

---

### Task 3: Write the Ghostty Config

**Files:**
- Create: `~/.config/ghostty/config`

**Step 1: Write the config file**

Create `~/.config/ghostty/config` with:

```
# Street Shaman: Fighting Demons with Magic
theme = street-shaman
custom-shader = /Users/crashy/.config/ghostty/shaders/street-shaman.glsl
custom-shader-animation = true
```

Note: `custom-shader-animation = true` is required for `iTime` to advance (enables animated shaders). The shader path must be absolute.

**Step 2: Verify the config**

Run: `cat ~/.config/ghostty/config`
Expected: The config content above.

---

### Task 4: Verify and Test

**Step 1: Verify all files exist**

Run: `ls -la ~/.config/ghostty/config ~/.config/ghostty/themes/street-shaman ~/.config/ghostty/shaders/street-shaman.glsl`
Expected: All three files listed.

**Step 2: Open a new Ghostty window to test**

The user should open a new Ghostty terminal window (or reload config). The theme should apply immediately and the shader should start animating.

**Step 3: Visual check**

Verify:
- Background is near-black void (`#0a0a0f`)
- Text is desaturated pale green
- Cursor is neon green
- Heat shimmer is visible at bottom of screen
- Edges flicker subtly like firelight
- Faint green smoke wisps drift across the terminal
- Text in the center is fully readable

**Step 4: Tune if needed**

If effects are too strong/weak, adjust these values in the shader:
- Heat: `0.002` multiplier (increase for more distortion)
- Flicker: `0.7` in `flicker * 0.7` (decrease for darker edges)
- Smoke: `0.04` opacity multiplier (increase for denser smoke)
