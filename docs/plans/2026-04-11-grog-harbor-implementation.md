# Grog Harbor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a LucasArts SCUMM-era VGA 256-color terminal theme for Ghostty — Melee Island at midnight. Ordered-dither palette quantization, moonlit water ripples, CRT scanlines, and a SCUMM verb-interface shell prompt.

**Architecture:** Follows the established theme pattern: one Ghostty theme file (color palette), three GLSL fragment shaders (full / lite / static), and one zsh prompt script. The shader is built incrementally, starting with the foundation shared by all three variants (dither + scanlines + vignette + text protection = the lite variant), then extending the full shader with ripples, phosphor glow, and torch flicker. The static variant is derived from lite by removing time-dependent code.

**Tech Stack:** Ghostty config, GLSL (Ghostty single-pass fragment shader API), zsh

**Spec:** `docs/plans/2026-04-11-grog-harbor-design.md`

**Testing approach:** This is a visual project. Each task is verified by running Ghostty with the current shader/config and confirming the described effect is visible. There are no unit tests. After each task, commit.

---

### Task 1: Color Theme File

**Files:**
- Create: `themes/grog-harbor`

- [ ] **Step 1: Create the theme palette**

Write the following to `themes/grog-harbor`:

```
background = #0a1228
foreground = #d8c898
cursor-color = #e89838
cursor-text = #0a1228
selection-background = #1e3868
selection-foreground = #f0e0a8

# ANSI Normal (0-7)
palette = 0=#0a1228
palette = 1=#b83820
palette = 2=#48883a
palette = 3=#d89828
palette = 4=#3878b0
palette = 5=#8840a0
palette = 6=#48a8a0
palette = 7=#b8a878

# ANSI Bright (8-15)
palette = 8=#24304e
palette = 9=#d8583c
palette = 10=#68a848
palette = 11=#e8b848
palette = 12=#58a0d8
palette = 13=#a860c0
palette = 14=#68c8c0
palette = 15=#d8c898
```

- [ ] **Step 2: Commit**

```bash
git add themes/grog-harbor
git commit -m "feat: add grog-harbor color theme — VGA 256-color Melee Island palette"
```

---

### Task 2: Shader Foundation — Dither + Scanlines + Vignette + Text Protection + Gamma

This task builds the **full** shader file (`grog-harbor.glsl`) with the foundation layers that will also be the basis for the lite and static variants. The signature ordered-dither quantization is the centerpiece.

**Files:**
- Create: `shaders/grog-harbor.glsl`
- Modify: `config`

- [ ] **Step 1: Create the shader with foundation layers**

Write `shaders/grog-harbor.glsl` containing:

- Standard header comment block (match existing themes — describe the scene: "Melee Island dock at midnight, VGA 256-color dither on a 1992 CRT").
- Constants: `PI`, `GAMMA_HZ = 40.0`, `GAMMA_AMP = 0.035`.
- `hash21` and `noise` utilities (copy from `shaders/deep-drift.glsl` lines 16-31).
- **4×4 Bayer matrix** as a `const float bayer4x4[16]` array with standard ordered-dither values (`0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5`) divided by 16.0.
- **`ditherQuantize(vec3 color, vec2 fragCoord)` function:** samples the Bayer matrix at `ivec2(mod(fragCoord, 4.0))`, adds `(bayerValue - 0.5) / STEPS` to the color, then quantizes each channel by `floor(c * STEPS + 0.5) / STEPS`. Use `STEPS = 5.0` (6 luminance steps per channel — era-correct VGA feel). Return the quantized color.
- **`mainImage(out vec4 fragColor, in vec2 fragCoord)`** function that does:
  1. Sample `iChannel0` at `uv = fragCoord / iResolution.xy`.
  2. Luminance-based text mask: `luma = dot(color, vec3(0.2126, 0.7152, 0.0722))`, `textMask = smoothstep(0.05, 0.12, luma)`.
  3. Save `cleanText = color` for later restore.
  4. Apply `ditherQuantize(color, fragCoord)`.
  5. Scanlines: `color *= 1.0 - 0.12 * mod(floor(fragCoord.y), 2.0)`.
  6. Vignette: compute `vec2 center = uv - 0.5`, `dist = length(center)`, `vignette = smoothstep(0.85, 0.35, dist)`, `vignette = mix(0.60, 1.0, vignette)`, `color *= vignette`.
  7. 40Hz gamma entrainment: `gamma = sin(2.0 * PI * GAMMA_HZ * iTime)`, `peripheryWeight = smoothstep(0.15, 0.5, dist)`, `color *= 1.0 + GAMMA_AMP * gamma * peripheryWeight`.
  8. Clamp color to [0, 1].
  9. Text restore: `color = mix(color, cleanText, textMask)`.
  10. Output `fragColor = vec4(color, 1.0)`.

