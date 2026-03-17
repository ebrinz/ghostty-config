# Power Tiers, Lite Shaders, and Theme Prompts — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 power tiers (full/lite/static) to all 4 Ghostty shaders, create theme-matched shell prompts, and update the launcher to support tier selection.

**Architecture:** Each full shader gets two stripped-down variants (-lite, -static). The launcher parses `--lite`/`--static`/`--no-shader` flags with `$GHOSTTY_POWER` env fallback, writes the appropriate config, and prints a prompt source hint. Four zsh prompt scripts in `prompts/` match the visual themes.

**Tech Stack:** GLSL (Ghostty custom shaders), zsh (launcher + prompts), Ghostty config format

**Spec:** `docs/superpowers/specs/2026-03-16-power-tiers-prompts-design.md`

---

## Chunk 1: Lite Shaders

### Task 1: street-shaman-lite.glsl

**Files:**
- Create: `shaders/street-shaman-lite.glsl`
- Reference: `shaders/street-shaman.glsl`

- [ ] **Step 1: Create the lite shader**

Copy `street-shaman.glsl` and strip:
- Layer 1 (heat distortion): Remove `distortedUV` computation and use `uv` directly for texture sampling
- Layer 3 (smoke): Remove `smokeUV`, both `fbm()` calls, `smokeFinal`, `smokeColor`, `smokeEdge` — all lines from `vec2 smokeUV` through `color.rgb += smokeColor`
- Layer 4 (azure wisps): Remove `bottomFade`, all 3 `wispUV` vars, all 3 `fbm()` calls, `wisp1/2/3` smoothstep shaping, `wisps`, `sway`, `azureWisp` — all lines from `float bottomFade` through `color.rgb += azureWisp`
- Keep the `fbm()` function definition (harmless dead code, or remove it since nothing calls it)
- Remove the `fbm()` function definition entirely since no caller remains

Keep intact:
- `hash()` and `noise()` utilities
- Layer 2 (firelight flicker + vignette): `flickerNoise`, `flicker`, `edgeFactor`, `vignette`
- Layer 5 (green bottom glow): `bottomGlow`, `glowPulse`, `fireGlow`
- Layer 6 (40Hz gamma)
- Layer 7 (text protection)

The shader header comment should note this is the lite variant.

```glsl
// street-shaman-lite.glsl
// Lite variant: firelight flicker + bottom glow only.
// Drops: fbm smoke, azure wisps, heat distortion (26 -> 1 noise eval).
```

- [ ] **Step 2: Verify shader compiles by setting it in config**

Manually edit `config` to point to `street-shaman-lite.glsl`, open Ghostty, confirm it loads without errors and shows firelight flicker + vignette without smoke/wisps.

- [ ] **Step 3: Commit**

```bash
git add shaders/street-shaman-lite.glsl
git commit -m "feat: add street-shaman-lite shader — drops fbm smoke and wisps"
```

### Task 2: feline-homunculus-lite.glsl

**Files:**
- Create: `shaders/feline-homunculus-lite.glsl`
- Reference: `shaders/feline-homunculus.glsl`

- [ ] **Step 1: Create the lite shader**

Copy `feline-homunculus.glsl` and strip:
- Layer 2 (neon glow bleed): Remove all lines from `// --- warm neon` through `color += coolNeon * coolFade * coolFlicker * 0.08;` — the `pink`, `amber`, `warmMix`, `warmNeon`, `warmFlicker`, `warmFade`, `teal`, `blue`, `coolMix`, `coolNeon`, `coolFlicker`, `coolFade` variables
- Layer 3 (wet pavement reflections): Remove all lines from `float pavementMask` through `color += pavementColor * pavementMask * 0.07;` — but note `warmNeon` and `coolNeon` are referenced here, so this must be removed too since the neon vars are gone
- Layer 3b (bottom glow): Remove all lines from `float glowMask` through `color += glowColor * glowMask * glowPulse * 0.10;`
- Rain: Change the loop from `for (int layer = 0; layer < 2; layer++)` to only run layer 0 (foreground rain). Simplest: change loop bound to `layer < 1`.

