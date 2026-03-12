# Deep Drift Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 90s deep-space terminal theme for Ghostty — degraded amber CRT shader, color palette, and ship console shell prompt.

**Architecture:** Three files following the established theme pattern: a Ghostty theme file (color palette), a GLSL fragment shader (7 composited layers), and a zsh prompt script. The shader builds layer-by-layer, each committed independently.

**Tech Stack:** Ghostty config, GLSL (Ghostty's single-pass fragment shader API), zsh

---

### Task 1: Color Theme File

**Files:**
- Create: `themes/deep-drift`

- [ ] **Step 1: Create the theme palette**

```
background = #0b0a08
foreground = #c4a348
cursor-color = #e8a010
cursor-text = #0b0a08
selection-background = #2a1e08
selection-foreground = #e8c860

# ANSI Normal (0-7)
palette = 0=#0b0a08
palette = 1=#a03020
palette = 2=#2d8a4e
palette = 3=#c4a348
palette = 4=#1a7a8a
palette = 5=#8a4a78
palette = 6=#2a8a7a
palette = 7=#8a7a58

# ANSI Bright (8-15)
palette = 8=#2a2418
palette = 9=#c84830
palette = 10=#40b868
palette = 11=#e8c860
palette = 12=#28a0b8
palette = 13=#b068a0
palette = 14=#40b8a8
palette = 15=#c4a348
```

- [ ] **Step 2: Commit**

```bash
git add themes/deep-drift
git commit -m "feat: add deep-drift color theme — degraded amber phosphor palette"
```

---

### Task 2: Shader Foundation — CRT Artifacts (Layer 1)

**Files:**
- Create: `shaders/deep-drift.glsl`

- [ ] **Step 1: Create shader with noise utilities + CRT layer**

The foundation: hash/noise functions, barrel distortion (0.08 strength), chromatic aberration (warm-shifted), thick scanlines (20%), and text detection mask.

- [ ] **Step 2: Wire up config and verify visually**

Update `config` to point at deep-drift theme + shader. Open Ghostty and verify CRT curvature, scanlines, and chromatic fringing are visible.

- [ ] **Step 3: Commit**

```bash
git add shaders/deep-drift.glsl config
git commit -m "feat: add deep-drift shader with CRT scanlines, barrel distortion, chromatic aberration"
```

---

### Task 3: Phosphor Burn-In (Layer 2)

**Files:**
- Modify: `shaders/deep-drift.glsl`

- [ ] **Step 1: Add burn-in layer**

Static ghostly shapes — a faint horizontal line at y≈0.2 (old status bar) and a faint rectangular border near edges. Amber-tinted, opacity 0.03-0.05. These are fixed in UV space, never animated.

- [ ] **Step 2: Verify visually**

Squint at the screen — should see very faint amber ghosts. If too strong, dial back opacity.

- [ ] **Step 3: Commit**

```bash
git add shaders/deep-drift.glsl
git commit -m "feat: add phosphor burn-in ghosts to deep-drift"
```

---

### Task 4: Power Supply Flicker (Layer 3)

**Files:**
- Modify: `shaders/deep-drift.glsl`

- [ ] **Step 1: Add power supply flicker**

Noise-driven brightness envelope. Uses low-frequency noise to create organic brightness dips to ~85%, recovering over 0.5-1.5s. Roughly every 4-8 seconds. Applied as a multiplier to the entire frame.

- [ ] **Step 2: Verify visually**

Watch for 30+ seconds. Should see occasional gentle brightness dips, not rhythmic.

- [ ] **Step 3: Commit**

```bash
git add shaders/deep-drift.glsl
git commit -m "feat: add power supply flicker to deep-drift"
```

---

### Task 5: Deep Space Radiation Static (Layer 4)

**Files:**
- Modify: `shaders/deep-drift.glsl`

- [ ] **Step 1: Add radiation static bursts**

Hash-based random pixels that flash white in brief bursts. Bursts last 0.1-0.3s, every 5-10s. Concentrated in random rectangular patches. Low density per burst (2-5% of patch pixels).

- [ ] **Step 2: Verify visually**

Wait for a burst — should see a brief rectangular patch of white pixel noise, then gone.

- [ ] **Step 3: Commit**

```bash
git add shaders/deep-drift.glsl
git commit -m "feat: add cosmic radiation static bursts to deep-drift"
```

---

### Task 6: Horizontal Sync Wobble (Layer 5)

**Files:**
- Modify: `shaders/deep-drift.glsl`

- [ ] **Step 1: Add H-sync wobble**

Subtle horizontal displacement — entire scanline rows shift left/right by 1-3 pixels. The wobble zone is a band ~10% of screen height that drifts vertically over time (period ~15-20s). Very subtle displacement.

- [ ] **Step 2: Verify visually**

Look for slight horizontal jitter in a band that slowly moves up/down the screen.

- [ ] **Step 3: Commit**

```bash
git add shaders/deep-drift.glsl
git commit -m "feat: add horizontal sync wobble to deep-drift"
```

---

### Task 7: Vignette + Gamma + Text Protection (Layers 6-7)

**Files:**
- Modify: `shaders/deep-drift.glsl`

- [ ] **Step 1: Add aggressive vignette**

Heavy corner darkening — corners drop to ~15% brightness. Slightly asymmetric: bottom-left is worse (use an offset center for the vignette calculation).

- [ ] **Step 2: Add 40Hz gamma entrainment**

Same convention as other themes: 3.5% sinusoidal at 40Hz, weighted to periphery.

- [ ] **Step 3: Add text protection**

Luminance-based text mask. Mix clean texture back over all effects where text is detected. Plus CRT edge fade for barrel distortion bounds.

- [ ] **Step 4: Verify visually**

Confirm text is crisp, vignette is visible (especially bottom-left), and overall effect is cohesive.

- [ ] **Step 5: Commit**

```bash
git add shaders/deep-drift.glsl
git commit -m "feat: add vignette, gamma entrainment, and text protection to deep-drift"
```

---

### Task 8: Shell Prompt Script

**Files:**
- Create: `deep-drift-prompt.sh`

- [ ] **Step 1: Create the prompt script**

Sourceable zsh script that sets precmd and PS1:
- SOL counter: `$(( ($(date +%s) - 820454400) / 86400 ))` (days since Jan 1 1996)
- O2: seeded random walk 91-97% (use $RANDOM with session seed)
- HULL: seeded random walk 82-91%
- Two-line prompt with box-drawing characters
- Amber ANSI coloring using the theme's palette

- [ ] **Step 2: Verify by sourcing**

```bash
source deep-drift-prompt.sh
```

Confirm prompt renders correctly with SOL count, O2, hull values.

- [ ] **Step 3: Commit**

```bash
git add deep-drift-prompt.sh
git commit -m "feat: add USS Erebus ship console prompt for deep-drift"
```

---

### Task 9: Final Integration

- [ ] **Step 1: Switch to theme using ghostty-random.sh**

```bash
./ghostty-random.sh deep-drift
```

Verify config is rewritten correctly and Ghostty reloads with full theme.

- [ ] **Step 2: Source prompt and verify full experience**

```bash
source deep-drift-prompt.sh
```

Confirm everything works together — shader effects, color palette, ship prompt.
