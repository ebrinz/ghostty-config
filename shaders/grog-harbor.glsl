// grog-harbor.glsl
// Theme: Melee Island Dock at Midnight — LucasArts SCUMM Era, 1992
// The harbor at night: salt air, creaking wood, the Scumm Bar lantern glow.
// VGA 256-color Bayer ordered dither on a 1992 CRT phosphor display.
// Foundation layers: Bayer 4x4 dither, scanlines, vignette, 40Hz gamma
// entrainment, and text protection. Extended layers added in later tasks.
// Scene: pixel-art waves roll along the bottom of the screen, palm fronds
// sway in from the top corners. Oriented to the screen (y down on Metal):
// water low, torch glow and fronds high.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — Guybrush's lantern. A warm dithered glow on the cursor; on jumps
//            of 2+ cells it walks to the new spot in SCUMM-style 12 fps
//            steps, leaving sprite afterimages that fade.
//   focus  — unfocused, the dock falls asleep: the palette drops to 4 levels
//            per channel, the torch stops flickering, the scene dims.
//            Regaining focus flares the lantern and torch for a moment.

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
// Bayer 4x4 ordered dither — VGA palette quantization
// ---------------------------------------------------------------------------

const float bayer4x4[16] = float[16](
     0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
    12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
     3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
    15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

// Ordered-dither palette quantization — 6 quantization levels per channel.
// DIVISOR is (levels - 1), so floor(c * DIVISOR + 0.5) / DIVISOR snaps to
// 6 evenly spaced values: {0, 1/5, 2/5, 3/5, 4/5, 1}.
vec3 ditherQuantize(vec3 color, vec2 fragCoord, float divisor) {
    ivec2 bc = ivec2(mod(fragCoord, 4.0));
    float threshold = bayer4x4[bc.y * 4 + bc.x];
    vec3 biased = color + (threshold - 0.5) / divisor;
    return floor(biased * divisor + 0.5) / divisor;
}

// ---------------------------------------------------------------------------
// Interaction helpers
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
// ---------------------------------------------------------------------------

vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// SCUMM walk: the lantern steps prev -> cur at 12 fps, with three fading
// afterimages behind it. Returns glow intensity at pixel p.
float lanternWalk(vec2 p, vec2 a, vec2 b, float age, float cell) {
    const float DUR = 0.5;
    const float FPS = 12.0;
    float glow = 0.0;
    for (int i = 0; i < 4; i++) {
        float lag = float(i) * (1.0 / FPS);
        float k = clamp((age - lag) / DUR, 0.0, 1.0);
        k = floor(k * DUR * FPS) / (DUR * FPS);          // quantize to frames
        vec2 pos = mix(a, b, k);
        float d = length(p - pos) / cell;
        float fade = (1.0 - float(i) * 0.3) * (1.0 - clamp(age / (DUR + 0.3), 0.0, 1.0));
        glow += exp(-d * 2.2) * fade;
    }
    return glow;
}

// ---------------------------------------------------------------------------
// Layer 1: Moonlit water ripples — bottom 35% of screen
// Returns (vertical displacement, cyan highlight strength) packed as vec2.
// ---------------------------------------------------------------------------

vec2 moonRipple(vec2 uv, float t) {
    float zone = smoothstep(0.0, 0.10, uv.y - 0.65); // 0 above 0.65, 1 toward the bottom (y down)
    if (zone <= 0.0) return vec2(0.0);

    // Slow horizontal sine bands, phase drifts with time
    float band1 = sin(uv.y * 80.0 + t * 0.6) * 0.5;
    float band2 = sin(uv.y * 140.0 - t * 0.4 + uv.x * 3.0) * 0.3;
    float disp = (band1 + band2) * zone * 0.003; // vertical uv displacement

    // Moonlight highlight streaks — brighter bands where the moon reflects
    float streak = sin(uv.y * 30.0 - t * 0.3) * 0.5 + 0.5;
    streak = pow(streak, 4.0);
    float highlight = streak * zone * 0.25;

    return vec2(disp, highlight);
}

// ---------------------------------------------------------------------------
// Pixel-art sea: three stepped wave bands drawn in 4-px blocks along the
// bottom of the screen (y is down on Metal, so bottom = large y). Returns
// (water body, crest) for the block this pixel falls in.
// ---------------------------------------------------------------------------

const float PX = 4.0; // block size in pixels

vec2 pixelWaves(vec2 fragCoord, vec2 res, float t) {
    vec2 b = floor(fragCoord / PX);
    vec2 nb = res / PX;
    float body = 0.0, crest = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float base  = nb.y * (0.80 + 0.07 * fi);           // wave midline (block row)
        float amp   = 1.5 + fi;                            // blocks
        float freq  = (0.045 - 0.008 * fi) * 6.2832;
        float speed = (0.9 - 0.2 * fi) * ((i == 1) ? -1.0 : 1.0);
        float y = base + floor(amp * sin(b.x * freq + t * speed)
                             + amp * 0.5 * sin(b.x * freq * 2.3 - t * speed * 0.7));
        body  = max(body, step(y, b.y) * (0.5 + 0.25 * fi));
        crest = max(crest, step(abs(b.y - y), 0.5));
        // foam dashes one block below the crest
        crest += step(abs(b.y - (y + 1.0)), 0.5) * 0.4 * step(0.5, fract(b.x * 0.5 + fi * 0.33));
    }
    return vec2(body, min(crest, 1.0));
}

