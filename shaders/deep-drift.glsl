// deep-drift.glsl
// Theme: USS Erebus Terminal — 30 Years Adrift in Deep Space
// A degraded amber phosphor CRT on a 1996-era deep space vessel.
// Single-pass fragment shader for Ghostty with 7 composited layers.
// CRT artifacts, phosphor burn-in, power supply flicker, radiation static,
// H-sync wobble, vignette, 40 Hz gamma entrainment, and text protection.
//
// Scene: the console's forward sensor view behind the text, all in amber
// phosphor and curved with the tube. A slowly tumbling parallax starfield,
// the dark limb of a dead planet crossing the lower right, wireframe debris
// drifting past with sensor tags, a navigation reticle with roll marker and
// range rings, a compass tape along the top, telemetry readouts ticking in
// the corners, and a target bracket wherever the cursor lands.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — slow amber phosphor. The cursor leaves a ghost of itself at its
//            previous position that decays over ~1.4 s, with a faint smear
//            between the two on jumps of 2+ cells. A soft phosphor bloom
//            haloes the resting cursor.
//   focus  — unfocused, the console drops to standby: half brightness,
//            deeper scanlines, heavier power-supply dips. Regaining focus is
//            a CRT power-on: the raster collapses to a bright line and
//            unfolds vertically over ~0.45 s.

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
// CRT barrel distortion — heavier than electrode-shaper (old tube)
// ---------------------------------------------------------------------------

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

// ---------------------------------------------------------------------------
// Layer 2: Phosphor burn-in — permanent damage from decades of static UI
// ---------------------------------------------------------------------------

float burnIn(vec2 uv) {
    float burn = 0.0;

    // Old status bar — horizontal line at ~20% from top
    float statusBar = smoothstep(0.005, 0.0, abs(uv.y - 0.82));
    burn += statusBar * 0.04;

    // Old window border — faint rectangular outline near edges
    float borderL = smoothstep(0.006, 0.0, abs(uv.x - 0.05));
    float borderR = smoothstep(0.006, 0.0, abs(uv.x - 0.95));
    float borderT = smoothstep(0.006, 0.0, abs(uv.y - 0.95));
    float borderB = smoothstep(0.006, 0.0, abs(uv.y - 0.05));
    float vertRange = step(0.05, uv.y) * step(uv.y, 0.95);
    float horizRange = step(0.05, uv.x) * step(uv.x, 0.95);
    burn += (borderL + borderR) * vertRange * 0.03;
    burn += (borderT + borderB) * horizRange * 0.03;

    // Old cursor position — a small bright rectangle, permanently etched
    float cursorX = smoothstep(0.02, 0.0, abs(uv.x - 0.12));
    float cursorY = smoothstep(0.008, 0.0, abs(uv.y - 0.50));
    burn += cursorX * cursorY * 0.05;

    return burn;
}

// ---------------------------------------------------------------------------
// Layer 4: Radiation static — cosmic ray bursts
// ---------------------------------------------------------------------------

float radiationBurst(vec2 uv, float time) {
    // Time cell for burst events — each cell ~7 seconds
    float cellSize = 7.0;
    float cell = floor(time / cellSize);
    float localTime = fract(time / cellSize);

    // Only fire ~40% of cells
    float fires = step(0.6, hash21(vec2(cell, 77.0)));
    if (fires < 0.5) return 0.0;

    // Burst envelope: quick on, quick off (0.1-0.3s within the cell)
    float burstStart = hash21(vec2(cell, 88.0)) * 0.5;
    float burstDuration = 0.015 + hash21(vec2(cell, 99.0)) * 0.03;
    float envelope = smoothstep(burstStart, burstStart + 0.005, localTime)
                   * smoothstep(burstStart + burstDuration, burstStart + burstDuration - 0.005, localTime);

    if (envelope < 0.01) return 0.0;

    // Random rectangular patch position and size
    vec2 patchCenter = vec2(hash21(vec2(cell, 111.0)), hash21(vec2(cell, 222.0)));
    vec2 patchSize = vec2(0.08 + hash21(vec2(cell, 333.0)) * 0.15,
                          0.05 + hash21(vec2(cell, 444.0)) * 0.10);

    // Is this pixel inside the patch?
    vec2 d = abs(uv - patchCenter);
    float inPatch = step(d.x, patchSize.x * 0.5) * step(d.y, patchSize.y * 0.5);
    if (inPatch < 0.5) return 0.0;

    // Sparse pixel noise within the patch (~3% density)
    float pixelNoise = hash21(floor(uv * 800.0) + vec2(cell * 13.7, cell * 7.3));
    float sparsePixel = step(0.97, pixelNoise);

    return sparsePixel * envelope;
}