- [ ] **Step 2: Wire up config to load the theme and shader**

Replace the contents of `config` with:

```
# Grog Harbor
theme = grog-harbor
custom-shader = /Users/crashy/.config/ghostty/shaders/grog-harbor.glsl
custom-shader-animation = true
```

- [ ] **Step 3: Visually verify**

Open Ghostty (or reload if open). Confirm:
- Background is deep navy `#0a1228`.
- Foreground text is parchment-colored and **sharp** (text protection working).
- The background has visible chunky ordered-dither stippling — gradients look "drawn" not smooth.
- Faint horizontal scanlines visible on the background.
- Corners are slightly darker than center (vignette).
- No artifacts, no crashes.

If text is not crisp or dither is bleeding through text, debug the text mask threshold before continuing.

- [ ] **Step 4: Commit**

```bash
git add shaders/grog-harbor.glsl config
git commit -m "feat: add grog-harbor shader foundation — Bayer dither, scanlines, vignette"
```

---

### Task 3: Snapshot Lite Variant

The foundation is the lite variant by definition. Copy it before adding the heavier full-shader layers.

**Files:**
- Create: `shaders/grog-harbor-lite.glsl`

- [ ] **Step 1: Copy the current shader to the lite variant**

```bash
cp shaders/grog-harbor.glsl shaders/grog-harbor-lite.glsl
```

- [ ] **Step 2: Update the header comment in the lite file**

In `shaders/grog-harbor-lite.glsl`, replace the header comment block to say:

```glsl
// grog-harbor-lite.glsl
// Lite variant: Bayer dither + scanlines + vignette + 40Hz gamma + text protection.
// Drops: moonlit water ripples, phosphor glow, chromatic aberration, torch flicker.
// Target: integrated GPU, 60fps with headroom.
```

- [ ] **Step 3: Commit**

```bash
git add shaders/grog-harbor-lite.glsl
git commit -m "feat: add grog-harbor-lite shader variant"
```

---

### Task 4: Full Shader — Moonlit Water Ripples

Add the water ripple layer to `grog-harbor.glsl` (NOT the lite variant). This layer activates below `uv.y ~= 0.35` (bottom third of the screen).

Coordinate convention note: Ghostty's `uv.y = 0` is the bottom of the screen, so "bottom 35%" means `uv.y < 0.35`. Verify this during visual testing — if the ripple appears at the top, invert.

**Files:**
- Modify: `shaders/grog-harbor.glsl`

- [ ] **Step 1: Add a `moonRipple` function**

Add a helper above `mainImage`:

```glsl
// Layer 1: Moonlit water ripples — bottom 35% of screen
// Returns (displacement, highlight) packed as vec2.
vec2 moonRipple(vec2 uv, float t) {
    float zone = smoothstep(0.0, 0.10, 0.35 - uv.y); // 0 above 0.35, 1 well below
    if (zone <= 0.0) return vec2(0.0);

    // Slow horizontal sine bands, phase drifts with time
    float band1 = sin(uv.y * 80.0 + t * 0.6) * 0.5;
    float band2 = sin(uv.y * 140.0 - t * 0.4 + uv.x * 3.0) * 0.3;
    float disp = (band1 + band2) * zone * 0.003; // vertical displacement in uv space

    // Moonlight highlight streaks — brighter bands where the moon reflects
    float streak = sin(uv.y * 30.0 - t * 0.3) * 0.5 + 0.5;
    streak = pow(streak, 4.0);
    float highlight = streak * zone * 0.25;

    return vec2(disp, highlight);
}
```

- [ ] **Step 2: Apply the ripple in `mainImage`**

Insert BEFORE the `ditherQuantize` call (so the ripple is dithered along with everything else):