Keep intact:
- `hash21()` and `noise()` utilities (rain still uses `hash21`)
- `rainStreak()` function (modified to 1 layer)
- Layer 1 (rain streaks) — single layer
- Layer 4 (vignette)
- Layer 5 (40Hz gamma)
- Layer 6 (text protection)

```glsl
// feline-homunculus-lite.glsl
// Lite variant: single-layer rain only.
// Drops: neon bleed, pavement reflections, bottom glow (7 noise calls removed).
```

- [ ] **Step 2: Verify shader loads in Ghostty**

- [ ] **Step 3: Commit**

```bash
git add shaders/feline-homunculus-lite.glsl
git commit -m "feat: add feline-homunculus-lite shader — single-layer rain only"
```

### Task 3: deep-drift-lite.glsl

**Files:**
- Create: `shaders/deep-drift-lite.glsl`
- Reference: `shaders/deep-drift.glsl`

- [ ] **Step 1: Create the lite shader**

Copy `deep-drift.glsl` and strip:
- H-sync wobble (Layer 5 applied to UV): Remove `wobbleZoneCenter`, `wobbleZoneWidth`, `wobbleMask`, `wobbleAmount`, `wobbledUV`. Use `rawUV` directly where `wobbledUV` was used (as input to `barrelDistort`).
- Power supply flicker (Layer 3): Remove `flickerNoise`, `flickerNoise2`, `combined`, `dip`, and the `color *= (1.0 - dip)` line.
- Radiation static (Layer 4): Remove the `radiationBurst()` function entirely and the `float radiation = radiationBurst(...)` call + `color += vec3(radiation) * 0.8`.
- Remove the `noise()` function if no remaining code calls it. Check: burn-in doesn't use noise, vignette doesn't, gamma doesn't. Safe to remove `noise()` and `hash21()` — wait, barrel distortion and chromatic aberration use `texture()` not `hash21()`. Burn-in uses only math. So yes, remove `noise()`. But `hash21()` is used by `radiationBurst()` which is removed, so remove `hash21()` too.

Keep intact:
- `barrelDistort()` function
- `burnIn()` function
- Layer 1 (CRT artifacts): barrel distortion, chromatic aberration, scanlines
- Layer 2 (phosphor burn-in)
- Layer 6 (vignette)
- Layer 7a (40Hz gamma)
- Layer 7b (text protection)
- CRT edge fade

```glsl
// deep-drift-lite.glsl
// Lite variant: CRT artifacts + burn-in only, no animated noise.
// Drops: power flicker, radiation bursts, h-sync wobble (all noise removed).
```

- [ ] **Step 2: Verify shader loads in Ghostty**

- [ ] **Step 3: Commit**

```bash
git add shaders/deep-drift-lite.glsl
git commit -m "feat: add deep-drift-lite shader — CRT + burn-in, no animated noise"
```

### Task 4: electrode-shaper-lite.glsl

**Files:**
- Create: `shaders/electrode-shaper-lite.glsl`
- Reference: `shaders/electrode-shaper.glsl`

- [ ] **Step 1: Create the lite shader**

Copy `electrode-shaper.glsl` and strip:
- `electrodeArc()` function: Remove entirely.
- `noise()` and `hash21()` functions: Remove entirely (no remaining callers after removing layers below).
- Layer 2 (plasma field): Remove `violet`, `cyan`, `hotWhite`, `phase`, `phase2`, `plasmaColor`, `plasmaMask`, `plasmaFlicker`, and the `color +=` line.
- Layer 3 (electrode arcs): Remove `float arc = electrodeArc(...)` and the `color +=` line. Note: `arcColor` references `plasmaColor` which is also removed — both go.
- Layer 4 (EMF interference): Remove `bandY`, `band`, `burst`, `emf`, and the `color +=` line. This also references `plasmaColor` which is removed.

Keep intact:
- `barrelDistort()` function
- Layer 1 (CRT artifacts): barrel distortion, chromatic aberration, scanlines
- Layer 5 (vignette) — note: `vignetteDist` is used by both vignette and gamma, keep both
- Layer 6 (40Hz gamma)
- Layer 7 (text protection)
- CRT edge fade

```glsl
// electrode-shaper-lite.glsl
// Lite variant: CRT artifacts only, no plasma/arcs/EMF.
// Drops: plasma field, electrode arcs, EMF interference (all noise removed).
```

