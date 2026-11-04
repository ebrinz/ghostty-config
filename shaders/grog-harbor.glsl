// grog-harbor.glsl
// Theme: Melee Island Dock at Midnight — LucasArts SCUMM Era, 1992
// The harbor at night: salt air, creaking wood, the Scumm Bar lantern glow.
// VGA 256-color Bayer ordered dither on a 1992 CRT phosphor display.
// Foundation layers: Bayer 4x4 dither, scanlines, vignette, 40Hz gamma
// entrainment, and text protection. Extended layers added in later tasks.
// Scene: a complete original pixel-art dock at midnight. Starry sky with a
// dithered moon and drifting clouds, the town's windows up a headland, a
// ship bobbing at anchor, pixel waves with a moonlight column, the Scumm
// Bar with candle-lit windows and a smoking chimney, a plank pier with a
// swaying lantern, palm fronds and a trunk. Oriented to the screen (y down
// on Metal): water low, sky high.
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
    float zone = smoothstep(0.0, 0.08, uv.y - 0.58) * smoothstep(0.0, 0.04, 0.86 - uv.y); // the sea band (y down)
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
        float base  = nb.y * (0.66 + 0.07 * fi);           // wave midline (block row), in the sea band
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

float frond(vec2 b, vec2 anchor, float ang, float len, float droop, float wBase) {
    vec2 d = vec2(cos(ang), sin(ang));
    vec2 n = vec2(-d.y, d.x);
    vec2 r = b - anchor;
    float s = dot(r, d);
    float off = dot(r, n) - droop * s * s / len;         // curved centreline
    float inside = step(0.0, s) * step(s, len);
    float w = (1.0 - s / len) * wBase + 0.5;             // tapering half-width
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
        m = max(m, frond(b, aL, 0.15 + fi * 0.22 + sway, nb.x * 0.28 - fi * 4.0, 0.9 + fi * 0.2, 4.0));
    }
    vec2 aR = vec2(nb.x + 6.0, -2.0);                    // just off the top-right
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float sway = sin(t * 0.45 + fi * 1.7 + 2.0) * 0.04;
        m = max(m, frond(b, aR, 3.14159 - (0.2 + fi * 0.25 + sway), nb.x * 0.24 - fi * 4.0, -(0.9 + fi * 0.2), 4.0));
    }
    return m;
}

// A whole palm: curved trunk from (baseX, baseRow) up `height` blocks leaning
// `lean` blocks, a crown of six swaying fronds, two coconuts. Returns
// (trunk, fronds, coconut) masks.
vec3 palmTree(vec2 b, float baseX, float baseRow, float height, float lean, float t, float seed) {
    float up = clamp((baseRow - b.y) / height, 0.0, 1.0);
    float trunkX = floor(baseX + lean * up * up);
    float trunk = step(abs(b.x - trunkX), 1.0) * step(b.y, baseRow) * step(baseRow - height, b.y);
    vec2 crown = vec2(baseX + lean, baseRow - height);
    float fr = 0.0;
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        float sway = sin(t * 0.6 + seed + fk * 0.9) * 0.05;
        float ang = -2.9 + fk * 0.62 + sway;              // fan from upper-left round to right
        float droop = 0.9 * sign(cos(ang) + 0.001);
        fr = max(fr, frond(b, crown, ang, height * 0.55, droop, 2.2));
    }
    float nut = step(length(b - (crown + vec2(-1.0, 2.0))), 1.1) + step(length(b - (crown + vec2(2.0, 2.0))), 1.1);
    return vec3(trunk, fr, min(nut, 1.0));
}

// ---------------------------------------------------------------------------
// The dock scene — original pixel art drawn in 4-px blocks, y down on Metal.
// Layout is in screen fractions so it scales with the window; details are in
// whole blocks so they stay crisp. Returns rgb + coverage to composite over
// the terminal background. `lit` is 1 when the window is focused.
// ---------------------------------------------------------------------------

