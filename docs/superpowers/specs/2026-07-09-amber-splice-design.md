# amber-splice — Design Spec

**Date:** 2026-07-09
**Theme:** `amber-splice`
**Vibe:** A DNA double helix suspended in amber, being spliced with alien DNA. Jurassic-Park genetics-lab awe (mosquito-in-amber gold, drifting inclusions) crossed with a Spielberg backlight glow and a Cowboys-&-Aliens cyan energy pulse that runs up the helix as the "expansion" fires.

## Concept

Steven Spielberg mashup — *Cowboys & Aliens* meets *Jurassic Park* DNA-expansion — with the aliens/genetics dialed up. The hero is a slowly winding, drifting **double helix** rendered from pure sine math (no noise calls), suspended in a warm amber field. A third **cyan alien strand** is woven into the helix (the "DNA expansion"), and periodically a **blue-white splice pulse** travels up the helix and flares the alien strand.

Design principle: the hero layer (helix) is noise-free and cheap, so even the full tier stays affordable. All effects are additive at low intensity and gated by luminance-based text protection, so text remains readable.

## Deliverables

Matches the existing per-theme package convention (see `README.md` File Structure):

| File | Purpose |
|------|---------|
| `themes/amber-splice` | Color palette |
| `shaders/amber-splice.glsl` | Full: amber wash + motes + helix + alien splice/pulse + vignette |
| `shaders/amber-splice-lite.glsl` | Lite: simplified helix + vignette |
| `shaders/amber-splice-static.glsl` | Static: frozen helix + vignette, no `iTime` |
| `prompts/amber-splice.sh` | Frontier genetics field-lab prompt |
| `README.md` | Add rows to Themes table, Prompts table, File Structure |
| this spec | Design record |

The launcher (`ghostty-random.sh`) needs **no changes** — it auto-discovers any `themes/<name>` that has a matching `shaders/<name>.glsl`.

## 1. Palette (`themes/amber-splice`)

Amber-black background, warm amber-gold foreground, cyan/teal as the alien-splice accent, rust for red. Same file format as other themes (background, foreground, cursor, selection, ANSI 0–15).

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

Rationale: slots 4/6/12/14 (blue/cyan) carry the alien accent so terminal output picks up the theme; everything else stays in the warm amber/rust/gold band.

## 2. Full shader (`shaders/amber-splice.glsl`)

Single-pass fragment shader, `mainImage(out vec4 fragColor, in vec2 fragCoord)`, following the house header-comment + shared noise-utility convention (`hash21`, `noise`) used by the other shaders. Constants:

```glsl
const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;
```

Preamble (identical pattern to other shaders):

```glsl
vec2 uv = fragCoord / iResolution.xy;
float time = iTime;
vec4 clean = texture(iChannel0, uv);
float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
float textMask = smoothstep(0.05, 0.12, luma);
vec3 color = clean.rgb;
```

### Layer 1 — Amber depth wash
A slow warm caustic gradient (light through resin). One `noise` call, low amplitude. Warms the whole frame toward amber and gives subtle motion.

```glsl
vec3 amberWarm = vec3(0.55, 0.35, 0.10);
float wash = noise(uv * 2.5 + vec2(0.0, time * 0.05));
color += amberWarm * wash * 0.05;
```