- [ ] **Step 2: Verify shader loads in Ghostty**

- [ ] **Step 3: Commit**

```bash
git add shaders/electrode-shaper-lite.glsl
git commit -m "feat: add electrode-shaper-lite shader — CRT only, no plasma/arcs"
```

## Chunk 2: Static Shaders

### Task 5: street-shaman-static.glsl

**Files:**
- Create: `shaders/street-shaman-static.glsl`

- [ ] **Step 1: Create the static shader**

Minimal shader: sample texture, apply vignette, text protection. No `iTime` usage.

```glsl
// street-shaman-static.glsl
// Static variant: vignette + text protection only. No iTime dependency.
// Use with custom-shader-animation = false for near-zero GPU cost.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.299, 0.587, 0.114));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // Vignette
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vignette = smoothstep(0.78, 0.45, dist);
    color *= mix(0.6, 1.0, vignette);

    // Text protection
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
```

- [ ] **Step 2: Verify shader loads in Ghostty with `custom-shader-animation = false`**

- [ ] **Step 3: Commit**

```bash
git add shaders/street-shaman-static.glsl
git commit -m "feat: add street-shaman-static shader — vignette only, no animation"
```

### Task 6: feline-homunculus-static.glsl

**Files:**
- Create: `shaders/feline-homunculus-static.glsl`

- [ ] **Step 1: Create the static shader**

Same structure as street-shaman-static but with feline-homunculus vignette parameters (center offset at 0.55, 0.45; corner darkness floor 0.3).

```glsl
// feline-homunculus-static.glsl
// Static variant: asymmetric vignette + text protection only.
// Use with custom-shader-animation = false for near-zero GPU cost.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // Asymmetric vignette (darker top-left, lighter bottom-right)
    vec2 vignetteCenter = vec2(0.55, 0.45);
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.8, 0.35, vignetteDist);
    vignette = mix(0.3, 1.0, vignette);
    color *= vignette;

    // Text protection
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
```

- [ ] **Step 2: Verify in Ghostty**

- [ ] **Step 3: Commit**

```bash
git add shaders/feline-homunculus-static.glsl
git commit -m "feat: add feline-homunculus-static shader — vignette only"
```

### Task 7: deep-drift-static.glsl

**Files:**
- Create: `shaders/deep-drift-static.glsl`

- [ ] **Step 1: Create the static shader**

CRT theme — keeps barrel distortion, chromatic aberration, scanlines, burn-in, vignette, text protection. No `iTime`.

```glsl
// deep-drift-static.glsl
// Static variant: CRT barrel + chromatic aberration + scanlines + burn-in + vignette.
// No iTime dependency. Use with custom-shader-animation = false.

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

float burnIn(vec2 uv) {
    float burn = 0.0;
    float statusBar = smoothstep(0.005, 0.0, abs(uv.y - 0.82));
    burn += statusBar * 0.04;
    float borderL = smoothstep(0.006, 0.0, abs(uv.x - 0.05));
    float borderR = smoothstep(0.006, 0.0, abs(uv.x - 0.95));
    float borderT = smoothstep(0.006, 0.0, abs(uv.y - 0.95));
    float borderB = smoothstep(0.006, 0.0, abs(uv.y - 0.05));
    float vertRange = step(0.05, uv.y) * step(uv.y, 0.95);
    float horizRange = step(0.05, uv.x) * step(uv.x, 0.95);
    burn += (borderL + borderR) * vertRange * 0.03;
    burn += (borderT + borderB) * horizRange * 0.03;
    float cursorX = smoothstep(0.02, 0.0, abs(uv.x - 0.12));
    float cursorY = smoothstep(0.008, 0.0, abs(uv.y - 0.50));
    burn += cursorX * cursorY * 0.05;
    return burn;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;

    // Barrel distortion
    vec2 uv = barrelDistort(rawUV, 0.08);

    // Chromatic aberration
    vec2 fromCenter = uv - 0.5;
    float edgeDist = length(fromCenter);
    float aberration = edgeDist * 0.004;
    vec2 aberrationDir = normalize(fromCenter + 0.0001);

    float r = texture(iChannel0, uv + aberrationDir * aberration * 1.3).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - aberrationDir * aberration * 0.7).b;
    float a = texture(iChannel0, uv).a;

    vec4 clean = vec4(r, g, b, a);
    vec3 color = clean.rgb;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // Scanlines
    float scanline = 1.0 - 0.20 * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // Burn-in
    vec3 amberBurn = vec3(0.76, 0.64, 0.28);
    color += amberBurn * burnIn(uv);

    // Vignette
    float vignetteDist = length(rawUV - vec2(0.52, 0.53));
    float vignette = smoothstep(0.78, 0.25, vignetteDist);
    vignette = mix(0.15, 1.0, vignette);
    color *= vignette;

    // Text protection
    color = clamp(color, 0.0, 1.0);
    vec3 cleanText = texture(iChannel0, uv).rgb;
    color = mix(color, cleanText, textMask);

    // CRT edge fade
    float edgeFade = smoothstep(0.0, 0.015, uv.x) * smoothstep(1.0, 0.985, uv.x)
                   * smoothstep(0.0, 0.015, uv.y) * smoothstep(1.0, 0.985, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
```

