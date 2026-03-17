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

Every shader includes a subliminal **40 Hz gamma entrainment** layer — a sinusoidal brightness pulse at the gamma brainwave frequency, weighted toward peripheral vision. Below conscious flicker fusion, but the visual cortex still entrains. Focus mode.

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
prompts/
  deep-drift.sh                 # USS Erebus console prompt
  street-shaman.sh              # Occult ritual prompt
  feline-homunculus.sh          # Tokyo navigation prompt
  electrode-shaper.sh           # Lab instrument prompt
```