```glsl
// --- Layer 1: Moonlit water ripples ---
vec2 ripple = moonRipple(uv, iTime);
if (ripple.y > 0.0 || ripple.x != 0.0) {
    // Resample the terminal color with vertical displacement
    vec2 sampleUV = uv + vec2(0.0, ripple.x);
    color = texture(iChannel0, sampleUV).rgb;
    // Add moonlit cyan highlight
    color += vec3(0.15, 0.35, 0.55) * ripple.y;
}
```

**Important constraints for text preservation:**
- The `textMask` and `cleanText` MUST be computed from the ORIGINAL unmodified `uv` sample (not the rippled resample). Confirm the code flow is: (1) sample `cleanText = texture(iChannel0, uv).rgb`, (2) compute `luma` and `textMask` from `cleanText`, (3) THEN apply the ripple block above. Do NOT recompute `textMask` after the ripple.
- The final `color = mix(color, cleanText, textMask)` at the end uses the unmodified sample, so text never shifts with the ripple.

- [ ] **Step 3: Visually verify**

Reload Ghostty. Confirm:
- Bottom third of the screen has visible ripple motion.
- Moonlit cyan streaks are visible in the ripple zone.
- Text in the ripple zone stays sharp and unrippled.
- Top two-thirds look unchanged from the previous task.

- [ ] **Step 4: Commit**

```bash
git add shaders/grog-harbor.glsl
git commit -m "feat: add moonlit water ripples to grog-harbor full shader"
```

---

### Task 5: Full Shader — Phosphor Glow + Chromatic Aberration

**Files:**
- Modify: `shaders/grog-harbor.glsl`

- [ ] **Step 1: Add a chromatic-aberration sampling helper and use it in both sample sites**

Add this helper above `mainImage`:

```glsl
// Chromatic aberration — red drifts outward from screen center
vec3 sampleAberrated(vec2 uv) {
    vec2 dir = normalize(uv - 0.5 + vec2(1e-6));
    float amt = 0.0015;
    float r = texture(iChannel0, uv + dir * amt).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - dir * amt * 0.5).b;
    return vec3(r, g, b);
}
```

Then in `mainImage`, update BOTH sampling sites to use this helper:
1. The initial `color = texture(iChannel0, uv).rgb` becomes `color = sampleAberrated(uv)`.
2. Inside the ripple block from Task 4, `color = texture(iChannel0, sampleUV).rgb` becomes `color = sampleAberrated(sampleUV)`.

The `cleanText = texture(iChannel0, uv).rgb` line stays UNCHANGED — text restore uses a clean, unshifted sample so text never fringes.

- [ ] **Step 2: Add a phosphor bloom after the ripple layer and before dither**

Insert:

```glsl
// --- Layer 4a: Phosphor bloom — soft glow around bright pixels ---
vec3 bloom = vec3(0.0);
float bloomRadius = 0.003;
bloom += texture(iChannel0, uv + vec2( bloomRadius, 0.0)).rgb;
bloom += texture(iChannel0, uv + vec2(-bloomRadius, 0.0)).rgb;
bloom += texture(iChannel0, uv + vec2(0.0,  bloomRadius)).rgb;
bloom += texture(iChannel0, uv + vec2(0.0, -bloomRadius)).rgb;
bloom *= 0.25;
float bloomLuma = dot(bloom, vec3(0.2126, 0.7152, 0.0722));
color += bloom * smoothstep(0.3, 0.8, bloomLuma) * 0.15;
```

- [ ] **Step 3: Visually verify**

Reload Ghostty. Confirm:
- Bright text (parchment foreground) has a subtle warm glow around it.
- Colored cells (e.g. `ls` output with colors) show very subtle color fringing at edges — red edges drift outward.
- Effect is subtle; should not make text look broken or blurry.

- [ ] **Step 4: Commit**

```bash
git add shaders/grog-harbor.glsl
git commit -m "feat: add phosphor bloom and chromatic aberration to grog-harbor"
```

---

### Task 6: Full Shader — Torch Flicker

**Files:**
- Modify: `shaders/grog-harbor.glsl`

- [ ] **Step 1: Add torch flicker after the dither and scanlines, before vignette**

Insert:

