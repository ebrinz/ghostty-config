# Electrode Shaper — Ghostty Theme Design

## Overview

**Full title:** Cyberpunk CRT Electrode Shaper: A Curious Experiment in EMF Effects on Plasma and Psionic Attenuation

**Metaphor:** You're looking THROUGH a CRT viewport into an unstable plasma chamber. Electrodes discharge arcs across the field, plasma cycles through violet/cyan/white as the experiment spirals out of control. The CRT itself shows authentic artifacts — scanlines, barrel distortion, chromatic aberration from the magnetic interference.

**Approach:** Layered composite (same proven pattern as street-shaman and feline-homunculus). Single-pass GLSL, 7 layers.

## Color Theme: `electrode-shaper`

### Core Colors

| Element | Color | Rationale |
|---------|-------|-----------|
| Background | `#08080f` | Near-black with blue cast — unlit CRT glass |
| Foreground | `#c0c8d8` | Cool silver — phosphor text |
| Cursor | `#e0e0ff` | Hot white-blue — electrode tip |
| Cursor text | `#08080f` | Contrast |
| Selection BG | `#1a1a3a` | Deep indigo — plasma afterglow |
| Selection FG | `#e8e0ff` | Pale violet — ionized air |

### ANSI Palette

| Slot | Normal | Bright | Concept |
|------|--------|--------|---------|
| 0/8 black | `#08080f` | `#2a2a3f` | Dead screen / dim phosphor |
| 1/9 red | `#c43060` | `#e84888` | Hot plasma discharge |
| 2/10 green | `#30c878` | `#50e898` | Phosphor afterglow |
| 3/11 yellow | `#c8a830` | `#e8c850` | Electrode spark |
| 4/12 blue | `#3060d0` | `#5080f0` | Plasma core blue |
| 5/13 magenta | `#9040d8` | `#b060f8` | Violet arc discharge |
| 6/14 cyan | `#20b8c8` | `#40d8e8` | Ionized gas |
| 7/15 white | `#8088a0` | `#c0c8d8` | CRT phosphor dim / bright |

## Shader: `electrode-shaper.glsl` — 7 Layers

### Layer 1: CRT Screen Artifacts
- **Scanlines**: Horizontal darkening every other pixel row, ~15% opacity
- **Barrel distortion**: Slight outward bulge at edges — CRT glass curvature. Applied to UV so all subsequent effects also curve
- **Chromatic aberration**: Tiny R/G/B channel offset at screen edges — magnetic field pulling electron beams apart

### Layer 2: Plasma Field
- Slowly cycling background glow shifting between violet, cyan, and hot white
- Layered noise (not fbm) with time-varying color mixing
- Concentrated at edges and corners — plasma pooling against the glass
- Color cycle period ~8-12 seconds

### Layer 3: Electrode Arcs
- Bright filaments crackling between screen edges (left/right or top/bottom)
- Hash-based: each arc lives in a time-cell, appears ~0.3s, fades
- Thin, bright, slightly branching (simplified Lichtenberg figures)
- Every 3-6 seconds — sparse enough to surprise, not distract
- Color matches current plasma state

### Layer 4: EMF Interference
- Subtle horizontal noise bands drifting vertically — analog TV interference
- Very low opacity, provides texture and movement
- Occasional brighter band (EMF burst)

### Layer 5: Vignette
- Dark edges — CRT bezel + plasma chamber walls through the glass
- Slightly heavier than other themes (CRTs naturally darken at edges)

### Layer 6: 40 Hz Gamma Entrainment
- Subliminal 3.5% sinusoidal modulation weighted to periphery
- Carried on plasma glow and electrode afterglow
- Same convention as all themes

### Layer 7: Text Protection
- Luminance-based text mask, all effects overwritten on text pixels
- Text stays razor-sharp through all CRT artifacts

## Performance
- All procedural, no external textures
- Arcs use hash-based particles, not expensive fbm
- CRT distortion is simple UV math
- Target: 60fps on integrated GPU

## File Structure

```
~/.config/ghostty/
  themes/electrode-shaper          # Color palette
  shaders/electrode-shaper.glsl    # CRT + plasma shader
  docs/plans/
    2026-02-25-electrode-shaper-design.md  # This file
```
