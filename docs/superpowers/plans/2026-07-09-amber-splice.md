# amber-splice Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new Ghostty theme, `amber-splice` — a DNA double helix suspended in amber, spliced with a cyan alien strand — as a full package matching the repo's per-theme convention.

**Architecture:** Five new files (palette, three shader tiers, prompt) plus README edits. The launcher `ghostty-random.sh` auto-discovers the theme from the `themes/amber-splice` + `shaders/amber-splice.glsl` pair, so it needs no changes. Shaders follow the established single-pass `mainImage` pattern with shared `hash21`/`noise` utilities, a 40 Hz gamma entrainment layer, and luminance-based text protection. The helix hero is pure sine math (no noise calls).

**Tech Stack:** GLSL (Ghostty/ShaderToy dialect: `iResolution`, `iTime`, `iChannel0`, `texture()`, `mainImage`), zsh (prompt), Ghostty config theme files, Markdown (README/docs).

**Verification model:** This repo has **no unit-test framework** and adding one would violate its conventions (YAGNI). Tasks are verified by (a) structural self-checks, (b) runnable commands where a real check exists (zsh sourcing for the prompt, launcher config-rewrite for integration), and (c) a **visual gate in Ghostty**: point `config` at the shader and confirm it renders with no red shader-compile-error overlay and text stays readable. "Commit" steps are per-task for frequent commits.

## Global Constraints

- All files live under `/Users/tech1/.config/ghostty/`. Theme base name is exactly `amber-splice` (files: `themes/amber-splice`, `shaders/amber-splice.glsl`, `shaders/amber-splice-lite.glsl`, `shaders/amber-splice-static.glsl`, `prompts/amber-splice.sh`).
- Shaders: no `#version` directive, no precision qualifiers (match existing shaders). Entry point `void mainImage(out vec4 fragColor, in vec2 fragCoord)`.
- Never use GLSL `pow(x, y)` where `x` can be negative — square by multiplication instead.
- Every animated shader ends with 40 Hz gamma entrainment (`GAMMA_HZ = 40.0`, `GAMMA_AMP = 0.035`) then text protection (`textMask = smoothstep(0.05, 0.12, luma)`, `color = mix(color, clean.rgb, textMask)`).
- The `-static` shader must contain **no `iTime` reference** and no gamma layer (used with `custom-shader-animation = false`).
- Work happens on branch `amber-splice-theme`. Do not stage or commit the pre-existing unrelated `M config` change.
- Commit messages end with the `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer.

---

### Task 1: Color palette

**Files:**
- Create: `themes/amber-splice`

**Interfaces:**
- Consumes: nothing.
- Produces: a Ghostty theme file the launcher discovers by name; pairs with `shaders/amber-splice.glsl`.

- [ ] **Step 1: Create the palette file**

Create `themes/amber-splice` with exactly this content:

```
background = #0c0906
foreground = #ecc87f
cursor-color = #ffb838
cursor-text = #0c0906
selection-background = #2a1c0c
selection-foreground = #ffd98a

# ANSI Normal (0-7)
palette = 0=#1c140a
palette = 1=#c85a2e
palette = 2=#9ea63e
palette = 3=#d4a634
palette = 4=#2e8ea8
palette = 5=#a05e8e
palette = 6=#3ec8c0
palette = 7=#d8c8a8

# ANSI Bright (8-15)
palette = 8=#3a2c1a
palette = 9=#e87a4e
palette = 10=#bec858
palette = 11=#f0c848
palette = 12=#4eb0d0
palette = 13=#c07eb0
palette = 14=#5ee0d8
palette = 15=#f4e8cc
```

- [ ] **Step 2: Verify the format matches an existing theme**

Run: `diff <(grep -cE '^(background|foreground|cursor-color|cursor-text|selection-background|selection-foreground|palette) ' themes/amber-splice) <(grep -cE '^(background|foreground|cursor-color|cursor-text|selection-background|selection-foreground|palette) ' themes/night-temple)`
Expected: no output (both files have the same count of 22 directive lines).

- [ ] **Step 3: Commit**

```bash
git add themes/amber-splice
git commit -m "$(cat <<'EOF'
feat: add amber-splice color palette

Amber-black/gold with cyan alien accent in ANSI 4/6/12/14.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Full shader

**Files:**
- Create: `shaders/amber-splice.glsl`

