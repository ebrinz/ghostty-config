# Night Temple — Egyptian Temple Theme Design

**Date:** 2026-03-17
**Status:** Draft

## Overview

An Ancient Egyptian night ritual theme for Ghostty. Deep indigo/gold/turquoise palette inspired by Tutankhamun's death mask and lapis lazuli. Full-immersion hieroglyphic prompt using real Unicode Egyptian glyphs from the Heiroglyphy project dictionary. Shader simulates torchlit stone temple open to the night sky, with Nile reflections at the base.

## Color Palette

Night ritual: deep indigo base, gold accents, lapis lazuli and turquoise highlights.

| Role | Hex | Name |
|------|-----|------|
| background | `#0a0b14` | Deep temple indigo |
| foreground | `#e8d5a3` | Pale gold |
| palette 0 (black) | `#1a1b2e` | Temple stone |
| palette 1 (red) | `#c44a2e` | Red ochre |
| palette 2 (green) | `#2e9e6e` | Malachite |
| palette 3 (yellow) | `#d4a634` | Gold leaf |
| palette 4 (blue) | `#2e5fa8` | Lapis lazuli |
| palette 5 (magenta) | `#8e3ea0` | Tyrian purple |
| palette 6 (cyan) | `#3eb8a8` | Turquoise faience |
| palette 7 (white) | `#c8c0b0` | Limestone |
| palette 8 (bright black) | `#3a3b5e` | Deep stone |
| palette 9 (bright red) | `#e86a4e` | Scarab red |
| palette 10 (bright green) | `#4ec88e` | Emerald |
| palette 11 (bright yellow) | `#f0c848` | Sun gold |
| palette 12 (bright blue) | `#4e8ee8` | Sky lapis |
| palette 13 (bright magenta) | `#b85ec8` | Amethyst |
| palette 14 (bright cyan) | `#5ed8c8` | Bright faience |
| palette 15 (bright white) | `#e8e0d0` | Pure limestone |

## Shader: `night-temple.glsl`

5 composited layers + text protection. Single-pass fragment shader. Moderate GPU cost (comparable to feline-homunculus — no fbm, hash-based noise only).

### Layer 1: Torch Flicker

Two wall-mounted brazier light sources, one on each side of the terminal.