// ---------------------------------------------------------------------------
// Palm fronds: tapered, serrated leaf silhouettes fanning in from the top
// corners and swaying slowly. Block-space math so they stay pixel-art.
// ---------------------------------------------------------------------------

float frond(vec2 b, vec2 anchor, float ang, float len, float droop) {
    vec2 d = vec2(cos(ang), sin(ang));
    vec2 n = vec2(-d.y, d.x);
    vec2 r = b - anchor;
    float s = dot(r, d);
    float off = dot(r, n) - droop * s * s / len;         // curved centreline
    float inside = step(0.0, s) * step(s, len);
    float w = (1.0 - s / len) * 4.0 + 0.5;               // tapering half-width
    float leaflets = 0.55 + 0.45 * step(0.45, fract(s * 0.35));
    return inside * step(abs(off), w * leaflets);
}

float palmTops(vec2 fragCoord, vec2 res, float t) {
    vec2 b = floor(fragCoord / PX);
    vec2 nb = res / PX;
    float m = 0.0;
    vec2 aL = vec2(-6.0, -4.0);                          // just off the top-left
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float sway = sin(t * 0.5 + fi * 1.3) * 0.04;
        m = max(m, frond(b, aL, 0.15 + fi * 0.22 + sway, nb.x * 0.28 - fi * 4.0, 0.9 + fi * 0.2));
    }
    vec2 aR = vec2(nb.x + 6.0, -2.0);                    // just off the top-right
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float sway = sin(t * 0.45 + fi * 1.7 + 2.0) * 0.04;
        m = max(m, frond(b, aR, 3.14159 - (0.2 + fi * 0.25 + sway), nb.x * 0.24 - fi * 4.0, -(0.9 + fi * 0.2)));
    }
    return m;
}

// ---------------------------------------------------------------------------
// Layer 4a: Chromatic aberration — red drifts outward from screen center
// ---------------------------------------------------------------------------