**Interfaces:**
- Consumes: `themes/amber-splice` (they form the launcher-discovered pair).
- Produces: the full-tier shader. Establishes the helix math (`cx=0.5`, `R=0.13`, `twist=6.0*2.0*PI`, `phaseY=(uv.y+time*0.05)*twist+time*0.6`, strand half-width `w=0.010`, gold `vec3(0.95,0.68,0.22)`, alien cyan `vec3(0.25,0.85,0.90)`) reused verbatim by Tasks 3 and 4.

- [ ] **Step 1: Create the full shader**

Create `shaders/amber-splice.glsl` with exactly this content:

```glsl
// amber-splice.glsl
// Theme: Amber Splice — a DNA double helix suspended in amber, spliced with alien DNA.
// Jurassic-Park genetics-lab amber (mosquito-in-amber gold, drifting inclusions) crossed
// with a Spielberg backlight glow and a Cowboys-&-Aliens cyan energy pulse.
// Single-pass fragment shader for Ghostty with 5 composited layers:
// amber wash, suspended motes, gold double helix, alien cyan strand + traveling splice
// pulse, amber vignette, 40 Hz gamma entrainment, and luminance-based text protection.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// ---------------------------------------------------------------------------
// Noise utilities
// ---------------------------------------------------------------------------

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // --- Text detection ---
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // -----------------------------------------------------------------------
    // Layer 1 — Amber depth wash (light through resin)
    // -----------------------------------------------------------------------
    vec3 amberWarm = vec3(0.55, 0.35, 0.10);
    float wash = noise(uv * 2.5 + vec2(0.0, time * 0.05));
    color += amberWarm * wash * 0.05;

    // -----------------------------------------------------------------------
    // Layer 2 — Suspended motes (gold inclusions drifting upward)
    // -----------------------------------------------------------------------
    float moteDensity = 90.0;
    vec2 moteUV = uv + vec2(0.0, time * 0.02);
    vec2 moteCell = floor(moteUV * moteDensity);
    float moteHash = hash21(moteCell);
    if (moteHash > 0.99) {
        float tw = 0.5 + 0.5 * sin(time * (0.8 + moteHash) + moteHash * 6.28);
        color += vec3(0.95, 0.70, 0.30) * tw * 0.35;
    }

    // -----------------------------------------------------------------------
    // Layer 3 — DNA double helix (HERO)
    // -----------------------------------------------------------------------
    float cx = 0.5;
    float R = 0.13;
    float twist = 6.0 * 2.0 * PI;
    float phaseY = (uv.y + time * 0.05) * twist + time * 0.6;

    float xA = cx + R * sin(phaseY);
    float xB = cx + R * sin(phaseY + PI);

    float depthA = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY));
    float depthB = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI));

    float w = 0.010;
    float glowA = smoothstep(w, 0.0, abs(uv.x - xA)) * depthA;
    float glowB = smoothstep(w, 0.0, abs(uv.x - xB)) * depthB;

    float beads = 0.5 + 0.5 * sin(phaseY * 3.0);
    float node = pow(beads, 6.0);

    vec3 goldStrand = vec3(0.95, 0.68, 0.22);
    color += goldStrand * (glowA + glowB) * (0.06 + 0.10 * node);

    // base-pair rungs
    float rungGate = pow(0.5 + 0.5 * sin(phaseY * 3.0 + PI * 0.5), 8.0);
    float betweenX = smoothstep(0.0, 0.01, uv.x - min(xA, xB)) *
                     smoothstep(0.0, 0.01, max(xA, xB) - uv.x);
    color += goldStrand * rungGate * betweenX * 0.04;

    // -----------------------------------------------------------------------
    // Layer 4 — Alien splice strand + traveling pulse
    // -----------------------------------------------------------------------
    float xC = cx + (R * 0.7) * sin(phaseY + PI * 0.66);
    float depthC = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI * 0.66));
    float glowC = smoothstep(0.008, 0.0, abs(uv.x - xC)) * depthC;
    float alienPulse = 0.6 + 0.4 * sin(time * 2.0);
    vec3 alienCyan = vec3(0.25, 0.85, 0.90);
    color += alienCyan * glowC * 0.07 * alienPulse;

    // traveling splice pulse — square by multiplication (GLSL pow(x,y) is undefined for x<0)
    float pulseY = fract(time * 0.18);
    float pd = (uv.y - pulseY) * 6.0;
    float pulse = exp(-pd * pd);
    vec3 spliceWhite = vec3(0.7, 0.9, 1.0);
    color += spliceWhite * pulse * (glowA + glowB + glowC * 1.5) * 0.5;

    // -----------------------------------------------------------------------
    // Layer 5 — Amber vignette
    // -----------------------------------------------------------------------
    vec2 vc = vec2(0.5, 0.5);
    float vDist = length(uv - vc);
    float vig = smoothstep(0.85, 0.20, vDist);
    vig = mix(0.15, 1.0, vig);
    color *= vig;

    // -----------------------------------------------------------------------
    // 40 Hz Gamma Entrainment
    // -----------------------------------------------------------------------
    float g = sin(2.0 * PI * GAMMA_HZ * time);
    float periphery = smoothstep(0.15, 0.5, vDist);
    color *= 1.0 + GAMMA_AMP * g * periphery;

    // --- Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
```

