# Power Tiers, Lite Shaders, and Theme Prompts

**Date:** 2026-03-16
**Status:** Draft

## Problem

Four custom GLSL shaders run at 60fps via `custom-shader-animation = true`. With multiple Ghostty windows open, GPU usage scales linearly (N windows x 60 shader invocations/sec). The heaviest shader (street-shaman) uses 26 noise evaluations per fragment (5 fbm calls x 5 octaves each + 1 standalone noise call). There is no way to dial down visual fidelity per-window, and only one of the four themes has a matching shell prompt.

## Goals

1. Three power tiers per theme: **full**, **lite**, **static** — selectable via launcher flags.
2. Lite shaders keep 1-2 signature animated effects; static shaders keep only non-animated effects.
3. Theme-matched shell prompts for all four themes, auto-sourced by the launcher.
4. Update the launcher (`ghostty-random.sh`) with `--lite`, `--static`, `--no-shader` flags and `GHOSTTY_POWER` env fallback.
5. Update README to document all themes, power tiers, and prompts.

## Non-Goals

- Shader performance benchmarking tooling.
- Automatic power tier selection based on battery/thermal state.
- Prompt integration with starship, oh-my-zsh, or other prompt frameworks.

## Directory Structure

```
~/.config/ghostty/
  config                            # active config (written by launcher)
  ghostty-random.sh                 # updated launcher
  themes/
    street-shaman                   # color palette (unchanged)
    feline-homunculus               # color palette (unchanged)
    deep-drift                      # color palette (unchanged)
    electrode-shaper                # color palette (unchanged)
  shaders/
    street-shaman.glsl              # full (existing, unchanged)
    street-shaman-lite.glsl         # new: reduced animation
    street-shaman-static.glsl       # new: no animation
    feline-homunculus.glsl          # full (existing, unchanged)
    feline-homunculus-lite.glsl     # new
    feline-homunculus-static.glsl   # new
    deep-drift.glsl                 # full (existing, unchanged)
    deep-drift-lite.glsl            # new
    deep-drift-static.glsl          # new
    electrode-shaper.glsl           # full (existing, unchanged)
    electrode-shaper-lite.glsl      # new
    electrode-shaper-static.glsl    # new
  prompts/
    deep-drift.sh                   # moved from ./deep-drift-prompt.sh
    street-shaman.sh                # new
    feline-homunculus.sh            # new
    electrode-shaper.sh             # new
  docs/
    plans/                          # existing design/implementation docs
    superpowers/specs/              # this spec
```

## Power Tiers

### Resolution Order

Flag (`--full`, `--lite`, `--static`, `--no-shader`) takes precedence over `$GHOSTTY_POWER` env var, which takes precedence over the default (`full`).

Valid values for `GHOSTTY_POWER`: `full`, `lite`, `static`, `no-shader`.

### Launcher CLI

```bash
ghostty                            # random theme, full shader
ghostty deep-drift                 # specific theme, full shader
ghostty deep-drift --lite          # specific theme, reduced animation
ghostty deep-drift --static        # specific theme, no animation
ghostty --lite                     # random theme, lite shader
ghostty --no-shader                # random theme, theme colors only
ghostty list                       # show available themes (existing)
```

### Argument Parsing

The launcher must distinguish theme names from flags. Parsing strategy:

1. Iterate all arguments. Any argument starting with `--` is a flag; any other non-flag argument is treated as the theme name (or `list` command).
2. Theme name and flags can appear in any order: `ghostty --lite deep-drift` and `ghostty deep-drift --lite` are equivalent.
3. `ghostty list --lite` is valid — it prints the theme list and ignores the flag.
4. At most one tier flag is accepted. If multiple tier flags are given, the last one wins.

### Config Generation

The launcher writes `~/.config/ghostty/config` with these variations:

| Tier | `custom-shader` | `custom-shader-animation` |
|------|-----------------|---------------------------|
| full | `shaders/<theme>.glsl` | `true` |
| lite | `shaders/<theme>-lite.glsl` | `true` |
| static | `shaders/<theme>-static.glsl` | `false` |
| no-shader | *(omitted)* | *(omitted)* |

### Prompt Auto-Sourcing

After writing the config, the launcher prints a `source` hint if a matching prompt exists:

```
source ~/.config/ghostty/prompts/<theme>.sh
```

