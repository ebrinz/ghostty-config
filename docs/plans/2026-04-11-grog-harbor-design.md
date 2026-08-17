# Grog Harbor — Ghostty Theme Design

## Overview

**Full title:** Grog Harbor: Melee Island Dock, Midnight, VGA 256-Color

**Metaphor:** You're running a SCUMM-engine adventure game on a 1992 VGA monitor. The scene is Melee Island, midnight on the dock — the opening of The Secret of Monkey Island. Torches flicker somewhere offscreen, the moon ripples on black water, and every color on the screen is quantized to a 256-color palette via ordered Bayer dither. The CRT hums. You half expect a verb interface to materialize at the bottom of the screen. (It does.)

**Approach:** Layered composite shader (same proven pattern as deep-drift / street-shaman / electrode-shaper). Single-pass GLSL. Plus a zsh prompt script that renders a SCUMM verb interface as your PS1.

**The signature move:** Ordered-dither palette quantization across the whole screen. Gradients go chunky. It looks *drawn*, not rendered. This is the one aesthetic choice that makes the theme unmistakable.

## Color Theme: `grog-harbor`

### Core Colors

| Element | Color | Rationale |
|---|---|---|
| Background | `#0a1228` | Deep navy — midnight Caribbean sky over Melee Island |
| Foreground | `#d8c898` | Bone parchment — SCUMM dialogue text color |
| Cursor | `#e89838` | Torch flame orange — the one warm point in the scene |
| Cursor text | `#0a1228` | Contrast against cursor |
| Selection BG | `#1e3868` | Moonlit water — the reflection band |
| Selection FG | `#f0e0a8` | Hot parchment — selected dialogue |

### ANSI Palette

Leans into VGA 256-color constraints: muted hues, limited saturation range, brights are the same hues pushed one notch — the way a real era-correct palette would be built, not modern gradient picks.

| Slot | Normal | Bright | Concept |
|---|---|---|---|
| 0/8 black | `#0a1228` | `#24304e` | Midnight sky / deep shadow |
| 1/9 red | `#b83820` | `#d8583c` | Brick red — ship hull, Governor's mansion roof |
| 2/10 green | `#48883a` | `#68a848` | Swamp green — Melee jungle foliage |
| 3/11 yellow | `#d89828` | `#e8b848` | Torch gold — flame and lamp light |
| 4/12 blue | `#3878b0` | `#58a0d8` | Moonlit cyan — water highlight |
| 5/13 magenta | `#8840a0` | `#a860c0` | Voodoo purple — the voodoo lady's shop |
| 6/14 cyan | `#48a8a0` | `#68c8c0` | Dock teal — weathered copper fittings |
| 7/15 white | `#b8a878` | `#d8c898` | Dim / bright parchment |

## Shader: `grog-harbor.glsl` — 7 Layers

### Layer 1: Moonlit Water Ripples (Bottom ~35%)
- Horizontal sine bands with slow phase drift, concentrated in the bottom third of the screen
- Displacement reads the base terminal color beneath and offsets it vertically 1-3 pixels
- Moonlight streaks: brighter cyan bands where the virtual moon reflects, modulated by a second slower sine
- Falls off smoothly near the top of the ripple zone so it doesn't have a hard seam
- Ripple speed is slow — this is ambience, not motion

### Layer 2: Ordered-Dither Palette Quantization (Full Screen)
- **This is the signature layer.** Every output pixel snapped to a limited luminance ladder via a 4×4 Bayer matrix
- Quantization ladder: 5-6 luminance steps per channel (approximates VGA 256-color output)
- Applied after water ripples so the ripples themselves look dithered
- Applied before text protection so text stays crisp
- The Bayer pattern is fixed in screen space (not worldspace) — this is what makes it read as "drawn on a CRT" rather than "animated"

### Layer 3: CRT Scanlines
- Subtle horizontal scanlines, ~12% darkening every other row
- Thinner than deep-drift — VGA monitors were sharper than a dying 30-year-old tube
- Fixed in screen space

### Layer 4: Phosphor Glow + Chromatic Aberration
- Mild warm shift across the whole screen
- Red channel drifts 0.5-1 pixel outward from screen center (very subtle)
- Soft bloom around bright pixels — flame and parchment glow slightly

### Layer 5: Torch Flicker
- Slow irregular warm luminance pulse, 2-4% amplitude
- Weighted to the top edge of the screen (torch is offscreen above)
- Uses noise-driven envelope, not periodic, so it feels organic
- Subtly warms the top 20% of the screen as it pulses

### Layer 6: Vignette
- Gentle corner darkening, corners drop to ~60% brightness
- This is CRT curvature, not hardware decay — don't overdo it
- Symmetric, no asymmetric damage pattern

### Layer 7: 40Hz Gamma Entrainment + Text Protection
- Subliminal 3.5% sinusoidal modulation weighted to periphery (consistent with other themes)
- Luminance-based text mask: text pixels bypass ripples, dither, flicker, aberration
- Text stays razor-sharp. Only the "background scene" gets the VGA treatment.

## Shader Variants

### `grog-harbor-lite.glsl`
- Dither quantization + scanlines + vignette + text protection only
- No ripples, no flicker, no chromatic aberration
- Target: integrated GPU at 60fps with headroom

### `grog-harbor-static.glsl`
- Lite, minus any time-based modulation
- Zero animation — everything is deterministic per pixel
- For recording, screenshots, or users who dislike motion

## Shell Prompt: `prompts/grog-harbor.sh`

A sourceable zsh script that renders a SCUMM verb interface as the prompt.

### Layout

```
 Look at   Open    Push    Give
 Talk to   Close   Pull    Use    Pick up
» ~/config ◂
```

- Two rows of verbs in parchment foreground (`#d8c898`)
- One verb per prompt is randomly highlighted in torch orange (`#e89838`) as if the mouse is hovering it
- The highlighted verb rotates on each prompt redraw (new random pick per precmd)
- Bottom line: `»` + current directory + `◂` — the SCUMM selection arrows bracketing the active "object"
- Git branch appears as an extra verb slot when inside a repo, prefixed: `Walk to <branch>` (rendered in dock teal `#48a8a0`)
- Error exit status: the `»` arrow on the bottom line turns brick red (`#b83820`)

### Implementation Notes
- Pure zsh, uses `precmd` hook to regenerate the highlighted verb index
- Uses 256-color ANSI escape codes matching the theme palette so it tracks if the user swaps themes later
- Verb list is fixed (9 verbs: Look at, Open, Push, Give, Talk to, Close, Pull, Use, Pick up)
- The Walk to <branch> verb is conditional — only rendered inside a git work tree

## Performance
- All procedural, no external textures
- Dither uses a static 4×4 Bayer matrix sampled by `gl_FragCoord`
- Ripples are two sine lookups, not fbm
- Target: 60fps on integrated GPU for the full shader

## File Structure

```
~/.config/ghostty/
  themes/grog-harbor                       # Color palette
  shaders/grog-harbor.glsl                 # Full shader — 7 layers
  shaders/grog-harbor-lite.glsl            # Reduced shader
  shaders/grog-harbor-static.glsl          # No animation
  prompts/grog-harbor.sh                   # SCUMM verb interface PS1
  docs/plans/
    2026-04-11-grog-harbor-design.md       # This file
```