- [ ] **Step 2: Verify in Ghostty**

- [ ] **Step 3: Commit**

```bash
git add shaders/deep-drift-static.glsl
git commit -m "feat: add deep-drift-static shader — CRT + burn-in, no animation"
```

### Task 8: electrode-shaper-static.glsl

**Files:**
- Create: `shaders/electrode-shaper-static.glsl`

- [ ] **Step 1: Create the static shader**

CRT theme — barrel distortion, chromatic aberration, scanlines, vignette, text protection. No burn-in (electrode-shaper full has none). No `iTime`.

```glsl
// electrode-shaper-static.glsl
// Static variant: CRT barrel + chromatic aberration + scanlines + vignette.
// No iTime dependency. Use with custom-shader-animation = false.

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;

    // Barrel distortion
    vec2 uv = barrelDistort(rawUV, 0.05);

    // Chromatic aberration
    vec2 fromCenter = uv - 0.5;
    float edgeDist = length(fromCenter);
    float aberration = edgeDist * 0.003;
    vec2 aberrationDir = normalize(fromCenter + 0.0001);

    float r = texture(iChannel0, uv + aberrationDir * aberration).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - aberrationDir * aberration).b;
    float a = texture(iChannel0, uv).a;

    vec4 clean = vec4(r, g, b, a);
    vec3 color = clean.rgb;

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // Scanlines
    float scanline = 1.0 - 0.15 * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // Vignette
    float vignetteDist = length(rawUV - 0.5);
    float vignette = smoothstep(0.75, 0.3, vignetteDist);
    vignette = mix(0.2, 1.0, vignette);
    color *= vignette;

    // Text protection
    color = clamp(color, 0.0, 1.0);
    vec3 cleanText = texture(iChannel0, uv).rgb;
    color = mix(color, cleanText, textMask);

    // CRT edge fade
    float edgeFade = smoothstep(0.0, 0.01, uv.x) * smoothstep(1.0, 0.99, uv.x)
                   * smoothstep(0.0, 0.01, uv.y) * smoothstep(1.0, 0.99, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
```

- [ ] **Step 2: Verify in Ghostty**

- [ ] **Step 3: Commit**

```bash
git add shaders/electrode-shaper-static.glsl
git commit -m "feat: add electrode-shaper-static shader — CRT only, no animation"
```

## Chunk 3: Theme Prompts

### Task 9: Move deep-drift prompt to prompts/

**Files:**
- Move: `deep-drift-prompt.sh` -> `prompts/deep-drift.sh`

- [ ] **Step 1: Create prompts directory and move file**

```bash
mkdir -p prompts
git mv deep-drift-prompt.sh prompts/deep-drift.sh
```

- [ ] **Step 2: Commit**

```bash
git commit -m "refactor: move deep-drift prompt to prompts/ directory"
```

### Task 10: street-shaman.sh prompt

**Files:**
- Create: `prompts/street-shaman.sh`

- [ ] **Step 1: Create the prompt script**