vec3 sampleAberrated(vec2 uv) {
    vec2 dir = normalize(uv - 0.5 + vec2(1e-6));
    float amt = 0.0015;
    float r = texture(iChannel0, uv + dir * amt).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - dir * amt * 0.5).b;
    return vec3(r, g, b);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Sample terminal content
    vec4 clean      = texture(iChannel0, uv);
    vec3 cleanText  = clean.rgb;

    // Text detection — luma mask protects text from CRT effects
    float luma = dot(cleanText, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // --- Interaction state ---
    float focused   = float(iFocus > 0);
    float focusAge  = iTime - iTimeFocus;
    vec2  curC      = cursorCenter(iCurrentCursor);
    vec2  prevC     = cursorCenter(iPreviousCursor);
    float cell      = max(max(iCurrentCursor.z, iCurrentCursor.w), 4.0);
    float moveAge   = iTime - iTimeCursorChange;
    // move measured in columns/rows (a bar cursor's z is only the bar width
    // and an underline's w only its thickness, so each axis has a fallback)
    vec2  cellWH    = vec2(iCurrentCursor.z > 4.0 ? iCurrentCursor.z : max(iCurrentCursor.w * 0.5, 2.0),
                           max(max(iCurrentCursor.w, iCurrentCursor.z * 2.0), 4.0));
    float moveCells = length((curC - prevC) / cellWH);
    float jumpGate  = step(0.5, iPreviousCursor.w) * smoothstep(1.2, 3.0, moveCells);
    float cursorD   = length(fragCoord - curC) / cell;
    float asleep    = 1.0 - focused;
    float flare     = smoothstep(0.8, 0.05, focusAge) * focused;

    vec3 color = sampleAberrated(uv);

    // --- Layer 1: Moonlit water ripples ---
    vec2 ripple = moonRipple(uv, iTime);
    if (ripple.y > 0.0 || ripple.x != 0.0) {
        // Resample the terminal color with vertical displacement
        vec2 sampleUV = uv + vec2(0.0, ripple.x);
        color = sampleAberrated(sampleUV);
        // Add moonlit cyan highlight on the water
        color += vec3(0.15, 0.35, 0.55) * ripple.y;
    }

    // --- Layer 1b: Pixel-art sea along the bottom ---
    vec2 sea = pixelWaves(fragCoord, iResolution.xy, iTime);
    vec3 seaDeep  = vec3(0.06, 0.14, 0.32);
    vec3 seaCrest = vec3(0.35, 0.75, 0.80);
    color += seaDeep * sea.x * 0.18;
    color += seaCrest * sea.y * 0.35;

    // --- Layer 1c: Palm tops swaying in from the top corners ---
    float palms = palmTops(fragCoord, iResolution.xy, iTime);
    vec3 frondColor = vec3(0.02, 0.06, 0.04);
    color = mix(color, frondColor, palms * 0.8);

    // --- Layer 4b: Phosphor bloom — soft warm glow around bright pixels ---
    vec3 bloom = vec3(0.0);
    float bloomRadius = 0.003;
    bloom += texture(iChannel0, uv + vec2( bloomRadius, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2(-bloomRadius, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2(0.0,  bloomRadius)).rgb;
    bloom += texture(iChannel0, uv + vec2(0.0, -bloomRadius)).rgb;
    bloom *= 0.25;
    float bloomLuma = dot(bloom, vec3(0.2126, 0.7152, 0.0722));
    color += bloom * smoothstep(0.3, 0.8, bloomLuma) * 0.15;

    // --- Layer 2: The lantern — warm glow on the cursor, SCUMM walk on jumps ---
    vec3 lanternColor = vec3(0.91, 0.60, 0.22); // #e89838 cursor orange
    float lanternFlicker = 0.85 + 0.15 * noise(vec2(iTime * 4.0, 5.0));
    float lantern = exp(-cursorD * 1.6) * lanternFlicker * (1.0 + flare * 1.5);
    color += lanternColor * lantern * 0.22 * mix(0.4, 1.0, focused);
    float walk = lanternWalk(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += lanternColor * walk * 0.3;

    // --- Bayer Dither: VGA 256-color ordered quantization (coarser asleep) ---
    // Gated off the plain background: dithering the near-black navy turned it
    // into a gray speckle that washed the whole screen out.
    vec3 dithered = ditherQuantize(color, fragCoord, mix(5.0, 3.0, asleep));
    float tone = smoothstep(0.08, 0.16, dot(color, vec3(0.2126, 0.7152, 0.0722)));
    color = mix(color, dithered, tone);

    // --- Scanlines: 12% darkening on alternating rows ---
    color *= 1.0 - 0.12 * mod(floor(fragCoord.y), 2.0);

    // --- Layer 5: Torch flicker — warm pulse weighted to top of screen ---
    float torchNoise1 = noise(vec2(iTime * 0.7, 0.0));
    float torchNoise2 = noise(vec2(iTime * 1.3, 17.0));
    float torch = (torchNoise1 * 0.7 + torchNoise2 * 0.3);
    torch = mix(torch, 0.35, asleep) + flare * 0.6;  // steady and low asleep, flares on focus
    float topWeight = smoothstep(0.4, 0.0, uv.y); // strongest near the top (y down)
    float flickerAmp = 0.035 * topWeight;
    vec3 torchTint = vec3(1.08, 1.02, 0.92); // warm orange tint
    color *= mix(vec3(1.0), torchTint, torch * topWeight);
    color *= 1.0 + (torch - 0.5) * flickerAmp;

    // --- Vignette: midnight harbor darkness at screen edges ---
    vec2 centered = uv - 0.5;
    float dist = length(centered);
    float v = smoothstep(0.85, 0.35, dist);
    v = mix(0.60, 1.0, v);
    color *= v;

    // --- Focus: the dock sleeps when the window is in the background ---
    color *= mix(1.0, 0.6, asleep);

    // --- 40Hz Gamma Entrainment: periphery flicker ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * iTime);
    float peripheryWeight = smoothstep(0.15, 0.5, dist);
    color *= 1.0 + GAMMA_AMP * gamma * peripheryWeight;

    // --- Text Protection: restore clean text after CRT effects ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, min(cleanText * 1.10, 1.0), textMask);   // glyphs lifted 10%

    fragColor = vec4(color, clean.a);
}