```glsl
// --- Layer 5: Torch flicker — warm pulse weighted to top of screen ---
float torchNoise1 = noise(vec2(iTime * 0.7, 0.0));
float torchNoise2 = noise(vec2(iTime * 1.3, 17.0));
float torch = (torchNoise1 * 0.7 + torchNoise2 * 0.3);
float topWeight = smoothstep(0.6, 1.0, uv.y); // strongest near top
float flickerAmp = 0.035 * topWeight;
vec3 torchTint = vec3(1.08, 1.02, 0.92); // warm orange tint
color *= mix(vec3(1.0), torchTint, torch * topWeight);
color *= 1.0 + (torch - 0.5) * flickerAmp;
```

- [ ] **Step 2: Visually verify**

Reload Ghostty. Confirm:
- Top of the screen has a slow, subtle warm pulse visible on the background.
- Pulse is irregular (noise-driven), not periodic.
- Bottom of screen is unaffected.
- Text stays crisp.

- [ ] **Step 3: Commit**

```bash
git add shaders/grog-harbor.glsl
git commit -m "feat: add torch flicker to grog-harbor full shader"
```

---

### Task 7: Static Shader Variant

The static variant is the lite variant with all time-dependent code stripped out.

**Files:**
- Create: `shaders/grog-harbor-static.glsl`

- [ ] **Step 1: Copy lite to static**

```bash
cp shaders/grog-harbor-lite.glsl shaders/grog-harbor-static.glsl
```

- [ ] **Step 2: Remove all `iTime`-dependent code**

