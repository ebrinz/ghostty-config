# Ghostty Config

Custom themes and shaders for [Ghostty](https://ghostty.org/).

## Themes

Each theme is a color palette + GLSL shader pair. Drop matching files in `themes/` and `shaders/` to add to the rotation.

| Theme | Vibe |
|-------|------|
| **street-shaman** | Neon-green occult hacker. A tumbling 3D Metatron's cube that morphs into an icosahedron and back, glowing embers rising through it, ritual fire, smoke haze, azure wisps. |
| **feline-homunculus** | Cat-creature lost in rainy Tokyo. A back-alley of abstract neon smears in crimson, electric blue and neon green, lit facades and sagging power lines reflected in the wet street, rain on glass, and a small pixel-art cat on an air-conditioner that watches your cursor, perks up when you type, stares at selections, paws at the cursor when it lands beside it, sleeps when you look away, and every so often strolls off along the street and back. |
| **electrode-shaper** | Cyberpunk CRT plasma lab. Electrode arcs, EMF interference, violet-cyan plasma field. |
| **deep-drift** | USS Erebus, 30 years adrift. The console's forward sensor view in degraded amber phosphor: a tumbling starfield, a dead planet's limb, drifting wireframe debris with sensor tags, a navigation reticle, compass tape, ticking telemetry, and a target bracket wherever the cursor lands. Radiation static, burn-in. |
| **night-temple** | Egyptian night ritual. Fluted columns with turquoise hieroglyph bands open to a starfield, braziers with living flames, a flagstone floor, the Nile reflecting stone and fire, and a gold-edged scarab crawling the floor that glints toward your cursor. Hieroglyphic prompt. |
| **amber-splice** | Jurassic DNA-expansion aliens. Gold double helix in amber, cyan alien splice strand, traveling splice pulse. |
| **dip-shit** | Trashed VHS tape in a dying CRT. Tracking errors, color bleed, static bursts, tape dropouts, barrel distortion. |
| **grog-harbor** | Melee Island dock at midnight, LucasArts SCUMM era. A complete original pixel-art scene: starry sky with a dithered moon and drifting clouds, town windows up the headland, a ship bobbing at anchor, pixel waves under a moonlight column, the Scumm Bar with candle-lit windows and a smoking chimney, a plank pier with a swaying lantern, palms. VGA Bayer dither, scanlines. |
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

## Interaction

Ghostty 1.4 exposes the terminal's **cursor** and **window focus** to custom shaders (`iCurrentCursor`, `iPreviousCursor`, `iTimeCursorChange`, `iFocus`, `iTimeFocus`). Every full and lite shader reacts to both. Mouse position (`iMouse`) is declared by Ghostty but never filled in, so there are no hover or click effects yet.

Two shared rules keep it out of the way while typing:

- **Cursor trails fire only on jumps of 2+ cells.** Single-cell moves (typing, scrolling output) show nothing beyond the resting glow. Vim motions, `clear`, a new prompt, or a click-to-move all fire.
- **Unfocused windows dim** so the active one stands out. Regaining focus plays a short theme-specific "wake" (about 0.3–1 s). It also plays once on launch.

| Theme | Resting cursor | Cursor jump | Unfocused | Focus gained |
|-------|----------------|-------------|-----------|--------------|
| **street-shaman** | Green ember candle-glow | Sparks scatter along the path and drift up | Fire burns down to embers: slow flicker, thicker smoke | Flare, settles over ~1 s |
| **feline-homunculus** | Amber lantern glow with a rippled reflection smeared below it | Long-exposure light streak | Neon shuts off, alley goes cold blue; rain keeps falling | Neon tubes stutter back on |
| **electrode-shaper** | Pulsing violet plasma corona | Jagged lightning arc old → new, plasma afterglow | Chamber powers down: plasma collapses, arcs stop, deeper scanlines | Power-on surge; one arc crosses the cursor's row |
| **deep-drift** | Amber phosphor bloom | Phosphor ghost of the old cursor decays over ~1.4 s, smear between | Standby: half brightness, heavier PSU dips | CRT power-on: raster unfolds from a bright line |
| **night-temple** | Gold oil-lamp flame | Ember comet | Braziers burn low; stars come out brighter | Torches flare |
| **dip-shit** | — | Tape skip: tracking tear, chroma smear and static on the landing row | PAUSE: dim, desaturated, head-switching noise bars | PLAY: frame rolls back into lock |
| **grog-harbor** | Dithered lantern glow | SCUMM walk: steps to the new spot at 12 fps with sprite afterimages | Dock sleeps: palette drops to 4 levels, torch stops flickering | Lantern and torch flare |
| **entropy-field** | Lattice cells near the cursor sample far more often | Bits along the path flip gold, then settle | Bit-rain stops, lattice goes quiet | One sampling ring expands from the cursor |
| **amber-splice** | Amber inclusion glow, breathing like light through resin | Splice run: blue-white charge races to the new spot, cyan strand decays behind it | Lab lights down: amber dims, splice pulse stops, alien strand idles | One splice pulse runs up the helix from the cursor's row |
| **ghost-in-the-machine** | Breathing ecto aura | Ectoplasm wake, magenta glitch tear where it lands | Séance goes still: lattice freezes, rain and bursts stop | Snow Crash burst on the cursor's row |

Static shaders are unchanged: they run with `custom-shader-animation = false`, so time-based trails and fades could not animate. `ghost-in-the-machine-nca` is also unchanged.

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