```bash
# street-shaman.sh — Occult Ritual Terminal Prompt
# Source this file to activate the street shaman prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/street-shaman.sh
#
# Renders:
#   ┌─[SIGIL ACTIVE]─[WARD:73%]─[ENCOUNTERS:12]─[MOON:WAXING]
#   └─╼ crashy@ritual:~ $

# Idempotency guard
[[ -n "$_STREET_SHAMAN_PROMPT_LOADED" ]] && return
_STREET_SHAMAN_PROMPT_LOADED=1

# Colors — neon green (matches street-shaman theme)
_SS_DIM=$'\e[32m'        # dim green
_SS_BRIGHT=$'\e[92m'     # bright green
_SS_RESET=$'\e[0m'

# Session state
_SS_WARD=$(( 60 + RANDOM % 36 ))       # 60-95
_SS_ENCOUNTERS=0

# Moon phase calculation — 8 phases from synodic month
_ss_moon_phase() {
    local now
    now=$(date +%s)
    # Known new moon: Jan 6, 2000 18:14 UTC = 947181240
    local ref=947181240
    local synodic=2551443  # 29.53059 days in seconds
    local age=$(( (now - ref) % synodic ))
    local phase=$(( age * 8 / synodic ))
    local phases=(NEW WAXING-CRESCENT FIRST-QTR WAXING-GIBBOUS FULL WANING-GIBBOUS LAST-QTR WANING-CRESCENT)
    echo "${phases[$((phase + 1))]}"
}

# Precmd hook
_street_shaman_precmd() {
    # Random walk WARD: drift -1 to +1, clamp 60-95
    local ward_drift=$(( (RANDOM % 3) - 1 ))
    _SS_WARD=$(( _SS_WARD + ward_drift ))
    (( _SS_WARD > 95 )) && _SS_WARD=95
    (( _SS_WARD < 60 )) && _SS_WARD=60

    # Increment encounter counter
    _SS_ENCOUNTERS=$(( _SS_ENCOUNTERS + 1 ))

    local moon
    moon=$(_ss_moon_phase)

    local line1="${_SS_DIM}┌─[${_SS_BRIGHT}SIGIL ACTIVE${_SS_DIM}]─[${_SS_BRIGHT}WARD:${_SS_WARD}%${_SS_DIM}]─[${_SS_BRIGHT}ENCOUNTERS:${_SS_ENCOUNTERS}${_SS_DIM}]─[${_SS_BRIGHT}MOON:${moon}${_SS_DIM}]${_SS_RESET}"
    local line2="${_SS_DIM}└─╼ ${_SS_RESET}%n@ritual:%~ ${_SS_BRIGHT}\$ ${_SS_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_street_shaman_precmd]} == 0 )); then
    precmd_functions+=(_street_shaman_precmd)
fi
```

- [ ] **Step 2: Verify prompt renders by sourcing**

```bash
source prompts/street-shaman.sh
```

Confirm two-line prompt appears with green text and all 4 status fields.

- [ ] **Step 3: Commit**

```bash
git add prompts/street-shaman.sh
git commit -m "feat: add street-shaman occult ritual prompt"
```

### Task 11: feline-homunculus.sh prompt

**Files:**
- Create: `prompts/feline-homunculus.sh`

- [ ] **Step 1: Create the prompt script**