// ---------------------------------------------------------------------------
// Forward sensor view. `q` is square-space (uv.x * aspect, uv.y) of the
// barrel-distorted uv, so everything curves with the tube. `pxl` is the size
// of one device pixel in q units. All returns are amber intensities 0..1.
// ---------------------------------------------------------------------------

mat2 rot2(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// The ship's slow tumble: a drift angle with a long wobble.
float tumble(float t) { return t * 0.003 + 0.12 * sin(t * 0.05); }

// Three parallax layers of phosphor stars, drifting and tumbling.
float starField(vec2 q, float aspect, float t, float pxl) {
    vec2 c = vec2(aspect * 0.5, 0.5);
    vec2 p = rot2(tumble(t)) * (q - c);
    float acc = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float scale = 28.0 + fi * 30.0;
        vec2 drift = vec2(0.004, 0.0025) * (1.0 + fi * 0.8) * t;
        vec2 sp = (p + drift) * scale;
        vec2 cell = floor(sp);
        vec2 f = fract(sp) - 0.5;
        float h = hash21(cell + fi * 101.0);
        if (h < 0.965) continue;
        vec2 off = (vec2(hash21(cell + 3.0), hash21(cell + 9.0)) - 0.5) * 0.6;
        float d = length(f - off) / scale;                        // back to q units
        float bright = mix(0.35, 1.0, hash21(cell + 17.0)) * (1.0 - fi * 0.25);
        float core = smoothstep(pxl * 1.6, 0.0, d);
        float bloom = smoothstep(pxl * 6.0, 0.0, d) * 0.25;
        acc += (core + bloom) * bright;
    }
    return acc;
}

// Dead planet: a dark disc crossing the lower right with a thin lit limb.
// Returns (body mask, limb glow).
vec2 planet(vec2 q, float aspect, float t) {
    vec2 c = vec2(aspect + 0.25 + 0.02 * sin(t * 0.010), 1.45 + 0.02 * cos(t * 0.013));
    const float R = 0.95;
    float d = length(q - c) - R;
    float body = step(d, 0.0);
    float limb = exp(-max(d, 0.0) * 55.0) * 0.9 + exp(-abs(d) * 220.0) * 0.6;
    // a faint band of reflected light just inside the limb
    limb += smoothstep(0.0, -0.06, d) * (1.0 - smoothstep(-0.06, -0.14, d)) * 0.12;
    return vec2(body, limb);
}

// Tumbling debris: wireframe fragments drifting across over minutes, each
// with a small sensor tag beside it. Returns (outline, tag).
vec2 debris(vec2 q, float aspect, float t, float pxl) {
    float outline = 0.0, tag = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float period = 180.0 + fi * 50.0;
        float cyc = floor(t / period + fi * 0.37);
        float ph = fract(t / period + fi * 0.37);
        float h1 = hash21(vec2(cyc, fi)), h2 = hash21(vec2(cyc, fi + 50.0));
        vec2 a = vec2(-0.1, mix(0.1, 0.9, h1));
        vec2 b = vec2(aspect + 0.1, mix(0.1, 0.9, h2));
        vec2 pos = mix(a, b, ph);
        if (fi == 1.0 || fi == 3.0) pos.x = aspect - pos.x;             // some come from the right
        vec2 p = rot2(t * (0.3 + h1 * 0.5) * ((fi < 2.0) ? 1.0 : -1.0)) * (q - pos);
        vec2 sz = vec2(0.010 + 0.02 * h1, 0.006 + 0.012 * h2);
        vec2 dd = abs(p) - sz;
        float sd = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0);
        outline += smoothstep(pxl * 1.4, 0.0, abs(sd)) * 0.9;
        // a second, inner facet line
        outline += smoothstep(pxl * 1.2, 0.0, abs(p.x * 0.7 + p.y * 0.3)) * step(sd, 0.0) * 0.5;
        // tag: a small bracket and a two-block readout to the upper right
        vec2 tp = q - (pos + vec2(sz.x + 0.012, -sz.y - 0.012));
        float br = step(abs(tp.x), 0.006) * step(abs(tp.y), 0.004);
        br *= step(0.004, abs(tp.x)) + step(0.0025, abs(tp.y));
        tag += min(br, 1.0) * 0.6;
        tag += step(abs(tp.x - 0.012), 0.0035) * step(abs(tp.y), 0.002) * step(0.5, hash21(vec2(floor(t * 2.0), fi))) * 0.6;
    }
    return vec2(min(outline, 1.0), min(tag, 1.0));
}