In `shaders/grog-harbor-static.glsl`:
- Delete the 40Hz gamma entrainment block entirely (it's the only `iTime` user in the lite variant).
- Update the header comment to:

```glsl
// grog-harbor-static.glsl
// Static variant: Bayer dither + scanlines + vignette + text protection only.
// No animation, no time dependence. For screenshots, recording, motion-averse users.
```

- [ ] **Step 3: Visually verify**

Temporarily point `config` at `grog-harbor-static.glsl`, reload Ghostty. Confirm:
- Dither, scanlines, vignette all visible.
- Absolutely nothing moving or pulsing.
- Text crisp.

Then revert `config` to point back at the full `grog-harbor.glsl` shader.

- [ ] **Step 4: Commit**

```bash
git add shaders/grog-harbor-static.glsl config
git commit -m "feat: add grog-harbor-static shader variant"
```

---

### Task 8: SCUMM Verb Interface Prompt Script

**Files:**
- Create: `prompts/grog-harbor.sh`

- [ ] **Step 1: Create the prompt script**

Write `prompts/grog-harbor.sh`. Structure (modeled on `prompts/night-temple.sh`):

- Header comment block explaining usage: `source ~/.config/ghostty/prompts/grog-harbor.sh`
- Idempotency guard (`_GROG_HARBOR_PROMPT_LOADED`)
- ANSI color definitions (256-color codes matching the palette):
  - `_GH_PARCH=$'\e[38;5;223m'` — parchment (approximates `#d8c898`)
  - `_GH_TORCH=$'\e[38;5;208m'` — torch orange (approximates `#e89838`)
  - `_GH_TEAL=$'\e[38;5;73m'` — dock teal (approximates `#48a8a0`)
  - `_GH_RED=$'\e[38;5;124m'` — brick red for error state (approximates `#b83820`)
  - `_GH_RESET=$'\e[0m'`
- Verb list as an array: `_GH_VERBS=('Look at' 'Open' 'Push' 'Give' 'Talk to' 'Close' 'Pull' 'Use' 'Pick up')`
- Layout constants: row 1 = verbs 0-3, row 2 = verbs 4-8 (5 verbs), with two leading spaces.
- **`_grog_harbor_precmd()` hook that:**
  1. Captures `$?` immediately as the first statement (`local last_exit=$?`).
  2. Picks a random highlighted verb index: `local hl=$(( RANDOM % ${#_GH_VERBS[@]} ))`.
  3. Builds row 1 and row 2 by iterating the verb array; each non-highlighted verb is wrapped in `${_GH_PARCH}` and the highlighted verb in `${_GH_TORCH}`. Separate verbs with 3 spaces.
  4. Checks for git branch: `local branch=$(git symbolic-ref --short HEAD 2>/dev/null)`. If non-empty, append ` ${_GH_TEAL}Walk to ${branch}${_GH_PARCH}` to row 2.
  5. Chooses arrow color: `local arrow_color=${_GH_PARCH}`; if `last_exit != 0`, set `arrow_color=${_GH_RED}`.
  6. Builds line 3: `${arrow_color}»${_GH_RESET} %~ ${arrow_color}◂${_GH_RESET} `
  7. Assembles `PROMPT=$'\n'"${row1}"$'\n'"${row2}"$'\n'"${line3}"`
- Register with zsh precmd_functions array, idempotently (match the pattern in `prompts/night-temple.sh` lines 94-97).

- [ ] **Step 2: Test the prompt in a subshell**

```bash
zsh -c 'source /Users/crashy/.config/ghostty/prompts/grog-harbor.sh && print -P "$PROMPT"'
```

Expected: prints the two verb rows and the `» ~/... ◂` line. One verb in each run should be highlighted in a different color from the others. Running it multiple times should produce different highlighted verbs.

- [ ] **Step 3: Test git-branch injection**

```bash
cd /Users/crashy/.config/ghostty && zsh -c 'source ./prompts/grog-harbor.sh && _grog_harbor_precmd && print -P "$PROMPT"'
```

Expected: the second verb row includes `Walk to master` (or whatever the current branch is) in teal.

- [ ] **Step 4: Test error-state arrow**

```bash
zsh -c 'source /Users/crashy/.config/ghostty/prompts/grog-harbor.sh && (exit 1); _grog_harbor_precmd; print -P "$PROMPT"'
```

Expected: the `»` and `◂` arrows are rendered in brick red instead of parchment.

- [ ] **Step 5: Commit**

```bash
git add prompts/grog-harbor.sh
git commit -m "feat: add grog-harbor SCUMM verb-interface prompt script"
```

---

### Task 9: Final Integration Verification

**Files:**
- (No file changes — verification only)

- [ ] **Step 1: Confirm config points at the full shader**

Check `config` reads:

```
# Grog Harbor
theme = grog-harbor
custom-shader = /Users/crashy/.config/ghostty/shaders/grog-harbor.glsl
custom-shader-animation = true
```

- [ ] **Step 2: Open a fresh Ghostty window and source the prompt**

In the new window:

```bash
source ~/.config/ghostty/prompts/grog-harbor.sh
```

Confirm all of the following simultaneously:
- Deep navy background with chunky Bayer dither stippling
- Moonlit cyan water ripples in the bottom third, animating slowly
- Scanlines across the whole screen
- Subtle torch flicker warming the top
- Vignetted corners
- SCUMM verb interface as prompt, one verb highlighted in torch orange
- `» ~/.config/ghostty ◂` bottom line with teal `Walk to master` verb inserted
- Text is perfectly sharp through all effects

- [ ] **Step 3: Run a command that exits non-zero to confirm red arrows**

```bash
false
```

Expected: the next prompt renders `»` and `◂` in brick red.

- [ ] **Step 4: Test the lite variant**

Temporarily edit `config` to point at `grog-harbor-lite.glsl`, reload, confirm it still looks coherent (no ripples, no flicker, but dither / scanlines / vignette / text protection all present). Revert config.

- [ ] **Step 5: Test the static variant**

Temporarily edit `config` to point at `grog-harbor-static.glsl`, reload, confirm zero motion. Revert config.

- [ ] **Step 6: Final commit (if any tweaks were needed)**

If any tweaks were made during verification, commit them. Otherwise, skip.

```bash
git add -A
git status  # review
git commit -m "fix: grog-harbor verification tweaks" # only if needed
```

---

## Done Criteria

All of these are true:

- `themes/grog-harbor` exists and loads without errors
- `shaders/grog-harbor.glsl`, `shaders/grog-harbor-lite.glsl`, `shaders/grog-harbor-static.glsl` all compile and run in Ghostty
- `prompts/grog-harbor.sh` sources cleanly in zsh and renders the SCUMM verb interface
- Running the full shader shows: dither, scanlines, water ripples, torch flicker, chromatic aberration, vignette, sharp text
- Running the lite variant shows the foundation layers only (no ripples, no flicker)
- Running the static variant shows zero motion
- The prompt highlights a random verb per redraw, shows git branch as `Walk to <branch>`, and turns the arrows red on non-zero exit
- All commits are on master; working tree is clean
