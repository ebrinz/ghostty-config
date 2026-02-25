# Ghostty Config

Custom themes and shaders for [Ghostty](https://ghostty.org/).

## Themes

Each theme is a color palette + GLSL shader pair. Drop matching files in `themes/` and `shaders/` to add to the rotation.

| Theme | Vibe |
|-------|------|
| **street-shaman** | Neon-green occult hacker. Ritual fire, smoke haze, azure wisps. |
| **feline-homunculus** | Cat-creature lost in rainy Tokyo. Rain on glass, neon bleed, wet pavement reflections. |

Every shader includes a subliminal **40 Hz gamma entrainment** layer — a sinusoidal brightness pulse at the gamma brainwave frequency, weighted toward peripheral vision. Below conscious flicker fusion, but the visual cortex still entrains. Focus mode.

## Random Theme Launcher

`ghostty-random.sh` picks a random theme+shader pair on each launch.

```bash
# Random
~/.config/ghostty/ghostty-random.sh

# Specific theme
~/.config/ghostty/ghostty-random.sh feline-homunculus

# Make every window random (add to ~/.zshrc)
alias ghostty='~/.config/ghostty/ghostty-random.sh'
```

## File Structure

```
config                  # Active Ghostty config
ghostty-random.sh       # Random theme launcher
themes/
  street-shaman         # Color palette
  feline-homunculus     # Color palette
shaders/
  street-shaman.glsl    # Fire + smoke + entrainment
  feline-homunculus.glsl # Rain + neon + entrainment
```
