# Deep Drift — Ghostty Theme Design

## Overview

**Full title:** Deep Drift: USS Erebus Terminal, Sol 10,957 — 30 Years Adrift

**Metaphor:** You're sitting at a terminal on Deck 7 of the USS Erebus, a deep space vessel launched in 1996. The ship is still running — reactor steady, life support nominal — but the display hardware has been degrading for three decades. The amber phosphor CRT has burn-in ghosts, the power supply causes brightness dips, cosmic radiation occasionally scrambles pixels, and the horizontal sync circuit is slowly dying. The terminal still works. It just looks like it's been through hell.

**Approach:** Layered composite (same proven pattern as street-shaman and electrode-shaper). Single-pass GLSL, 7 layers. Plus a shell prompt script that makes your PS1 look like a ship's console.

## Color Theme: `deep-drift`

### Core Colors

| Element | Color | Rationale |
|---------|-------|-----------|
| Background | `#0b0a08` | Near-black with warm undertone — dying backlight |
| Foreground | `#c4a348` | Degraded amber phosphor — was bright orange in '96 |
| Cursor | `#e8a010` | Hot amber — the one replacement part |
| Cursor text | `#0b0a08` | Contrast |
| Selection BG | `#2a1e08` | Dark amber wash — phosphor afterglow |
| Selection FG | `#e8c860` | Bright amber — selected text pops |

### ANSI Palette

| Slot | Normal | Bright | Concept |
|------|--------|--------|---------|
| 0/8 black | `#0b0a08` | `#2a2418` | Dead screen / dim phosphor |
| 1/9 red | `#a03020` | `#c84830` | Hull breach warning — seen too many times |
| 2/10 green | `#2d8a4e` | `#40b868` | Life support readout |
| 3/11 yellow | `#c4a348` | `#e8c860` | Primary amber phosphor |
| 4/12 blue | `#1a7a8a` | `#28a0b8` | Nav console / star chart cyan |
| 5/13 magenta | `#8a4a78` | `#b068a0` | Comms frequency — rarely used now |
| 6/14 cyan | `#2a8a7a` | `#40b8a8` | Sensor data — still scanning |
| 7/15 white | `#8a7a58` | `#c4a348` | Dim / bright phosphor |

## Shader: `deep-drift.glsl` — 7 Layers

### Layer 1: CRT Scanlines + Barrel Distortion
- **Scanlines**: Thick, pronounced — 20% darkening every other row. Old hardware = chunkier lines.
- **Barrel distortion**: Stronger than electrode-shaper (0.08 vs 0.05) — this is a 30-year-old tube
- **Chromatic aberration**: Warm-shifted. Red channel drifts outward more than blue (amber phosphor aging)

### Layer 2: Phosphor Burn-In
- Static ghostly shapes at fixed screen positions — old UI elements permanently etched
- A faint horizontal line at ~20% from top (the old status bar)
- Faint rectangular outline at edges (the old window border)
- Very low opacity (0.03-0.05), amber-tinted
- Does NOT move with time — burn-in is permanent damage

### Layer 3: Power Supply Flicker
- Slow, irregular brightness dips across the whole screen
- Not periodic — uses noise-driven envelope so it feels organic
- Dips to ~85% brightness for 0.5-1.5 seconds, then recovers
- Frequency: roughly every 4-8 seconds
- Simulates aging capacitors that can't hold steady voltage

### Layer 4: Deep Space Radiation Static
- Brief bursts of pixel-level noise — cosmic rays hitting the electronics
- Hash-based random pixels that flash white for single frames
- Bursts last 0.1-0.3 seconds, occur every 5-10 seconds
- Low density — maybe 2-5% of pixels per burst
- Concentrated in random rectangular patches (radiation shower pattern)

### Layer 5: Horizontal Sync Wobble
- Subtle horizontal displacement that drifts slowly
- Entire scanline rows shift left/right by 1-3 pixels
- The wobble zone moves vertically over time (the fault drifts)
- Very subtle — just enough to notice subconsciously
- Simulates a worn H-sync oscillator crystal

### Layer 6: Vignette (Aggressive)
- Heavy darkening at corners and edges — tube is losing luminance
- More aggressive than other themes: corners drop to ~15% brightness
- Slightly asymmetric — bottom-left corner is worse (gravity + heat over 30 years)

### Layer 7: 40Hz Gamma Entrainment + Text Protection
- Subliminal 3.5% sinusoidal modulation weighted to periphery
- Luminance-based text mask — all effects overwritten on text pixels
- Text stays razor-sharp through all degradation artifacts

## Shell Prompt: `deep-drift-prompt.sh`

A sourceable zsh script that sets PS1 to a ship's console interface:

```
┌─[USS EREBUS]─[DECK 7 TERM 03]─[SOL 10957]─[O2:94%]─[HULL:87%]
└─╼ crashy@nav:~ $
```

- SOL counter: days since Unix epoch of Jan 1 1996 (ship launch date)
- O2: random walk between 91-97%, seeded per-session
- HULL: random walk between 82-91%, seeded per-session
- All values computed in PROMPT_COMMAND / precmd so they update per-prompt
- Uses theme amber color via ANSI escape codes

## Performance
- All procedural, no external textures
- Radiation static uses hash, not fbm
- Burn-in is static geometry, zero per-frame cost beyond sampling
- Target: 60fps on integrated GPU

## File Structure

```
~/.config/ghostty/
  themes/deep-drift                    # Color palette
  shaders/deep-drift.glsl             # Degraded CRT shader
  deep-drift-prompt.sh                # Ship console PS1 prompt
  docs/plans/
    2026-03-11-deep-drift-design.md   # This file
```