- [ ] **Step 2: Structural self-check**

Run: `awk '{o+=gsub(/{/,"{"); c+=gsub(/}/,"}")} END{print o, c}' shaders/amber-splice.glsl`
Expected: `4 4` (braces balanced: hash21, noise, the `if`, and mainImage).

Also confirm the entry point exists:
Run: `grep -c 'void mainImage(out vec4 fragColor, in vec2 fragCoord)' shaders/amber-splice.glsl`
Expected: `1`

- [ ] **Step 3: Visual gate in Ghostty**

Point the live config at the new shader and confirm it renders:
```bash
cp config /tmp/amber-splice-config.bak
printf 'custom-shader = %s/shaders/amber-splice.glsl\ncustom-shader-animation = true\n' "$PWD" > /tmp/amber-splice-config.frag
```
Then, in an open Ghostty window, temporarily set `custom-shader` to `shaders/amber-splice.glsl` and `custom-shader-animation = true` (Ghostty hot-reloads on save). Confirm:
- No red shader-compile-error text overlay.
- A gold double helix winds/drifts vertically, a fainter cyan strand is woven in, and a soft blue-white pulse travels up roughly every ~5s.
- Terminal text remains readable over the effect.

Expected: all three confirmed. (Restore your previous `config` afterward.)

- [ ] **Step 4: Commit**

```bash
git add shaders/amber-splice.glsl
git commit -m "$(cat <<'EOF'
feat: add amber-splice full shader

Amber wash, suspended motes, gold double helix, cyan alien splice
strand + traveling pulse, amber vignette, 40Hz gamma, text protection.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Lite shader

**Files:**
- Create: `shaders/amber-splice-lite.glsl`

**Interfaces:**
- Consumes: the helix math constants from Task 2 (`cx`, `R`, `twist`, `phaseY`, `w`, `goldStrand`, `alienCyan`) — copied verbatim.
- Produces: the lite-tier shader.

- [ ] **Step 1: Create the lite shader**

Create `shaders/amber-splice-lite.glsl` with exactly this content:

```glsl
// amber-splice-lite.glsl
// Lite variant: DNA helix (gold double strand + cyan alien strand + nodes) + amber vignette.
// Drops: amber wash, suspended motes, base-pair rungs, traveling splice pulse.
// Effects: helix (0 noise calls — pure sine math), amber vignette, 40 Hz gamma, text protection.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// ---------------------------------------------------------------------------
// Noise utilities
// ---------------------------------------------------------------------------

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // --- Layer: DNA helix (gold double strand + nodes) ---
    float cx = 0.5;
    float R = 0.13;
    float twist = 6.0 * 2.0 * PI;
    float phaseY = (uv.y + time * 0.05) * twist + time * 0.6;

    float xA = cx + R * sin(phaseY);
    float xB = cx + R * sin(phaseY + PI);
    float depthA = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY));
    float depthB = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI));
    float w = 0.010;
    float glowA = smoothstep(w, 0.0, abs(uv.x - xA)) * depthA;
    float glowB = smoothstep(w, 0.0, abs(uv.x - xB)) * depthB;
    float beads = 0.5 + 0.5 * sin(phaseY * 3.0);
    float node = pow(beads, 6.0);
    vec3 goldStrand = vec3(0.95, 0.68, 0.22);
    color += goldStrand * (glowA + glowB) * (0.06 + 0.10 * node);

    // --- Layer: alien cyan strand ---
    float xC = cx + (R * 0.7) * sin(phaseY + PI * 0.66);
    float depthC = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI * 0.66));
    float glowC = smoothstep(0.008, 0.0, abs(uv.x - xC)) * depthC;
    float alienPulse = 0.6 + 0.4 * sin(time * 2.0);
    vec3 alienCyan = vec3(0.25, 0.85, 0.90);
    color += alienCyan * glowC * 0.07 * alienPulse;

    // --- Layer: amber vignette ---
    vec2 vc = vec2(0.5, 0.5);
    float vDist = length(uv - vc);
    float vig = smoothstep(0.85, 0.20, vDist);
    vig = mix(0.15, 1.0, vig);
    color *= vig;

    // --- 40 Hz Gamma Entrainment ---
    float g = sin(2.0 * PI * GAMMA_HZ * time);
    float periphery = smoothstep(0.15, 0.5, vDist);
    color *= 1.0 + GAMMA_AMP * g * periphery;

    // --- Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