- Left torch: warm amber `vec3(0.95, 0.65, 0.20)` radiating from `uv.x = 0.0`
- Right torch: slightly cooler gold `vec3(0.90, 0.55, 0.15)` radiating from `uv.x = 1.0`
- Each uses `noise(vec2(time * 3.0, ...))` for organic flicker rhythm (same pattern as street-shaman's firelight)
- Fade: `smoothstep(0.35, 0.0, uv.x)` for left, `smoothstep(0.65, 1.0, uv.x)` for right
- Flicker modulation: `0.7 + 0.3 * noise(...)` per side, independent seeds
- Intensity: `0.08` multiplier (matches neon bleed intensity from feline-homunculus)
- 2 noise calls total

### Layer 2: Stone Vignette

Aggressive corner darkening — terminal is carved into a recessed stone niche.

- Center offset: `vec2(0.50, 0.48)` — slightly high, as if looking up at a wall carving
- Smoothstep range: `smoothstep(0.75, 0.20, dist)` — tighter than other themes for stronger effect
- Floor: `mix(0.10, 1.0, vignette)` — corners go very dark (0.10 vs typical 0.2-0.3)
- 0 noise calls

### Layer 3: Starfield

Sparse twinkling stars visible through the open temple roof (upper 40%).

- Hash-based star placement: `hash21(floor(uv * starDensity))` with density ~400
- Sparsity gate: `step(0.985, hash)` — only ~1.5% of cells contain a star
- Brightness: slow twinkle via `0.5 + 0.5 * sin(time * twinkleSpeed + hash * 6.28)` where `twinkleSpeed` varies per star (0.5-2.0 from hash)
- Vertical mask: `smoothstep(0.6, 0.85, uv.y)` — stars only in upper portion, fading in
- Star color: mostly white `vec3(0.9, 0.88, 0.95)` with occasional blue tint from hash
- Intensity: `0.5` multiplier (stars should be subtle, not dominant)
- 0 noise calls (pure hash-based)

### Layer 4: Nile Reflections

Torchlight dancing on water at the temple's base (bottom 25%).

- Vertical mask: `smoothstep(0.25, 0.0, uv.y)`
- Two sin-wave ripples at different frequencies for interference pattern:
  - `sin(uv.x * 35.0 + time * 2.5 + uv.y * 15.0)`
  - `sin(uv.x * 20.0 - time * 1.8 + uv.y * 10.0)`
- Color: blend of torch gold `vec3(0.95, 0.65, 0.20)` and lapis blue `vec3(0.18, 0.37, 0.66)` shifting with `sin(uv.x * 3.0 + time * 0.2)`
- Intensity: `0.06` multiplier (subtle, ambient)
- 0 noise calls (sin-wave based, like feline-homunculus pavement reflections)

### Layer 5: 40Hz Gamma Entrainment

Standard subliminal focus layer, consistent with all other themes.

- `sin(2.0 * PI * 40.0 * time)` at `0.035` amplitude
- Weighted to periphery via `smoothstep(0.15, 0.5, dist)`
- 0 noise calls

### Text Protection

Standard luminance-based mask applied last.

- `smoothstep(0.05, 0.12, luma)` — 1 on text, 0 on background
- `mix(effectColor, clean.rgb, textMask)`

### Total Cost

- 2 noise calls per fragment (torch flicker only)
- 1 texture sample (no chromatic aberration — this isn't a CRT theme)
- No fbm, no barrel distortion, no scanlines
- Comparable to feline-homunculus-lite in GPU cost

## Prompt: `prompts/night-temple.sh`

Full-immersion hieroglyphic prompt with dynamic status readouts.

### Render Format

```
┌─𓊹𓉗─[𓇳 HOUR 9]─[𓂓 KA:STRONG]─[𓎂 WARD:𓏴𓏏𓊮]─[𓁹 EYE OPEN]─𓊹𓉗─
└─𓅃 crashy@temple:~ $
```

### Colors

Dim gold `\e[33m`, bright gold `\e[93m` (ANSI yellow slots, which render as gold in this theme's palette).

### Dynamic Values

**𓇳 HOUR — Egyptian temporal hours**
- Maps current time of day to Egyptian hour system (1-12)
- Daytime (6am-6pm): hours of Ra's journey across the sky
- Nighttime (6pm-6am): hours of the Duat (underworld journey)
- Display: `HOUR N` where N = 1-12
- Calculation: `hour_of_day % 12 + 1` (simplified; true Egyptian hours were variable-length but this captures the spirit)

**𓂓 KA — Soul strength**
- Random walk: 40-99, drift -1 to +1 per command
- Label mapping:
  - 40-55: FAINT
  - 56-70: WAKING
  - 71-80: STEADY
  - 81-90: STRONG
  - 91-99: RADIANT

**𓎂 WARD — Protection glyph**
- Cycles through 4 protection signs every 8 commands:
  - 𓎂 (sa — protection)
  - 𓏴𓏏𓊮 (sDt — fire ward)
  - 𓆓𓏤 (Dt — cobra ward)
  - 𓁹 (irt — eye ward)

**𓁹 EYE — Eye of Horus watchfulness**
- Random walk: 20-99, drift -2 to +2 per command
- Label mapping:
  - 20-39: SHUT
  - 40-59: DROWSY
  - 60-79: OPEN
  - 80-99: BLAZING

### Decorative Glyphs

| Glyph | Gardiner | Transliteration | Meaning | Usage |
|-------|----------|-----------------|---------|-------|
| 𓊹𓉗 | R8+O6 | Hwt nTr | Temple of the god | Bookend frame |
| 𓅃 | G5 | Hrw | Horus falcon | Prompt indicator |
| 𓇳 | N5 | ra | Sun disk | Hour marker |
| 𓂓 | D28 | kA | Ka (soul) arms | Soul strength marker |
| 𓎂 | V16 | sA | Sa (protection) | Ward marker |
| 𓁹 | D10 | wDAt | Wedjat eye | Watchfulness marker |

### Pattern

Follows established prompt conventions:
- Zsh sourceable script
- Idempotency guard (`_NIGHT_TEMPLE_PROMPT_LOADED`)
- `precmd` hook for dynamic values
- Two-line box-drawing format with hieroglyphic bookends
- Theme-matched ANSI colors

## Font

Hieroglyphic Unicode (U+13000-U+1342F) renders through system font fallback. macOS already has `Noto Sans Egyptian Hieroglyphs` installed at `/System/Library/Fonts/Supplemental/NotoSansEgyptianHieroglyphs-Regular.ttf`. The custom `EgyptianHiero.ttf` from `~/Development/Heiroglyphy/final_output/` can be installed to `~/Library/Fonts/` as an alternative, but is not required — Noto handles the glyphs we use.

No `font-family` change in Ghostty config — the primary terminal font stays as the user's preference; hieroglyphs fall back automatically.

## Power Tier Variants

### night-temple-lite.glsl

**Keeps:** torch flicker (2 noise calls), stone vignette, 40Hz gamma, text protection.
**Drops:** starfield, Nile reflections.
**Cost:** 2 noise calls per fragment. Low.

### night-temple-static.glsl

**Keeps:** stone vignette, text protection.
**Drops:** everything animated (torch flicker, starfield, Nile reflections, gamma).
**Cost:** 0 noise calls, no `iTime`. Near-zero with `custom-shader-animation = false`.

## Launcher Integration

Standard integration following established patterns:
- `themes/night-temple` — color palette file
- `shaders/night-temple.glsl` — full shader
- `shaders/night-temple-lite.glsl` — lite variant
- `shaders/night-temple-static.glsl` — static variant
- `prompts/night-temple.sh` — hieroglyphic prompt
- Launcher auto-discovers via theme+shader pair matching
- README updated with new theme entry

## Testing

Manual verification:
- Confirm hieroglyphic Unicode glyphs render in the terminal (𓊹𓉗𓅃𓇳𓂓𓎂𓁹)
- Source prompt, confirm two-line render with gold colors and all 4 dynamic values
- Load each shader tier, confirm visual effects and animation behavior
- Verify `ghostty-random.sh` discovers and can select night-temple at all tiers