```bash
# feline-homunculus.sh — Tokyo Street Navigation Prompt
# Source this file to activate the feline homunculus prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/feline-homunculus.sh
#
# Renders:
#   ┌─[SHINJUKU]─[RAIN:HEAVY]─[NEON:87%]─[ALLEY:DEEP]
#   └─╼ crashy@tokyo:~ $

# Idempotency guard
[[ -n "$_FELINE_HOMUNCULUS_PROMPT_LOADED" ]] && return
_FELINE_HOMUNCULUS_PROMPT_LOADED=1

# Colors — neon magenta/pink (matches feline-homunculus theme)
_FH_DIM=$'\e[35m'        # dim magenta
_FH_BRIGHT=$'\e[95m'     # bright magenta
_FH_RESET=$'\e[0m'

# Session state
_FH_RAIN_VAL=$(( 40 + RANDOM % 60 ))   # 40-99 (maps to labels)
_FH_NEON=$(( 70 + RANDOM % 30 ))       # 70-99
_FH_ALLEY_VAL=$(( 20 + RANDOM % 80 ))  # 20-99 (maps to labels)
_FH_CMD_COUNT=0

# District rotation list
_FH_DISTRICTS=(SHINJUKU AKIHABARA SHIBUYA KABUKICHO ROPPONGI IKEBUKURO)

# Precmd hook
_feline_homunculus_precmd() {
    # Increment command count
    _FH_CMD_COUNT=$(( _FH_CMD_COUNT + 1 ))

    # Rotate district every 10 commands
    local district_idx=$(( (_FH_CMD_COUNT / 10) % ${#_FH_DISTRICTS[@]} + 1 ))
    local district="${_FH_DISTRICTS[$district_idx]}"

    # Random walk RAIN: drift -2 to +2, clamp 20-99
    local rain_drift=$(( (RANDOM % 5) - 2 ))
    _FH_RAIN_VAL=$(( _FH_RAIN_VAL + rain_drift ))
    (( _FH_RAIN_VAL > 99 )) && _FH_RAIN_VAL=99
    (( _FH_RAIN_VAL < 20 )) && _FH_RAIN_VAL=20

    # Map rain value to label
    local rain_label
    if (( _FH_RAIN_VAL < 40 )); then rain_label="DRIZZLE"
    elif (( _FH_RAIN_VAL < 60 )); then rain_label="STEADY"
    elif (( _FH_RAIN_VAL < 80 )); then rain_label="HEAVY"
    else rain_label="DOWNPOUR"
    fi

    # Random walk NEON: drift -1 to +1, clamp 70-99
    local neon_drift=$(( (RANDOM % 3) - 1 ))
    _FH_NEON=$(( _FH_NEON + neon_drift ))
    (( _FH_NEON > 99 )) && _FH_NEON=99
    (( _FH_NEON < 70 )) && _FH_NEON=70

    # Random walk ALLEY: drift -2 to +2, clamp 20-99
    local alley_drift=$(( (RANDOM % 5) - 2 ))
    _FH_ALLEY_VAL=$(( _FH_ALLEY_VAL + alley_drift ))
    (( _FH_ALLEY_VAL > 99 )) && _FH_ALLEY_VAL=99
    (( _FH_ALLEY_VAL < 20 )) && _FH_ALLEY_VAL=20

    # Map alley value to label
    local alley_label
    if (( _FH_ALLEY_VAL < 40 )); then alley_label="SHALLOW"
    elif (( _FH_ALLEY_VAL < 60 )); then alley_label="WINDING"
    elif (( _FH_ALLEY_VAL < 80 )); then alley_label="DEEP"
    else alley_label="LABYRINTH"
    fi

    local line1="${_FH_DIM}┌─[${_FH_BRIGHT}${district}${_FH_DIM}]─[${_FH_BRIGHT}RAIN:${rain_label}${_FH_DIM}]─[${_FH_BRIGHT}NEON:${_FH_NEON}%${_FH_DIM}]─[${_FH_BRIGHT}ALLEY:${alley_label}${_FH_DIM}]${_FH_RESET}"
    local line2="${_FH_DIM}└─╼ ${_FH_RESET}%n@tokyo:%~ ${_FH_BRIGHT}\$ ${_FH_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_feline_homunculus_precmd]} == 0 )); then
    precmd_functions+=(_feline_homunculus_precmd)
fi
```

- [ ] **Step 2: Verify prompt renders by sourcing**

- [ ] **Step 3: Commit**

```bash
git add prompts/feline-homunculus.sh
git commit -m "feat: add feline-homunculus Tokyo navigation prompt"
```

### Task 12: electrode-shaper.sh prompt

**Files:**
- Create: `prompts/electrode-shaper.sh`

- [ ] **Step 1: Create the prompt script**