```

- [ ] **Step 2: Structural self-check**

Run: `awk '{o+=gsub(/{/,"{"); c+=gsub(/}/,"}")} END{print o, c}' shaders/amber-splice-lite.glsl`
Expected: `3 3` (hash21, noise, mainImage — no `if` in lite).

- [ ] **Step 3: Visual gate in Ghostty**

Set `custom-shader = shaders/amber-splice-lite.glsl`, `custom-shader-animation = true`. Confirm: no error overlay; the gold double helix + cyan strand animate (no motes, no traveling pulse, no rungs); text readable.
Expected: confirmed.

- [ ] **Step 4: Commit**

```bash
git add shaders/amber-splice-lite.glsl
git commit -m "$(cat <<'EOF'
feat: add amber-splice lite shader

Helix (gold double + cyan alien strand) + amber vignette + gamma.
Drops wash, motes, rungs, and traveling splice pulse.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Static shader

**Files:**
- Create: `shaders/amber-splice-static.glsl`

**Interfaces:**
- Consumes: the helix math from Task 2, with all time terms removed (`phaseY = uv.y * twist`).
- Produces: the static-tier shader with no `iTime` and no gamma layer.

- [ ] **Step 1: Create the static shader**

Create `shaders/amber-splice-static.glsl` with exactly this content:

```glsl
// amber-splice-static.glsl
// Static variant: frozen DNA helix + amber vignette + text protection.
// No iTime dependency. Use with custom-shader-animation = false.

const float PI = 3.14159265359;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // Frozen helix (phase at t=0)
    float cx = 0.5;
    float R = 0.13;
    float twist = 6.0 * 2.0 * PI;
    float phaseY = uv.y * twist;

    float xA = cx + R * sin(phaseY);
    float xB = cx + R * sin(phaseY + PI);
    float depthA = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY));
    float depthB = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI));
    float w = 0.010;
    float glowA = smoothstep(w, 0.0, abs(uv.x - xA)) * depthA;
    float glowB = smoothstep(w, 0.0, abs(uv.x - xB)) * depthB;
    vec3 goldStrand = vec3(0.95, 0.68, 0.22);
    color += goldStrand * (glowA + glowB) * 0.05;

    // Frozen alien cyan strand
    float xC = cx + (R * 0.7) * sin(phaseY + PI * 0.66);
    float depthC = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI * 0.66));
    float glowC = smoothstep(0.008, 0.0, abs(uv.x - xC)) * depthC;
    color += vec3(0.25, 0.85, 0.90) * glowC * 0.04;

    // Amber vignette
    vec2 vc = vec2(0.5, 0.5);
    float vDist = length(uv - vc);
    float vig = smoothstep(0.85, 0.20, vDist);
    vig = mix(0.15, 1.0, vig);
    color *= vig;

    // Text protection
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
```

- [ ] **Step 2: Verify no iTime dependency**

Run: `grep -c 'iTime' shaders/amber-splice-static.glsl`
Expected: `0`

Run: `awk '{o+=gsub(/{/,"{"); c+=gsub(/}/,"}")} END{print o, c}' shaders/amber-splice-static.glsl`
Expected: `1 1` (only mainImage).

- [ ] **Step 3: Visual gate in Ghostty**

Set `custom-shader = shaders/amber-splice-static.glsl`, `custom-shader-animation = false`. Confirm: no error overlay; a faint frozen helix + amber vignette; nothing animates; text readable.
Expected: confirmed.