The launcher does NOT auto-source the prompt (it can't modify the calling shell). The user adds this to their `.zshrc` or sources manually. The launcher prints the hint with the resolved theme name — in random mode this is the randomly chosen theme, e.g.:

```
source ~/.config/ghostty/prompts/deep-drift.sh
```

The hint is only printed when a matching file exists in `prompts/`.

## Lite Shader Layer Retention

Each lite variant keeps the cheapest layers that preserve the theme's identity.

### street-shaman-lite.glsl

**Keeps:** firelight flicker (1 noise call), bottom glow (sin pulse), vignette, 40Hz gamma, text protection.
**Drops:** fbm smoke (5-octave x2 calls = 10 noise evals), fbm azure wisps (5-octave x3 calls = 15 noise evals), heat distortion.
**Savings:** Eliminates all 5 fbm calls (25 noise evals); retains 1 standalone noise call for firelight. Total: 26 -> 1. Largest reduction of any theme.

### feline-homunculus-lite.glsl

**Keeps:** rain streaks (1 layer instead of 2), vignette, 40Hz gamma, text protection.
**Drops:** neon glow bleed (warm + cool sides, 4 noise calls), pavement reflections (1 noise call + ripple math), bottom glow (2 noise calls).
**Savings:** Eliminates 7 noise calls and all bottom-screen compositing. Rain is the signature effect.

### deep-drift-lite.glsl

**Keeps:** barrel distortion + chromatic aberration (4 texture samples), burn-in (no `iTime` dependency, cheap per-frame), scanlines, vignette, 40Hz gamma, text protection.
**Drops:** power supply flicker (2 noise calls), radiation burst (branching + hash), h-sync wobble (sin + smoothstep on UV).
**Savings:** Eliminates all time-dependent noise. Burn-in has no `iTime` dependency so the compiler can optimize it heavily, but it still executes every frame since `custom-shader-animation = true` for lite tier. CRT look preserved.

### electrode-shaper-lite.glsl

**Keeps:** barrel distortion + chromatic aberration (4 texture samples), scanlines, vignette, 40Hz gamma, text protection.
**Drops:** plasma field (3 noise calls + edge masking), electrode arcs (time-cell hash system), EMF interference (2 noise calls).
**Savings:** Eliminates all noise calls and the arc system. CRT hardware look preserved.

## Static Shader Layer Retention

All static variants share a common structure — they have zero `iTime` dependency and run once per resize/redraw.

**All themes keep:** vignette, text protection.
**CRT themes (deep-drift, electrode-shaper) also keep:** barrel distortion, chromatic aberration, scanlines. Deep-drift additionally keeps burn-in (its full shader has a `burnIn()` function; electrode-shaper does not have burn-in in its full shader, so its static variant omits it — no new burn-in layer is authored).
**Non-CRT themes (street-shaman, feline-homunculus) also keep:** vignette only (no barrel/scanlines in originals).

Static shaders set `custom-shader-animation = false`, meaning the GPU renders the shader once and caches the result until the window resizes or content redraws. Near-zero ongoing GPU cost.

## Theme Prompts

All four prompts follow the same pattern established by deep-drift-prompt.sh:

- Zsh sourceable script
- Idempotency guard (`_<THEME>_PROMPT_LOADED`)
- `precmd` hook for dynamic values
- Two-line box-drawing format
- Theme-matched ANSI color codes

### deep-drift.sh (move from root)

Existing USS Erebus ship console prompt. Move from `./deep-drift-prompt.sh` to `./prompts/deep-drift.sh`. No content changes.

```
┌─[USS EREBUS]─[DECK 7 TERM 03]─[SOL 10957]─[O2:94%]─[HULL:87%]
└─╼ crashy@nav:~ $
```

**Colors:** dim amber `\e[33m`, bright amber `\e[93m`.
**Dynamic values:** SOL (days since 1996-01-01), O2 (91-97% random walk), HULL (82-91% random walk).

### street-shaman.sh (new)

Occult ritual terminal. The shaman's working console during a demon-fighting session.

```
┌─[SIGIL ACTIVE]─[WARD:73%]─[ENCOUNTERS:12]─[MOON:WAXING]
└─╼ crashy@ritual:~ $
```

**Colors:** dim green `\e[32m`, bright green `\e[92m` (matching the neon-green occult theme).
**Dynamic values:**
- WARD: 60-95% random walk (ward strength, drifts each command)
- ENCOUNTERS: session command counter (increments each precmd)
- MOON: cycles through 8 phases based on actual lunar calendar (calculated from date)

### feline-homunculus.sh (new)

Tokyo street navigation terminal. A cat-creature navigating rainy neon districts.

```
┌─[SHINJUKU]─[RAIN:HEAVY]─[NEON:87%]─[ALLEY:DEEP]
└─╼ crashy@tokyo:~ $
```

**Colors:** dim magenta `\e[35m`, bright magenta `\e[95m` (matching the pink neon theme).
**Dynamic values:**
- District: rotates through a list (SHINJUKU, AKIHABARA, SHIBUYA, KABUKICHO, ROPPONGI, IKEBUKURO) every N commands
- RAIN: intensity label mapped from numeric random walk (DRIZZLE / STEADY / HEAVY / DOWNPOUR)
- NEON: 70-99% random walk (neon sign density/brightness)
- ALLEY: depth label from random walk (SHALLOW / WINDING / DEEP / LABYRINTH)

### electrode-shaper.sh (new)

Lab instrument readout. A researcher monitoring plasma containment and EMF levels.

```
┌─[PLASMA:92%]─[EMF:340mT]─[ARCS:7]─[FREQ:40.0Hz]
└─╼ crashy@lab:~ $
```

**Colors:** dim cyan `\e[36m`, bright cyan `\e[96m` (matching the violet/cyan plasma theme).
**Dynamic values:**
- PLASMA: 80-99% random walk (containment percentage)
- EMF: 200-500mT random walk (electromagnetic field level, steps of ~20)
- ARCS: session command counter (electrode discharge events)
- FREQ: fixed at 40.0Hz (a nod to the gamma entrainment layer)

## README Update

Update README.md to:

1. Add electrode-shaper and deep-drift to the theme table.
2. Add a "Power Tiers" section documenting `--lite`, `--static`, `--no-shader`, and `GHOSTTY_POWER`.
3. Add a "Prompts" section documenting the `prompts/` directory and how to source them.
4. Update the file structure diagram.

## Testing

Manual verification:
- Launch each theme at each tier, confirm shader loads and animation behaves correctly.
- Source each prompt script, confirm two-line prompt renders, dynamic values update.
- Verify `--no-shader` produces a config with no shader lines.
- Verify `GHOSTTY_POWER=lite ghostty` respects the env var.
- Verify flag overrides env var (`GHOSTTY_POWER=full ghostty --static` uses static).
- Verify `ghostty list` still works.
- Verify random mode works with each tier flag.