const float HORIZON = 0.56;   // sea meets sky
const float PIER_Y  = 0.86;   // pier edge

vec4 dockScene(vec2 fragCoord, vec2 res, float t, float lit) {
    vec2 b  = floor(fragCoord / PX);
    vec2 nb = floor(res / PX);
    vec2 u  = (b + 0.5) / nb;
    float ax = nb.x / nb.y;                         // aspect, for round things
    vec3 warm = vec3(1.0, 0.72, 0.30);
    vec3 col;

    // --- Sky: deep navy to indigo, darkest up top where the text lives ---
    float skyT = clamp(u.y / HORIZON, 0.0, 1.0);
    col = mix(vec3(0.02, 0.03, 0.10), vec3(0.08, 0.10, 0.28), skyT * skyT);

    // stars: one block, blinking on their own clocks
    float sh = hash21(b);
    if (u.y < HORIZON - 0.03 && sh > 0.994) {
        float blink = step(0.35, fract(sh * 37.0 + t * (0.15 + sh * 0.3)));
        col += vec3(0.85, 0.90, 1.0) * blink * 0.8;
    }

    // moon: dithered disc with crater blocks, soft halo
    vec2 moonC = vec2(0.80, 0.16);
    vec2 dm = (u - moonC) * vec2(ax, 1.0);
    float md = length(dm);
    const float MR = 0.045;
    col += vec3(0.25, 0.25, 0.35) * smoothstep(MR * 2.2, MR, md) * 0.35 * mix(0.5, 1.0, lit);
    if (md < MR) {
        float crater = step(0.93, hash21(floor(b / 2.0) + 7.0));
        col = mix(vec3(0.92, 0.90, 0.78), vec3(0.70, 0.68, 0.56), crater) * mix(0.55, 1.0, lit);
    }

    // clouds: three slow strips with ragged ends, wrapping across the sky
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float cyRow = floor((0.09 + fi * 0.08) * nb.y);
        float cx = fract(hash21(vec2(fi, 3.0)) + t * 0.004 * (1.0 + fi * 0.5));
        float len = 0.14 + 0.05 * fi;
        float dx = fract(u.x - cx + 0.5) - 0.5;
        float rows = (abs(dx) < len * 0.3) ? 1.0 : 0.0;      // thicker in the middle
        float inStrip = step(abs(dx), len * 0.5) * step(cyRow - rows, b.y) * step(b.y, cyRow + rows);
        inStrip *= step(0.25, hash21(vec2(b.x, fi)) + step(abs(dx), len * 0.35)); // ragged ends
        col = mix(col, vec3(0.12, 0.14, 0.30), inStrip * 0.85);
    }

    // --- Headland on the left, the town's windows up the hill ---
    float hx = clamp(u.x / 0.42, 0.0, 1.0);
    float ridge = HORIZON - 0.20 * pow(1.0 - hx, 1.3) - 0.015 * hash21(vec2(floor(b.x / 3.0), 9.0));
    if (u.x < 0.42 && u.y > ridge && u.y < HORIZON) {
        col = vec3(0.03, 0.06, 0.08);
        float wh = hash21(floor(b / 2.0) + 21.0);
        if (wh > 0.975 && u.y > ridge + 0.02) {
            float on = step(0.12, fract(wh * 53.0 + t * 0.07)) * lit;
            col = mix(col, warm, on);
        }
    }

    // --- Lookout tower on the headland, with a slow beacon ---
    float towerCol = floor(0.12 * nb.x);
    float towerTop = floor(0.30 * nb.y);
    float towerBase = floor((HORIZON - 0.20 * pow(1.0 - 0.12 / 0.42, 1.3)) * nb.y) + 1.0;
    float beacon = step(0.5, fract(t * 0.5)) * lit;
    if (b.y >= towerTop && b.y <= towerBase) {
        float halfW = (b.y <= towerTop + 1.0) ? 2.0 : 1.0;                     // wider lantern room
        if (abs(b.x - towerCol) <= halfW) {
            col = vec3(0.04, 0.05, 0.07);
            if (b.y == towerTop + 1.0 && abs(b.x - towerCol) <= 1.0) col = mix(vec3(0.08, 0.06, 0.04), warm, beacon);
            if (b.x == towerCol && (b.y == towerTop + 6.0 || b.y == towerTop + 11.0)) col = warm * 0.6 * lit; // windows
        }
    }
    col += warm * beacon * smoothstep(7.0, 2.0, length(b - vec2(towerCol, towerTop + 1.0))) * 0.35;

    // --- Ship at anchor, bobbing a block: hull, two masts, yards, furled sails ---
    float bobBlocks = floor(sin(t * 0.8) + 0.5);
    vec2 bs = b + vec2(0.0, bobBlocks);
    vec2 us = (bs + 0.5) / nb;
    const float SX0 = 0.25, SX1 = 0.35;
    float hullTop = HORIZON - 0.03;
    vec3 shipDark = vec3(0.02, 0.03, 0.05);
    float hull = step(SX0, us.x) * step(us.x, SX1) * step(hullTop, us.y) * step(us.y, HORIZON + 0.005);
    hull *= step(abs(us.x - (SX0 + SX1) * 0.5), (SX1 - SX0) * 0.5 - (us.y - hullTop) * 0.6); // tapered ends
    if (hull > 0.5) {
        col = shipDark;
        if (bs.y == floor(hullTop * nb.y) + 1.0) col = vec3(0.10, 0.08, 0.06);  // gunwale stripe
        float portRow = floor((hullTop + 0.014) * nb.y);
        if (bs.y == portRow && (bs.x == floor((SX0 + 0.03) * nb.x) || bs.x == floor((SX0 + 0.06) * nb.x)))
            col = warm * 0.8 * lit;                                              // portholes
    }
    // bowsprit off the bow (right), one diagonal run of blocks
    float bowRow = floor(hullTop * nb.y);
    float bowX = floor(SX1 * nb.x);
    for (int k = 1; k <= 4; k++) {
        if (bs.x == bowX + float(k) && bs.y == bowRow - float(k / 2)) col = shipDark;
    }
    // masts: main (taller) and fore
    float mainCol = floor(((SX0 + SX1) * 0.5 - 0.012) * nb.x);
    float foreCol = floor((SX1 - 0.025) * nb.x);
    float mainTop = floor((hullTop - 0.13) * nb.y);
    float foreTop = floor((hullTop - 0.085) * nb.y);
    if (bs.x == mainCol && bs.y >= mainTop && bs.y <= bowRow) col = shipDark;
    if (bs.x == foreCol && bs.y >= foreTop && bs.y <= bowRow) col = shipDark;
    // yards with a furled sail bundle hung beneath each
    for (int k = 0; k < 3; k++) {
        float mcol = (k < 2) ? mainCol : foreCol;
        float yrow = (k == 0) ? mainTop + 3.0 : (k == 1) ? mainTop + 9.0 : foreTop + 3.0;
        float yhalf = (k == 0) ? 4.0 : (k == 1) ? 6.0 : 4.0;
        if (bs.y == yrow && abs(bs.x - mcol) <= yhalf) col = shipDark;
        if (bs.y == yrow + 1.0 && abs(bs.x - mcol) <= yhalf - 1.0) col = vec3(0.22, 0.20, 0.17);
    }
    // flag at the main top, flapping between two shapes
    float flap = step(0.5, fract(t * 1.2));
    if (bs.y == mainTop - 1.0 && bs.x > mainCol && bs.x <= mainCol + 2.0 + flap) col = vec3(0.55, 0.12, 0.10);
    if (bs.y == mainTop && bs.x > mainCol && bs.x <= mainCol + 1.0 + flap) col = vec3(0.55, 0.12, 0.10);
    if (bs.x == floor((SX0 + 0.004) * nb.x) && bs.y == floor((hullTop - 0.012) * nb.y))
        col = warm * lit;                                                        // stern lantern

    // --- Sea: base, moonlight column, pixel waves ---
    if (u.y >= HORIZON && u.y < PIER_Y) {
        float depth = (u.y - HORIZON) / (PIER_Y - HORIZON);
        col = mix(vec3(0.05, 0.10, 0.26), vec3(0.04, 0.08, 0.20), depth);
        float halfW = 0.02 + 0.03 * depth;
        if (abs(u.x - moonC.x) < halfW) {
            float shimmer = step(0.45, hash21(vec2(b.y, floor(t * 4.0) + floor(b.x * 0.5))));
            col += vec3(0.55, 0.55, 0.45) * shimmer * (1.0 - depth * 0.7) * 0.5 * mix(0.4, 1.0, lit);
        }
        vec2 sea = pixelWaves(fragCoord, res, t);
        col += vec3(0.06, 0.14, 0.32) * sea.x * 0.9;
        col += vec3(0.35, 0.75, 0.80) * sea.y * 0.8;
    }

    // --- The Scumm Bar on the right shore ---
    const float BX0 = 0.70, BX1 = 0.97, BY0 = 0.50, ROOF = 0.42;
    float rc = (BX0 + BX1) * 0.5;
    if (u.y > ROOF && u.y < BY0) {                                           // gable roof
        float hw = (BX1 - BX0) * 0.5 * (u.y - ROOF) / (BY0 - ROOF) + 0.01;
        if (abs(u.x - rc) < hw) col = vec3(0.08, 0.05, 0.04);
    }
    if (u.x > BX0 && u.x < BX1 && u.y >= BY0 && u.y < PIER_Y) {               // walls
        col = vec3(0.05, 0.05, 0.07);
        for (int w = 0; w < 4; w++) {                                        // candle-lit windows
            float fw = float(w);
            vec2 wc = floor(vec2(BX0 + 0.045 + fw * 0.065, 0.64) * nb);
            if (abs(b.x - wc.x) <= 1.0 && abs(b.y - wc.y) <= 1.0) {
                float candle = 0.7 + 0.3 * noise(vec2(t * 3.0 + fw * 7.0, fw));
                float on = step(0.08, fract(fw * 0.37 + t * 0.03)) * lit;    // one blinks out now and then
                col = mix(col, warm * candle, on);
            }
        }
        vec2 dc = floor(vec2(0.835, PIER_Y - 0.035) * nb);                   // doorway
        if (abs(b.x - dc.x) <= 1.0 && b.y >= dc.y - 3.0 && b.y <= dc.y + 3.0)
            col = mix(vec3(0.03, 0.02, 0.02), warm * 0.45, lit * step(abs(b.x - dc.x), 0.5));
    }
    if (u.x > 0.90 && u.x < 0.915 && u.y > 0.40 && u.y < BY0) col = vec3(0.07, 0.05, 0.04); // chimney
    if (u.y < 0.40 && u.y > 0.22) {                                           // smoke, drifting left
        float rise = 0.40 - u.y;
        float dxs = u.x - 0.905 + rise * 0.5;
        if (abs(dxs) < 0.01 + rise * 0.3) {
            float puff = step(0.55, hash21(floor(b / 2.0) + floor(t * 0.7)));
            col = mix(col, vec3(0.16, 0.17, 0.22), puff * (1.0 - rise / 0.18) * 0.7);
        }
    }

    // --- Pier: planks receding, two posts, a swaying lantern ---
    if (u.y >= PIER_Y) {
        float s = (u.y - PIER_Y) / (1.0 - PIER_Y);
        float pk = pow(s, 0.7) * 9.0;
        vec3 wood = mix(vec3(0.16, 0.10, 0.05), vec3(0.13, 0.08, 0.04), mod(floor(pk), 2.0));
        col = mix(wood, vec3(0.05, 0.03, 0.02), step(fract(pk), 0.14));         // plank gaps
        float boardW = 0.05 + 0.05 * s;
        col = mix(col, vec3(0.05, 0.03, 0.02), step(fract((u.x - 0.5) / boardW), 1.0 / (boardW * nb.x)) * 0.8);
    }
    float postL = floor(0.06 * nb.x), postR = floor(0.93 * nb.x);
    float postTop = floor((PIER_Y - 0.09) * nb.y), postBot = floor((PIER_Y + 0.03) * nb.y);
    if ((abs(b.x - postL) <= 1.0 || abs(b.x - postR) <= 1.0) && b.y >= postTop && b.y <= postBot)
        col = (b.y == postTop) ? vec3(0.05, 0.03, 0.02) : vec3(0.09, 0.06, 0.03);
    // bracket + lantern hanging off the right post
    float brRow = postTop + 1.0;
    if (b.y == brRow && b.x >= postR - 5.0 && b.x <= postR - 2.0) col = vec3(0.09, 0.06, 0.03);
    float sway = floor(sin(t * 0.9) * 1.2 + 0.5);
    vec2 lan = vec2(postR - 5.0 + sway, brRow + 3.0);                          // lantern centre (blocks)
    if (abs(b.x - lan.x) <= 1.0 && abs(b.y - lan.y) <= 1.5) {
        float inner = step(abs(b.x - lan.x), 0.5) * step(abs(b.y - lan.y), 1.0);
        col = mix(vec3(0.10, 0.07, 0.04), warm * mix(0.3, 1.0, lit), inner);
    }
    if (b.y == brRow + 1.0 && b.x == lan.x) col = vec3(0.10, 0.07, 0.04);     // hook
    // its light pool, dithered, on everything near it
    float ld = length((b - lan) * vec2(1.0, 1.6));
    float pool = smoothstep(16.0, 2.0, ld) * step(0.35, hash21(b + 3.0)) * mix(0.2, 1.0, lit);
    col += warm * pool * 0.30;

    // --- Two palm trees: one on the pier at left, one on the shore by the bar ---
    vec3 frondCol = vec3(0.03, 0.09, 0.05);
    vec3 trunkCol = vec3(0.08, 0.055, 0.03);
    vec3 palmA = palmTree(b, floor(0.14 * nb.x), floor((PIER_Y + 0.02) * nb.y), 0.26 * nb.y, -5.0, t, 0.0);
    vec3 palmB = palmTree(b, floor(0.60 * nb.x), floor(PIER_Y * nb.y), 0.34 * nb.y, 6.0, t, 2.0);
    float trunks = max(palmA.x, palmB.x), fronds = max(palmA.y, palmB.y), nuts = max(palmA.z, palmB.z);
    if (trunks > 0.5) col = (mod(b.y, 3.0) == 0.0) ? trunkCol * 0.7 : trunkCol;
    if (fronds > 0.5) col = frondCol;
    if (nuts > 0.5) col = vec3(0.10, 0.07, 0.03);

    // --- Palm trunk up the right edge, leading to the corner fronds ---
    float trunkX = floor(nb.x - 2.5 - 4.0 * pow(1.0 - u.y, 2.0));
    if (u.y < PIER_Y + 0.01 && abs(b.x - trunkX) <= 1.0)
        col = (mod(b.y, 3.0) == 0.0) ? vec3(0.05, 0.035, 0.02) : vec3(0.08, 0.055, 0.03);

    return vec4(col, 1.0);
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

    // --- Layer 1b: The dock scene, composited over the terminal background ---
    // SCENE_STRENGTH dials the whole picture; glyph pixels are excluded here
    // and restored again at the end.
    const float SCENE_STRENGTH = 0.9;
    vec4 scene = dockScene(fragCoord, iResolution.xy, iTime, focused);
    color = mix(color, scene.rgb, scene.a * SCENE_STRENGTH * (1.0 - textMask));

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