- [ ] **Step 4: Commit**

```bash
git add shaders/amber-splice-static.glsl
git commit -m "$(cat <<'EOF'
feat: add amber-splice static shader

Frozen helix + amber vignette, no iTime, no animation.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Field-lab prompt

**Files:**
- Create: `prompts/amber-splice.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: a sourceable zsh prompt defining `_amber_splice_precmd` and guard var `_AMBER_SPLICE_PROMPT_LOADED`.

- [ ] **Step 1: Create the prompt**

Create `prompts/amber-splice.sh` with exactly this content:

```bash
# amber-splice.sh — Amber Splice Genetics Field-Lab Prompt
# Source this file to activate the genetics field-lab prompt.
#
# Usage:
#   source ~/.config/ghostty/prompts/amber-splice.sh
#
# Renders:
#   ┌─⌬─[AMBER FIELD LAB]─[SITE·B]─[SEQ 63%]─[VIABILITY:88%]─[SPLICE:α-9]─⌬─
#   └─⌖ user@lab:~ $

# Idempotency guard
[[ -n "$_AMBER_SPLICE_PROMPT_LOADED" ]] && return
_AMBER_SPLICE_PROMPT_LOADED=1

# Colors — amber gold (matches amber-splice theme) + cyan alien accent
_AS_DIM=$'\e[33m'        # dim gold
_AS_BRIGHT=$'\e[93m'     # bright gold
_AS_CYAN=$'\e[36m'       # alien cyan
_AS_RESET=$'\e[0m'

# Session state
_AS_SEQ=$(( RANDOM % 100 ))             # 0-99 sequencing progress
_AS_VIABILITY=$(( 70 + RANDOM % 30 ))   # 70-99
_AS_CMD_COUNT=0

# Splice strain codes — cycle through 4
_AS_STRAINS=('α-9' 'β-2' 'Δ-7' 'Ω-1')

# Precmd hook
_amber_splice_precmd() {
    _AS_CMD_COUNT=$(( _AS_CMD_COUNT + 1 ))

    # SEQ: climb +0..+3, wrap at 100 (a sequencing run completing and restarting)
    local seq_drift=$(( RANDOM % 4 ))
    _AS_SEQ=$(( (_AS_SEQ + seq_drift) % 100 ))

    # VIABILITY random walk -2..+2, clamp 40-99
    local via_drift=$(( (RANDOM % 5) - 2 ))
    _AS_VIABILITY=$(( _AS_VIABILITY + via_drift ))
    (( _AS_VIABILITY > 99 )) && _AS_VIABILITY=99
    (( _AS_VIABILITY < 40 )) && _AS_VIABILITY=40

    # Strain — cycles every 8 commands
    local strain_idx=$(( (_AS_CMD_COUNT / 8) % ${#_AS_STRAINS[@]} + 1 ))
    local strain="${_AS_STRAINS[$strain_idx]}"

    # Build the prompt
    local line1="${_AS_DIM}┌─${_AS_BRIGHT}⌬${_AS_DIM}─[${_AS_BRIGHT}AMBER FIELD LAB${_AS_DIM}]─[${_AS_BRIGHT}SITE·B${_AS_DIM}]─[${_AS_BRIGHT}SEQ ${_AS_SEQ}%${_AS_DIM}]─[${_AS_BRIGHT}VIABILITY:${_AS_VIABILITY}%${_AS_DIM}]─[${_AS_CYAN}SPLICE:${strain}${_AS_DIM}]─${_AS_BRIGHT}⌬${_AS_DIM}─${_AS_RESET}"
    local line2="${_AS_DIM}└─${_AS_BRIGHT}⌖ ${_AS_RESET}%n@lab:%~ ${_AS_BRIGHT}\$ ${_AS_RESET}"

    PROMPT=$'\n'"${line1}"$'\n'"${line2}"
}

# Register precmd hook (idempotent)
if (( ${precmd_functions[(I)_amber_splice_precmd]} == 0 )); then
    precmd_functions+=(_amber_splice_precmd)
fi
```

- [ ] **Step 2: Verify it sources, renders, and is idempotent**