// Navigation reticle: circle with cardinal ticks, a roll marker riding the
// ship's tumble, two faint dashed range rings.
float reticle(vec2 q, float aspect, float t, float pxl) {
    vec2 c = vec2(aspect * 0.5, 0.5);
    vec2 p = q - c;
    float r = length(p);
    float acc = 0.0;
    acc += smoothstep(pxl * 1.5, 0.0, abs(r - 0.12)) * 0.8;
    // cardinal ticks outside the circle
    float ang = atan(p.y, p.x);
    float tick = smoothstep(pxl * 1.5, 0.0, min(abs(p.x), abs(p.y))) * step(0.125, r) * step(r, 0.15);
    acc += tick * 0.8;
    // roll marker: a small wedge on the circle at the tumble angle
    vec2 m = c + vec2(cos(-1.5708 + tumble(t) * 20.0), sin(-1.5708 + tumble(t) * 20.0)) * 0.12;
    acc += smoothstep(0.006, 0.0, length(q - m)) * 1.0;
    // range rings, dashed by angle, very faint
    float dash = step(0.5, fract(ang * 12.0 / 6.2832));
    acc += smoothstep(pxl * 1.2, 0.0, abs(r - 0.30)) * dash * 0.3;
    acc += smoothstep(pxl * 1.2, 0.0, abs(r - 0.45)) * (1.0 - dash) * 0.22;
    // centre dot
    acc += smoothstep(pxl * 2.0, 0.0, r) * 0.9;
    return acc;
}

// Compass tape along the top: ticks scrolling with the drifting heading.
float compassTape(vec2 q, float aspect, float t, float pxl) {
    float y = 0.055;
    float inBand = step(abs(q.y - y), 0.018);
    float heading = t * 0.004 + 0.05 * sin(t * 0.03);
    float x = q.x + heading;
    float f = fract(x / 0.05);
    float major = step(fract(x / 0.25), 0.05 / 0.25 + 0.001) * step(f, 0.5);
    float tickH = mix(0.006, 0.014, major);
    float tick = smoothstep(pxl * 1.3, 0.0, abs(f - 0.0) * 0.05) * step(abs(q.y - y), tickH);
    tick = max(tick, smoothstep(pxl * 1.3, 0.0, (1.0 - f) * 0.05) * step(abs(q.y - y), tickH));
    float line = smoothstep(pxl * 1.0, 0.0, abs(q.y - (y + 0.016)));
    // lubber mark at centre
    float lub = step(abs(q.x - aspect * 0.5), pxl * 1.5) * step(abs(q.y - y), 0.02);
    return (tick * 0.7 + line * 0.35) * inBand + lub * 0.9;
}

// Telemetry: blocks of fake readouts. Characters are 3x5 cells of `blk`
// device pixels; labels are static, values tick over every couple of seconds.
float telemetry(vec2 pxc, vec2 origin, float rows, float cols, float t, float blk, float seed) {
    vec2 g = floor((pxc - origin) / blk);
    vec2 ch = floor(g / vec2(4.0, 7.0));                    // 3 wide + 1 gap, 5 tall + 2 gap
    vec2 sub = mod(g, vec2(4.0, 7.0));
    if (ch.x < 0.0 || ch.x >= cols || ch.y < 0.0 || ch.y >= rows) return 0.0;
    if (sub.x > 2.0 || sub.y > 4.0) return 0.0;
    float isValue = step(4.0, ch.x);                        // first 4 chars are a label
    float clock = floor(t * mix(0.0, 0.5, isValue) + hash21(ch + seed) * 7.0);
    float on = step(0.5, hash21(ch * 3.1 + sub * 7.7 + seed + clock * 13.0));
    // a blank column between words
    float gapCol = step(abs(ch.x - 4.0), 0.1);
    return on * (1.0 - gapCol) * mix(0.6, 1.0, isValue);
}