```bash
# electrode-shaper.sh — Lab Instrument Readout Prompt
# Source this file to activate the electrode shaper prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/electrode-shaper.sh
#
# Renders:
#   ┌─[PLASMA:92%]─[EMF:340mT]─[ARCS:7]─[FREQ:40.0Hz]
#   └─╼ crashy@lab:~ $

# Idempotency guard
[[ -n "$_ELECTRODE_SHAPER_PROMPT_LOADED" ]] && return
_ELECTRODE_SHAPER_PROMPT_LOADED=1

# Colors — cyan (matches electrode-shaper violet/cyan theme)
_ES_DIM=$'\e[36m'        # dim cyan
_ES_BRIGHT=$'\e[96m'     # bright cyan
_ES_RESET=$'\e[0m'

# Session state
_ES_PLASMA=$(( 80 + RANDOM % 20 ))     # 80-99
_ES_EMF=$(( 200 + (RANDOM % 16) * 20 ))  # 200-500 in steps of 20
_ES_ARCS=0

# Precmd hook
_electrode_shaper_precmd() {
    # Random walk PLASMA: drift -1 to +1, clamp 80-99
    local plasma_drift=$(( (RANDOM % 3) - 1 ))
    _ES_PLASMA=$(( _ES_PLASMA + plasma_drift ))
    (( _ES_PLASMA > 99 )) && _ES_PLASMA=99
    (( _ES_PLASMA < 80 )) && _ES_PLASMA=80

    # Random walk EMF: drift -20 to +20 (steps of 20), clamp 200-500
    local emf_drift=$(( ((RANDOM % 3) - 1) * 20 ))
    _ES_EMF=$(( _ES_EMF + emf_drift ))
    (( _ES_EMF > 500 )) && _ES_EMF=500
    (( _ES_EMF < 200 )) && _ES_EMF=200

    # Increment arc counter
    _ES_ARCS=$(( _ES_ARCS + 1 ))

    local line1="${_ES_DIM}┌─[${_ES_BRIGHT}PLASMA:${_ES_PLASMA}%${_ES_DIM}]─[${_ES_BRIGHT}EMF:${_ES_EMF}mT${_ES_DIM}]─[${_ES_BRIGHT}ARCS:${_ES_ARCS}${_ES_DIM}]─[${_ES_BRIGHT}FREQ:40.0Hz${_ES_DIM}]${_ES_RESET}"
    local line2="${_ES_DIM}└─╼ ${_ES_RESET}%n@lab:%~ ${_ES_BRIGHT}\$ ${_ES_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_electrode_shaper_precmd]} == 0 )); then
    precmd_functions+=(_electrode_shaper_precmd)
fi
```

- [ ] **Step 2: Verify prompt renders by sourcing**

- [ ] **Step 3: Commit**

```bash
git add prompts/electrode-shaper.sh
git commit -m "feat: add electrode-shaper lab instrument prompt"
```

## Chunk 4: Launcher Update and README

### Task 13: Update ghostty-random.sh with power tier support

**Files:**
- Modify: `ghostty-random.sh`

- [ ] **Step 1: Rewrite the launcher**

Replace the argument handling section. New logic:

1. Parse all args: flags (`--lite`, `--static`, `--full`, `--no-shader`) go to `$tier`, non-flag args go to `$theme_arg`.
2. Resolve tier: flag > `$GHOSTTY_POWER` > `full`.
3. Handle `list` command (unchanged).
4. Pick theme: `$theme_arg` or random.
5. Resolve shader path based on tier (with suffix for lite/static, omitted for no-shader).
6. Write config.
7. Print prompt hint if `prompts/${chosen}.sh` exists.

Full replacement script:

```bash
#!/usr/bin/env zsh
# ghostty-random.sh — Switch Ghostty theme live with power tier support.
# Rewrites ~/.config/ghostty/config; Ghostty auto-reloads on file change.
#
# Usage (via alias ghostty='~/.config/ghostty/ghostty-random.sh'):
#   ghostty                        # random theme, full shader
#   ghostty deep-drift             # specific theme, full shader
#   ghostty deep-drift --lite      # specific theme, reduced animation
#   ghostty deep-drift --static    # specific theme, no animation
#   ghostty --lite                 # random theme, lite shader
#   ghostty --no-shader            # random theme, theme colors only
#   ghostty list                   # show available themes
#
# Environment:
#   GHOSTTY_POWER=lite|static|full|no-shader   # default tier (flag overrides)

GHOSTTY_DIR="${HOME}/.config/ghostty"
THEMES_DIR="${GHOSTTY_DIR}/themes"
SHADERS_DIR="${GHOSTTY_DIR}/shaders"
PROMPTS_DIR="${GHOSTTY_DIR}/prompts"
CONFIG="${GHOSTTY_DIR}/config"

# --- Parse arguments ---
tier=""
theme_arg=""

for arg in "$@"; do
    case "$arg" in
        --lite)      tier="lite" ;;
        --static)    tier="static" ;;
        --full)      tier="full" ;;
        --no-shader) tier="no-shader" ;;
        *)           theme_arg="$arg" ;;
    esac
done

# Resolve tier: flag > env > default
if [[ -z "$tier" ]]; then
    tier="${GHOSTTY_POWER:-full}"
fi

# --- Discover available themes ---
themes=()
for theme_file in "${THEMES_DIR}"/*; do
    name="${theme_file:t}"
    if [[ -f "${SHADERS_DIR}/${name}.glsl" ]]; then
        themes+=("$name")
    fi
done

if (( ${#themes[@]} == 0 )); then
    echo "No theme+shader pairs found." >&2
    exit 1
fi

# --- Handle 'list' command ---
if [[ "$theme_arg" == "list" ]]; then
    echo "Available themes:"
    for t in "${themes[@]}"; do
        echo "  $t"
    done
    echo ""
    echo "Power tiers: --full (default), --lite, --static, --no-shader"
    echo "Env default: export GHOSTTY_POWER=lite"
    exit 0
fi

# --- Pick theme ---
if [[ -n "$theme_arg" ]]; then
    if [[ " ${themes[*]} " == *" $theme_arg "* ]]; then
        chosen="$theme_arg"
    else
        echo "Unknown theme: $theme_arg" >&2
        echo "Available: ${themes[*]}" >&2
        exit 1
    fi
else
    chosen="${themes[RANDOM % ${#themes[@]} + 1]}"
fi

# --- Pretty-print theme name ---
pretty="${chosen//-/ }"
pretty="${(C)pretty}"

# --- Resolve shader path ---
case "$tier" in
    full)
        shader="${SHADERS_DIR}/${chosen}.glsl"
        animation="true"
        ;;
    lite)
        shader="${SHADERS_DIR}/${chosen}-lite.glsl"
        animation="true"
        if [[ ! -f "$shader" ]]; then
            echo "No lite shader for ${chosen}, falling back to full." >&2
            shader="${SHADERS_DIR}/${chosen}.glsl"
        fi
        ;;
    static)
        shader="${SHADERS_DIR}/${chosen}-static.glsl"
        animation="false"
        if [[ ! -f "$shader" ]]; then
            echo "No static shader for ${chosen}, falling back to full." >&2
            shader="${SHADERS_DIR}/${chosen}.glsl"
            animation="true"
        fi
        ;;
    no-shader)
        shader=""
        animation=""
        ;;
    *)
        echo "Unknown tier: $tier" >&2
        echo "Valid: full, lite, static, no-shader" >&2
        exit 1
        ;;
esac

# --- Write config ---
if [[ -n "$shader" ]]; then
    cat > "${CONFIG}" <<EOF
# ${pretty} (${tier})
theme = ${chosen}
custom-shader = ${shader}
custom-shader-animation = ${animation}
EOF
else
    cat > "${CONFIG}" <<EOF
# ${pretty} (no shader)
theme = ${chosen}
EOF
fi

# --- Output ---
tier_label="${tier}"
[[ "$tier" == "full" ]] && tier_label=""
[[ -n "$tier_label" ]] && tier_label=" [${tier_label}]"

echo "🎨 ${pretty}${tier_label}  · Cmd+Shift+, to reload"

# Prompt hint
prompt_file="${PROMPTS_DIR}/${chosen}.sh"
if [[ -f "$prompt_file" ]]; then
    echo "🔤 source ${prompt_file}"
fi
```

- [ ] **Step 2: Verify launcher works**

Test these cases manually:
```bash
./ghostty-random.sh list
./ghostty-random.sh deep-drift
./ghostty-random.sh deep-drift --lite
./ghostty-random.sh deep-drift --static
./ghostty-random.sh --no-shader
./ghostty-random.sh --lite
cat config  # inspect output after each
```

- [ ] **Step 3: Commit**

```bash
git add ghostty-random.sh
git commit -m "feat: add power tier flags to launcher (--lite, --static, --no-shader)"
```

### Task 14: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README**

Replace the full README with updated content adding:
- All 4 themes in the table
- Power tiers section
- Prompts section
- Updated file structure
- Updated usage examples

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README with all themes, power tiers, and prompts"
```