Run:
```bash
zsh -c '
autoload -Uz add-zsh-hook 2>/dev/null
source prompts/amber-splice.sh
source prompts/amber-splice.sh   # second source must be a no-op
_amber_splice_precmd
print -r -- "PROMPT=$PROMPT"
print -r -- "hook_count=${precmd_functions[(I)_amber_splice_precmd]}"
'
```
Expected: `PROMPT=` line contains `AMBER FIELD LAB`, `SEQ`, `VIABILITY:`, and `SPLICE:`; `hook_count=1` (registered exactly once despite double-source).

- [ ] **Step 3: Commit**

```bash
git add prompts/amber-splice.sh
git commit -m "$(cat <<'EOF'
feat: add amber-splice field-lab prompt

Two-line genetics field-lab prompt: SEQ%, VIABILITY%, cycling SPLICE
strain. Idempotent precmd hook, amber-gold + cyan accent.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: README + end-to-end launcher verification

**Files:**
- Modify: `README.md` (three sections: Themes table, Prompts table, File Structure)

**Interfaces:**
- Consumes: all files from Tasks 1–5.
- Produces: documentation; final integration gate confirming the launcher discovers and wires up the theme.

- [ ] **Step 1: Add the Themes table row**

In `README.md`, find the line:
```
| **night-temple** | Egyptian night ritual. Torchlit temple, starfield, Nile reflections, hieroglyphic prompt. |
```
Add immediately after it:
```
| **amber-splice** | Jurassic DNA-expansion aliens. Gold double helix in amber, cyan alien splice strand, traveling splice pulse. |
```

- [ ] **Step 2: Add the Prompts table row**

In `README.md`, find the line:
```
| **night-temple** | Hieroglyphic temple ritual | 𓇳 Hour, 𓂓 KA strength, 𓎂 ward glyph, 𓁹 Eye of Horus |
```
Add immediately after it:
```
| **amber-splice** | Genetics field-lab console | SEQ%, VIABILITY%, SPLICE strain |
```

- [ ] **Step 3: Add the File Structure entries**

In `README.md` File Structure block, after the line `  night-temple                  # Color palette` add:
```
  amber-splice                  # Color palette
```
After the line `  night-temple-static.glsl      # Static: stone vignette only` add:
```
  amber-splice.glsl             # Full: amber + motes + helix + splice pulse
  amber-splice-lite.glsl        # Lite: helix + amber vignette
  amber-splice-static.glsl      # Static: frozen helix + vignette
```
After the line `  night-temple.sh               # Hieroglyphic temple prompt` add:
```
  amber-splice.sh               # Genetics field-lab prompt
```

- [ ] **Step 4: Verify the launcher discovers and wires the theme**

Run: `./ghostty-random.sh list`
Expected: output includes `amber-splice`.

Run (writes `config`, then inspect what it wired — this is what the launcher is for):
```bash
./ghostty-random.sh amber-splice --static
grep -E 'custom-shader|custom-shader-animation' config
```
Expected: `custom-shader` points at `shaders/amber-splice-static.glsl` and `custom-shader-animation = false`.

Run:
```bash
./ghostty-random.sh amber-splice --full
grep -E 'custom-shader|custom-shader-animation' config
```
Expected: `custom-shader` points at `shaders/amber-splice.glsl` and `custom-shader-animation = true`.

- [ ] **Step 5: Verify README markdown**

Run: `grep -c 'amber-splice' README.md`
Expected: `6` (1 Themes row + 1 Prompts row + 4 File Structure lines = 6 occurrences of the string `amber-splice`).

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: add amber-splice to README

Themes table, Prompts table, and File Structure entries.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- Palette → Task 1. ✓
- Full shader (5 layers + gamma + text protection) → Task 2. ✓
- Lite shader → Task 3. ✓
- Static shader (no iTime) → Task 4. ✓
- Prompt (SEQ/VIABILITY/SPLICE, idempotent) → Task 5. ✓
- README (three sections) → Task 6. ✓
- Launcher needs no changes → verified end-to-end in Task 6. ✓
- Success criteria 1–6 from spec all map to task verification steps. ✓

**Type/name consistency:** Helix constants (`cx`, `R`, `twist`, `phaseY`, `w`, `goldStrand`, `alienCyan`) are identical across Tasks 2/3/4; static drops the time terms as specified. Prompt function `_amber_splice_precmd` and guard `_AMBER_SPLICE_PROMPT_LOADED` used consistently.

**Placeholder scan:** No TBD/TODO; every code step contains complete file content; every verification step has an exact command and expected output.