### Layer 2 — Suspended motes
Gold dust / inclusions drifting slowly upward, hash-cell based (same technique as night-temple's starfield, but the sample point drifts in y so motes rise). Sparse (threshold ~0.99), soft twinkle.

```glsl
float moteDensity = 90.0;
vec2 moteUV = uv + vec2(0.0, time * 0.02);      // drift upward
vec2 moteCell = floor(moteUV * moteDensity);
float moteHash = hash21(moteCell);
if (moteHash > 0.99) {
    float tw = 0.5 + 0.5 * sin(time * (0.8 + moteHash) + moteHash * 6.28);
    color += vec3(0.95, 0.70, 0.30) * tw * 0.35;
}
```

### Layer 3 — DNA double helix (HERO)
Centered vertical helix. Two gold strands are opposite-phase sines in x as a function of uv.y; the phase advances with time (winding) and the sample scrolls in y (drift). Front/back depth is faked from the phase cosine so each strand brightens as it comes "forward" and dims as it goes "behind." Glowing nucleotide nodes sit along the strands; base-pair rungs connect the two strands at intervals.

Reference math (strand centers and distances are all in uv.x space; the helix is intentionally stylized, not circular, so no aspect correction is needed):

```glsl
float cx = 0.5;
float R  = 0.13;                                  // horizontal radius (uv.x units)
float twist = 6.0 * 2.0 * PI;                     // vertical winds
float phaseY = (uv.y + time * 0.05) * twist + time * 0.6;

// strand centers (in uv.x)
float xA = cx + R * sin(phaseY);
float xB = cx + R * sin(phaseY + PI);

// depth brightness from phase cosine (front bright / back dim)
float depthA = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY));
float depthB = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI));

// strand glow: distance from this pixel's x to each strand center
float w = 0.010;                                  // strand half-width in uv.x
float glowA = smoothstep(w, 0.0, abs(uv.x - xA)) * depthA;
float glowB = smoothstep(w, 0.0, abs(uv.x - xB)) * depthB;

// nucleotide nodes: periodic bright beads along each strand
float beads = 0.5 + 0.5 * sin(phaseY * 3.0);
float node  = pow(beads, 6.0);

vec3 goldStrand = vec3(0.95, 0.68, 0.22);
color += goldStrand * (glowA + glowB) * (0.06 + 0.10 * node);

// base-pair rungs: horizontal band between xA and xB at intervals
float rungGate = pow(0.5 + 0.5 * sin(phaseY * 3.0 + PI * 0.5), 8.0);
float betweenX = smoothstep(0.0, 0.01, (uv.x - min(xA,xB))) *
                 smoothstep(0.0, 0.01, (max(xA,xB) - uv.x));
color += goldStrand * rungGate * betweenX * 0.04;
```

Intensities are held low (~0.06–0.16 peak) so the helix reads as backlit glow behind text, not a solid overlay. Exact widths/frequencies to be tuned during implementation for readability.

### Layer 4 — Alien splice strand + pulse
A third **cyan** strand woven at an offset phase, smaller radius, dimmer and pulsing (the "more aliens" element). Plus a periodic **blue-white pulse** that travels up the helix in y and flares the strands (especially the cyan one) as it passes — the DNA-expansion event.

```glsl
// alien strand
float xC = cx + (R * 0.7) * sin(phaseY + PI * 0.66);
float depthC = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI * 0.66));
float glowC = smoothstep(0.008, 0.0, abs(uv.x - xC)) * depthC;
float alienPulse = 0.6 + 0.4 * sin(time * 2.0);
vec3 alienCyan = vec3(0.25, 0.85, 0.90);
color += alienCyan * glowC * 0.07 * alienPulse;

// traveling splice pulse (blue-white flare running up the helix)
float pulseY = fract(time * 0.18);
float pulse  = exp(-pow((uv.y - pulseY) * 6.0, 2.0));
vec3 spliceWhite = vec3(0.7, 0.9, 1.0);
color += spliceWhite * pulse * (glowA + glowB + glowC * 1.5) * 0.5;
```

### Layer 5 — Amber vignette
Warm recessed vignette that focuses the center and darkens edges. Reuse its distance for the gamma periphery weight.

```glsl
vec2 vc = vec2(0.5, 0.5);
float vDist = length(uv - vc);
float vig = smoothstep(0.85, 0.20, vDist);
vig = mix(0.15, 1.0, vig);
color *= vig;
```

### Signature — 40 Hz gamma entrainment + text protection
Identical to every other theme:

```glsl
float g = sin(2.0 * PI * GAMMA_HZ * time);
float periphery = smoothstep(0.15, 0.5, vDist);
color *= 1.0 + GAMMA_AMP * g * periphery;

color = clamp(color, 0.0, 1.0);
color = mix(color, clean.rgb, textMask);
fragColor = vec4(color, clean.a);
```

## 3. Lite shader (`shaders/amber-splice-lite.glsl`)

Keeps the signature helix (gold double strand + cyan alien strand + nodes) and the amber vignette. **Drops:** amber wash, motes, base-pair rungs, and the traveling splice pulse. Keeps 40 Hz gamma + text protection. Header comment states what's dropped and the noise-call count (helix is noise-free, so 0 noise calls in lite). Shares the same `hash21`/`noise` utilities for consistency even if unused.

## 4. Static shader (`shaders/amber-splice-static.glsl`)

**No `iTime` dependency** (used with `custom-shader-animation = false`). Renders:
- Amber vignette (same as full)
- A faint **frozen** helix — the same strand math with `phaseY = uv.y * twist` (no time terms), low intensity, so the tier still reads as amber-splice
- Text protection

No gamma layer (it requires time). Near-zero cost, purely per-pixel math.

## 5. Prompt (`prompts/amber-splice.sh`)

Frontier genetics field-lab console. Zsh `precmd` hook with an idempotency guard, random-walk session state, two-line prompt, ANSI colors matching the theme (amber-gold dim `\e[33m` / bright `\e[93m`, cyan accent `\e[36m` on the splice readout). Same structure as `prompts/night-temple.sh`.

Rendered:
```
┌─⌬─[AMBER FIELD LAB]─[SITE·B]─[SEQ 63%]─[VIABILITY:88%]─[SPLICE:α-9]─⌬─
└─⌖ user@lab:~ $
```

Readouts:
- **SEQ%** — sequencing progress. Random-walk, drift +0..+3 per command, wraps 0→99 (climbs, resets — a run "completing" and restarting).
- **VIABILITY%** — specimen viability. Random-walk ±2, clamp 40–99.
- **SPLICE** — current alien strain code, cycles every 8 commands through `α-9 → β-2 → Δ-7 → Ω-1` (same cycling technique as night-temple's ward glyphs).

Glyphs use safe geometric Unicode (`⌬` ring, `⌖` marker) — no emoji, to keep column width stable. Prompt name/host: `%n@lab:%~`.

## 6. README updates

- **Themes table:** add
  `| **amber-splice** | DNA helix suspended in amber, spliced with alien DNA. Drifting gold double helix, cyan alien strand, traveling splice pulse. |`
- **Prompts table:** add
  `| **amber-splice** | Genetics field-lab console | SEQ%, VIABILITY%, SPLICE strain |`
- **File Structure:** add the five `amber-splice*` files under `themes/`, `shaders/`, `prompts/` with brief inline comments matching the existing style.

## Success criteria

1. All three shaders compile in Ghostty (no GLSL errors) and render without artifacts over text; text stays readable (text protection working).
2. `ghostty-random.sh amber-splice` (and `--lite`, `--static`) selects the theme, points `config` at the correct shader, and sets `custom-shader-animation` appropriately (false for static).
3. `ghostty-random.sh list` shows `amber-splice`.
4. `source prompts/amber-splice.sh` renders the two-line prompt with live readouts that update per command; sourcing twice is a no-op (idempotency guard).
5. Palette loads (valid Ghostty theme file).
6. README reflects the new theme in all three sections.

## Out of scope

- No changes to the launcher logic (auto-discovery already covers it).
- No new power-tier flags or env behavior.
- No CRT/scanline treatment (this theme is amber/organic, not a CRT theme).
