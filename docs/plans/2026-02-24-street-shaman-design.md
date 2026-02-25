# Street Shaman: Fighting Demons with Magic — Ghostty Theme Design

## Overview

Custom Ghostty configuration combining a neon-green occult hacker color scheme ("Sigil") with a ritual fire + smoke GLSL shader at medium intensity.

## Color Scheme: "Sigil"

Near-black base with sickly neon greens, toxic teals, and muted accents evoking occult terminal runes glowing in darkness.

- **Background:** `#0a0a0f` (void black, slight blue undertone)
- **Foreground:** `#b8c4b8` (desaturated pale green)
- **Cursor:** `#00ff41` (full neon green)
- **Selection BG:** `#1a3a1a` (dark forest green)
- **Selection FG:** `#e0ffe0` (bright pale green)

### ANSI Palette

| Index | Normal | Bright | Theme |
|-------|--------|--------|-------|
| 0/8 (black) | `#0a0a0f` | `#3a4a3a` | Void / shadow |
| 1/9 (red) | `#8b1a1a` | `#c43c3c` | Dried / fresh blood |
| 2/10 (green) | `#00ff41` | `#39ff14` | Neon sigil / active sigil |
| 3/11 (yellow) | `#9b8a2f` | `#d4a017` | Tarnished / molten gold |
| 4/12 (blue) | `#2a6e4f` | `#3cb99e` | Spirit water / spirit flame |
| 5/13 (magenta) | `#6b2fa5` | `#9b59b6` | Arcane energy / power surge |
| 6/14 (cyan) | `#1abc9c` | `#2ecc71` | Ward glow / bright ward |
| 7/15 (white) | `#8a9a8a` | `#c8d8c8` | Smoke gray / pale smoke |

## Shader: `street-shaman.glsl`

Single unified GLSL shader with three layered effects:

### 1. Heat Distortion (base layer)
- Sine-wave UV displacement, stronger at screen bottom (heat rises)
- Slow organic oscillation via `iTime`
- ~2-3px amplitude — visible but text stays sharp

### 2. Edge Flicker (accent layer)
- Breathing vignette with noise-driven brightness variation
- Firelight shadow effect at screen periphery
- Center stays stable for readability

### 3. Smoke Haze (atmosphere layer)
- Fractal noise (fBm) creating slow-drifting smoke wisps
- Very low opacity (~0.03-0.05), green-tinted
- Drifts upward-right like incense smoke

### Architecture
- Single shader file, single render pass
- All effects use simple math (sin, noise, fBm)
- One texture sample of terminal frame
- 60fps on any modern GPU

### Readability
- Effects concentrated at edges and background
- Central text area has minimal distortion
- Heat shimmer amplitude kept below text-blurring threshold

## File Structure

```
~/.config/ghostty/
  config                           # Main config file
  shaders/
    street-shaman.glsl             # Unified shader
  themes/
    street-shaman                  # Color scheme file
```
