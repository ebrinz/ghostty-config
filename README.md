# Ghostty Config

Custom themes and shaders for [Ghostty](https://ghostty.org/).

## Themes

Each theme is a color palette + GLSL shader pair. Drop matching files in `themes/` and `shaders/` to add to the rotation.

| Theme | Vibe |
|-------|------|
| **street-shaman** | Neon-green occult hacker. Ritual fire, smoke haze, azure wisps. |
| **feline-homunculus** | Cat-creature lost in rainy Tokyo. Rain on glass, neon bleed, wet pavement reflections. |
| **electrode-shaper** | Cyberpunk CRT plasma lab. Electrode arcs, EMF interference, violet-cyan plasma field. |
| **deep-drift** | USS Erebus, 30 years adrift. Degraded amber phosphor CRT, radiation static, burn-in. |
| **night-temple** | Egyptian night ritual. Torchlit temple, starfield, Nile reflections, hieroglyphic prompt. |
| **amber-splice** | Jurassic DNA-expansion aliens. Gold double helix in amber, cyan alien splice strand, traveling splice pulse. |
| **dip-shit** | Trashed VHS tape in a dying CRT. Tracking errors, color bleed, static bursts, tape dropouts, barrel distortion. |
| **grog-harbor** | Melee Island dock at midnight, LucasArts SCUMM era. VGA Bayer dither, moonlit water, torch flicker, scanlines. |
| **entropy-field** | Realtime RNG observatory. Quantum foam, falling bit-rain, turquoise/gold sampling lattice. Backdrop for the **ghostty-rng** app. |
| **ghost-in-the-machine** | Spectral cyberpunk séance. Ectoplasmic vapor, jittering Fuller geodesic lattice, matrix code-rain, rare magenta Snow Crash glitch bursts. |

Every shader **except dip-shit, entropy-field, and ghost-in-the-machine** includes a subliminal **40 Hz gamma entrainment** layer — a sinusoidal brightness pulse at the gamma brainwave frequency, weighted toward peripheral vision. Below conscious flicker fusion, but the visual cortex still entrains. Focus mode. (entropy-field is a data-visualization backdrop rather than a focus-mode theme, so it omits the pulse to keep the charts honest; ghost-in-the-machine has its own glitch-burst rhythm instead.)

### ghost-in-the-machine → emergent CA

ghost-in-the-machine ships a fourth shader variant, `ghost-in-the-machine-nca.glsl`: true Conway Life (B3/S23) computed via the light-cone trick — Ghostty shaders are stateless, so each frame recomputes N generations from an epoch-seeded grid. Colonies emerge, evolve, and fade every 24 s; births flash white, deaths ghost out magenta. Heaviest shader in the collection.

### entropy-field → ghostty-rng

`entropy-field` is the visual companion to **ghostty-rng**, a realtime hardware-entropy observatory for [TrueRNG](https://ubld.it/) devices — it streams the RNG and renders a live Shannon-entropy curve against the 8.0 bits/byte baseline, NIST-style randomness tests (monobit, chi-square, serial correlation, min-entropy), and a truecolor bitstream.

The app is a standalone Rust project (`~/Development/ghostty-rng`); this repo carries only its theme + shaders. To run it:

```bash
ghostty entropy-field          # apply the backdrop (or --lite / --static)
ghostty-rng                    # then launch the observatory
# …or, from the app repo, one shot in a fresh window:
~/Development/ghostty-rng/run.sh
```

## Power Tiers

Each theme has three shader variants to control GPU usage:

| Tier | Description | GPU Cost |
|------|-------------|----------|
| `--full` | All effects, 60fps animation (default) | High |
| `--lite` | 1-2 signature effects, reduced noise calls | Low |
| `--static` | Vignette + CRT only, no animation | Near-zero |
| `--no-shader` | Theme colors only, no shader | Zero |

```bash
ghostty deep-drift --lite      # reduced animation
ghostty --static               # random theme, static shader
ghostty --no-shader             # random theme, colors only
```

Set a default tier via environment variable:

```bash
export GHOSTTY_POWER=lite       # in ~/.zshrc
ghostty deep-drift              # uses lite (env default)
ghostty deep-drift --full       # flag overrides env
```

## Theme Prompts

Each theme has a matching shell prompt in `prompts/`. Source it to get a themed two-line prompt with live status readouts:

```bash
source ~/.config/ghostty/prompts/deep-drift.sh
# ┌─[USS EREBUS]─[DECK 7 TERM 03]─[SOL 10957]─[O2:94%]─[HULL:87%]
# └─╼ crashy@nav:~ $
```

| Prompt | Vibe | Readouts |
|--------|------|----------|
| **deep-drift** | USS Erebus ship console | SOL counter, O2%, HULL% |
| **street-shaman** | Occult ritual terminal | WARD%, encounters, moon phase |
| **feline-homunculus** | Tokyo street navigation | District, rain, neon%, alley depth |
| **electrode-shaper** | Lab instrument readout | PLASMA%, EMF, arcs, frequency |
| **night-temple** | Hieroglyphic temple ritual | 𓇳 Hour, 𓂓 KA strength, 𓎂 ward glyph, 𓁹 Eye of Horus |
| **amber-splice** | Genetics field-lab console | SEQ%, VIABILITY%, SPLICE strain |
| **grog-harbor** | SCUMM verb-panel interface | Verb grid (Look at, Open, Push…), git branch, cwd |

The launcher prints a source hint when switching themes.

## Random Theme Launcher

`ghostty-random.sh` picks a random theme+shader pair on each launch.

```bash
# Random
~/.config/ghostty/ghostty-random.sh

# Specific theme
~/.config/ghostty/ghostty-random.sh feline-homunculus

# With power tier
~/.config/ghostty/ghostty-random.sh deep-drift --lite

# List available themes
~/.config/ghostty/ghostty-random.sh list

# Make every window random (add to ~/.zshrc)
alias ghostty='~/.config/ghostty/ghostty-random.sh'
```

## File Structure

```
config                          # Active Ghostty config
ghostty-random.sh               # Random theme launcher (with power tier support)
themes/
  street-shaman                 # Color palette
  feline-homunculus             # Color palette
  electrode-shaper              # Color palette
  deep-drift                    # Color palette
  night-temple                  # Color palette
  amber-splice                  # Color palette
  dip-shit                      # Color palette
  grog-harbor                   # Color palette
  entropy-field                 # Color palette (pairs with the ghostty-rng app)
  ghost-in-the-machine          # Color palette
shaders/
  street-shaman.glsl            # Full: fire + smoke + entrainment
  street-shaman-lite.glsl       # Lite: firelight + bottom glow
  street-shaman-static.glsl     # Static: vignette only
  feline-homunculus.glsl        # Full: rain + neon + entrainment
  feline-homunculus-lite.glsl   # Lite: single-layer rain
  feline-homunculus-static.glsl # Static: vignette only
  electrode-shaper.glsl         # Full: plasma + arcs + EMF
  electrode-shaper-lite.glsl    # Lite: CRT artifacts only
  electrode-shaper-static.glsl  # Static: CRT + vignette
  deep-drift.glsl               # Full: CRT + radiation + wobble
  deep-drift-lite.glsl          # Lite: CRT + burn-in
  deep-drift-static.glsl        # Static: CRT + burn-in
  night-temple.glsl             # Full: torches + stars + Nile
  night-temple-lite.glsl        # Lite: torches + vignette
  night-temple-static.glsl      # Static: stone vignette only
  amber-splice.glsl             # Full: amber + motes + helix + splice pulse
  amber-splice-lite.glsl        # Lite: helix + amber vignette
  amber-splice-static.glsl      # Static: frozen helix + vignette
  dip-shit.glsl                 # Full: VHS tracking + bursts + dropouts
  dip-shit-lite.glsl            # Lite: CRT look, no time-based animation
  dip-shit-static.glsl          # Static: frozen VHS frame
  grog-harbor.glsl              # Full: dither + water ripples + torch flicker
  grog-harbor-lite.glsl         # Lite: dither + scanlines + vignette
  grog-harbor-static.glsl       # Static: dither + scanlines, no animation
  entropy-field.glsl            # Full: quantum foam + bit-rain + sampling lattice
  entropy-field-lite.glsl       # Lite: fewer octaves, gentler motion
  entropy-field-static.glsl     # Static: frozen field, no animation
  ghost-in-the-machine.glsl     # Full: vapor + geodesic lattice + code-rain + glitch
  ghost-in-the-machine-lite.glsl   # Lite: vapor + code-rain
  ghost-in-the-machine-static.glsl # Static: frozen vapor + lattice
  ghost-in-the-machine-nca.glsl    # CA: true Conway Life via light-cone recompute
prompts/
  deep-drift.sh                 # USS Erebus console prompt
  street-shaman.sh              # Occult ritual prompt
  feline-homunculus.sh          # Tokyo navigation prompt
  electrode-shaper.sh           # Lab instrument prompt
  night-temple.sh               # Hieroglyphic temple prompt
  amber-splice.sh               # Genetics field-lab prompt
  grog-harbor.sh                # SCUMM verb-interface prompt
```