// ---------------------------------------------------------------------------
// Interaction helpers
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
// ---------------------------------------------------------------------------

vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// Soft box: 1 inside the cursor rect, feathering out by `soft` pixels.
float cursorBox(vec2 p, vec4 c, float soft) {
    vec2 center = cursorCenter(c);
    vec2 halfSize = max(c.zw * 0.5, vec2(1.0));
    vec2 d = abs(p - center) - halfSize;
    float outside = length(max(d, 0.0));
    return 1.0 - smoothstep(0.0, soft, outside);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 rawUV = fragCoord / iResolution.xy;
    float time = iTime;

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
    float hasPrev   = step(0.5, iPreviousCursor.w);
    float jumpGate  = hasPrev * smoothstep(1.2, 3.0, moveCells);
    float cursorD   = length(fragCoord - curC) / cell;
    float standby   = 1.0 - focused;

    // --- Power-on: raster unfolds from a horizontal line over 0.45 s ---
    const float POWER_DUR = 0.45;
    float unfold = focused * (1.0 - smoothstep(0.0, POWER_DUR, focusAge)); // 1 -> 0
    float vScale = max(1.0 - unfold * unfold, 0.015);
    rawUV.y = 0.5 + (rawUV.y - 0.5) / vScale;
    float rasterLine = unfold * smoothstep(0.02, 0.0, abs(fragCoord.y / iResolution.y - 0.5))
                     * smoothstep(0.0, 0.1, unfold);
    float rasterMask = step(0.0, rawUV.y) * step(rawUV.y, 1.0);

    // --- Layer 5: H-Sync Wobble (applied to UV before sampling) ---
    // A band of horizontal displacement that drifts vertically
    float wobbleZoneCenter = 0.5 + 0.4 * sin(time * 0.15);
    float wobbleZoneWidth = 0.08;
    float wobbleMask = smoothstep(wobbleZoneWidth, 0.0,
                                  abs(rawUV.y - wobbleZoneCenter));
    float wobbleAmount = sin(rawUV.y * 60.0 + time * 2.0) * 0.002 * wobbleMask;
    vec2 wobbledUV = rawUV + vec2(wobbleAmount, 0.0);

    // --- Layer 1: CRT Screen Artifacts ---

    // Barrel distortion — stronger than electrode-shaper (old tube)
    float barrelStrength = 0.08;
    vec2 uv = barrelDistort(wobbledUV, barrelStrength);

    // Chromatic aberration — warm-shifted (red drifts more than blue)
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

    // Text detection — protect text from effects
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // --- Forward sensor view: the console's navigation display behind the text ---
    // Drawn in the barrel-distorted frame so it curves with the tube, before
    // scanlines so it gets them too.
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(uv.x * aspect, uv.y);
    float pxl = 1.0 / iResolution.y;
    vec2 pxc = uv * iResolution.xy;
    vec3 phosphorA = vec3(0.91, 0.63, 0.06);
    float sensorLit = mix(0.45, 1.0, focused);
    vec2 pl = planet(q, aspect, time);
    float stars = starField(q, aspect, time, pxl) * (1.0 - pl.x);        // the planet occludes stars
    vec2 db = debris(q, aspect, time, pxl);
    float ret = reticle(q, aspect, time, pxl);
    float tape = compassTape(q, aspect, time, pxl);
    float blk = max(floor(cell / 7.0), 2.0);
    float tele = telemetry(pxc, vec2(0.03, 0.80) * iResolution.xy, 5.0, 12.0, time, blk, 1.0)
               + telemetry(pxc, vec2(0.76, 0.045) * iResolution.xy, 3.0, 11.0, time, blk, 2.0);
    // target bracket where the cursor just landed: "acquiring"
    float acq = smoothstep(0.7, 0.0, moveAge) * jumpGate;
    if (acq > 0.001) {
        vec2 tp = abs(fragCoord - curC);
        vec2 half2 = vec2(cell * 1.1, cell * 0.8) * (1.0 + 0.6 * acq);
        float onEdge = step(abs(max(tp.x - half2.x, tp.y - half2.y)), 1.2);
        float corner = step(half2.x - cell * 0.5, tp.x) + step(half2.y - cell * 0.35, tp.y);
        ret += onEdge * min(corner, 1.0) * acq * 1.2;
    }
    vec3 sensor = vec3(0.0);
    sensor = mix(sensor, vec3(0.012, 0.009, 0.004), pl.x);              // planet body: darker than space
    sensor += phosphorA * pl.y * 0.22;
    sensor += phosphorA * stars * 0.55;
    sensor += phosphorA * (db.x * 0.45 + db.y * 0.5);
    sensor += phosphorA * ret * 0.32;
    sensor += phosphorA * tape * 0.30;
    sensor += phosphorA * tele * 0.28;
    color = mix(color, sensor, pl.x * 0.6 * (1.0 - textMask));          // the planet darkens the background
    color += (sensor - vec3(0.012, 0.009, 0.004) * pl.x) * sensorLit;

    // Scanlines — thick, old hardware (20% darkening; 35% in standby)
    float scanline = 1.0 - mix(0.20, 0.35, standby) * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // --- Layer 2: Phosphor Burn-In ---
    vec3 amberBurn = vec3(0.76, 0.64, 0.28); // amber tint
    float burn = burnIn(uv);
    color += amberBurn * burn;

    // --- Layer 3: Power Supply Flicker ---
    // Low-frequency noise creates organic brightness dips
    float flickerNoise = noise(vec2(time * 0.3, 0.0));
    float flickerNoise2 = noise(vec2(time * 0.17, 50.0));
    float combined = flickerNoise * flickerNoise2;
    // Threshold to create occasional dips rather than constant modulation
    float dip = smoothstep(0.15, 0.05, combined) * mix(0.15, 0.35, standby);
    color *= (1.0 - dip);

    // --- Layer 3b: Phosphor persistence — the cursor's ghost and bloom ---
    vec3 phosphor = vec3(0.91, 0.63, 0.06); // #e8a010 cursor amber
    // ghost of the previous cursor block, decaying over ~1.4 s
    float ghostAge = clamp(moveAge / 1.4, 0.0, 1.0);
    float ghost = cursorBox(fragCoord, iPreviousCursor, cell * 0.35)
                * pow(1.0 - ghostAge, 1.6) * hasPrev * smoothstep(1.0, 2.0, moveCells);
    color += phosphor * ghost * 0.55;
    // smear between old and new position on jumps
    if (jumpGate > 0.001) {
        vec2 ab = curC - prevC;
        float h = clamp(dot(fragCoord - prevC, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
        float dSmear = length(fragCoord - prevC - ab * h);
        float smear = smoothstep(cell * 0.45, 0.0, dSmear) * pow(1.0 - clamp(moveAge / 0.7, 0.0, 1.0), 2.0);
        color += phosphor * smear * jumpGate * 0.25;
    }
    // bloom around the resting cursor
    float bloom = exp(-cursorD * 1.7) * (0.92 + 0.08 * noise(vec2(time * 8.0, 2.0)));
    color += phosphor * bloom * 0.16 * mix(0.4, 1.0, focused);

    // --- Layer 4: Deep Space Radiation Static ---
    float radiation = radiationBurst(uv, time);
    color += vec3(radiation) * 0.8;

    // --- Layer 6: Vignette (Aggressive, asymmetric) ---
    // Bottom-left is worse — gravity + heat degradation over 30 years
    vec2 vignetteCenter = vec2(0.52, 0.53); // shifted slightly from true center
    float vignetteDist = length(rawUV - vignetteCenter);
    float vignette = smoothstep(0.78, 0.25, vignetteDist);
    vignette = mix(0.15, 1.0, vignette);
    color *= vignette;

    // --- Focus: standby brightness, power-on raster ---
    color *= mix(1.0, 0.5, standby);
    color *= rasterMask;
    color += phosphor * rasterLine * 1.2 + vec3(1.0, 0.95, 0.85) * rasterLine * 0.6;

    // --- Layer 7a: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Layer 7b: Text Protection ---
    color = clamp(color, 0.0, 1.0);
    vec3 cleanText = texture(iChannel0, uv).rgb;
    color = mix(color, cleanText, textMask);

    // CRT edge fade — pixels outside the barrel curve go black
    float edgeFade = smoothstep(0.0, 0.015, uv.x) * smoothstep(1.0, 0.985, uv.x)
                   * smoothstep(0.0, 0.015, uv.y) * smoothstep(1.0, 0.985, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
