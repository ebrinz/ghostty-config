# Feline Homunculus Lost in Tokyo on a Rainy Night — Ghostty Theme Design

## Overview

Complete Ghostty reskin: color theme + GLSL shader evoking a small cat-creature sheltering from rain in a neon-drenched Tokyo alley, staring out through rain-streaked glass. Mixed hot/cold neon palette (pink, amber vs cyan, blue). The feline manifests purely through color — amber predator eyes (cursor), sleek dark fur (background), alert and watchful in a cold neon landscape.

## Approach: "Rain Window"

You're the cat looking out through a rain-streaked window. The screen surface IS the glass. Raindrops streak down, neon signs bleed from the edges, wet pavement reflections pool at the bottom. 40 Hz gamma entrainment carried on the peripheral neon glow.

## Color Theme: "feline-homunculus"

### Core Colors

| Element | Color | Rationale |
|---------|-------|-----------|
| Background | `#0b0e14` | Deep blue-black — Tokyo midnight sky, wet fur |
| Foreground | `#c5cdd9` | Cool silver-gray — rain-washed, reading through mist |
| Cursor | `#f0a500` | Amber cat eye — the predatory glow |
| Cursor text | `#0b0e14` | Matches bg for contrast |
| Selection BG | `#1a2435` | Muted indigo — reflected sky in a puddle |
| Selection FG | `#e8dff0` | Pale lavender — neon bleed on wet skin |

### ANSI Palette

| Slot | Normal | Bright | Concept |
|------|--------|--------|---------|
| 0/8 black | `#0b0e14` | `#2a3040` | Night sky / wet concrete |
| 1/9 red | `#e84a72` | `#ff6b8a` | Hot pink neon / reflection |
| 2/10 green | `#59c98b` | `#7aedaa` | Konbini glow / emerald rain |
| 3/11 yellow | `#f0a500` | `#ffc352` | Amber cat eye / lantern warm |
| 4/12 blue | `#4a9cd6` | `#6fbcf0` | Rain streaks / neon blue |
| 5/13 magenta | `#b07adb` | `#d4a0f5` | Violet neon / purple bloom |
| 6/14 cyan | `#45c8c2` | `#6aeae4` | Teal puddle / electric mint |
| 7/15 white | `#8892a0` | `#c5cdd9` | Mist gray / bright mist |

## Shader: `feline-homunculus.glsl`

Single GLSL shader, single pass, six layers:

### Layer 1: Rain Streaks on Glass
- Procedural rain particles spawning near top, streaking downward
- Thin vertical lines with slight wobble and varied speed/brightness
- Faint trails (water residue on glass)
- Hash-based particle system — lightweight, no per-pixel fbm

### Layer 2: Neon Glow Bleed
- Soft color tints from left (warm: pink/amber) and right (cool: cyan/blue) edges
- Organic noise-driven intensity drift — neon signs flickering off-screen
- Very low opacity edge tinting

### Layer 3: Wet Pavement Reflections
- Bottom 20-25% of screen: rippled horizontal light bands
- Neon colors (pink, cyan, amber) shifting and rippling
- Rain-on-puddle distortion effect
- Smooth fade into clean center

### Layer 4: Vignette
- Dark corners — alley shadows
- Slightly asymmetric (darker top-left, lighter bottom-right near neon)
- Gentle, atmospheric

### Layer 5: 40 Hz Gamma Entrainment
- Subliminal sinusoidal pulse at 40 Hz, ~3.5% amplitude
- Carried on neon bleed and puddle reflections (peripheral vision)
- Rain provides conscious camouflage

### Layer 6: Text Protection
- Luminance-based text detection against `#0b0e14` background
- All effects overwritten with clean texture on text pixels
- Text is always razor-sharp

### Performance
- All procedural — no external textures
- Rain uses hash-based particles, not expensive fbm
- 60fps on integrated GPU

## File Structure

```
~/.config/ghostty/
  config                              # Points to feline-homunculus theme + shader
  shaders/
    street-shaman.glsl                # Previous theme (preserved)
    feline-homunculus.glsl            # New rain window shader
  themes/
    street-shaman                     # Previous theme (preserved)
    feline-homunculus                 # New palette
  docs/plans/
    2026-02-25-feline-homunculus-design.md  # This file
```
