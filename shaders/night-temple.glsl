// night-temple.glsl
// Theme: Egyptian Night Ritual — Torchlit Temple Open to the Stars
// Deep indigo, gold, turquoise. Tutankhamun's death mask palette.
// Single-pass fragment shader for Ghostty with 5 composited layers.
// Torch flicker, stone vignette, starfield, Nile reflections,
// 40 Hz gamma entrainment, and luminance-based text protection.
//
// Scene (y down on Metal): open to the stars above; two pairs of fluted
// columns with lotus capitals and turquoise hieroglyph bands either side;
// braziers with living flames; a flagstone floor; the Nile below reflecting
// columns and fire; a gold-edged scarab crawling the floor whose shell glint
// turns toward the cursor.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — an oil lamp carried through the temple. Warm gold flame-glow on
//            the cursor; jumps of 2+ cells leave a drifting comet of embers.
//   focus  — unfocused, the braziers burn low and slow and the stone
//            darkens, so the stars overhead come out brighter. Regaining
//            focus flares both torches, settling over about a second.

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
// Interaction helpers
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
// ---------------------------------------------------------------------------

vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// Ember comet: a lamp-glow head glides prev -> cur, a tail of embers breaks
// up behind it. Returns intensity at pixel p.
float emberComet(vec2 p, vec2 a, vec2 b, float age, float cell, float t) {
    const float DUR = 0.6;
    float k = clamp(age / DUR, 0.0, 1.0);
    float ease = 1.0 - pow(1.0 - k, 3.0);
    vec2 head = mix(a, b, ease);
    vec2 ab = head - a;
    float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    float d = length(p - a - ab * h);
    float width = cell * mix(0.2, 0.6, h);
    float body = smoothstep(width, 0.0, d);
    // embers: the tail crumbles into sparks
    float ember = step(0.55, hash21(floor(p / (cell * 0.3)) + floor(t * 20.0)));
    body *= mix(ember, 1.0, h * h);
    return body * (1.0 - k) * mix(0.3, 1.0, h);
}

float sdEllipse2(vec2 p, vec2 r) { return (length(p / r) - 1.0) * min(r.x, r.y); }

// ---------------------------------------------------------------------------
// The temple. `q` is square-space (uv.x * aspect, uv.y), y down on Metal.
// Open to the stars above; columns either side; a flagstone floor at
// FLOOR_Y..NILE_Y with the Nile below, reflecting the columns.
// ---------------------------------------------------------------------------

const float FLOOR_Y = 0.74;
const float NILE_Y  = 0.82;

// One column: lotus capital up top, fluted shaft with a hieroglyph band, a
// base at the floor. Returns (stone mask, fluting shade, glyph mask).
vec3 column(vec2 q, float cx, float w, float torch) {
    float capFlare = smoothstep(0.13, 0.06, q.y);                      // widens toward the top
    float baseFlare = smoothstep(FLOOR_Y - 0.03, FLOOR_Y, q.y);
    float halfW = w * (1.0 + 0.6 * capFlare + 0.3 * baseFlare);
    float inX = step(abs(q.x - cx), halfW);
    float inY = step(0.05, q.y) * step(q.y, FLOOR_Y);
    float stone = inX * inY;
    // fluting: vertical ridges, lit from the inner (torch) side
    float ridge = 0.55 + 0.45 * abs(sin((q.x - cx) / w * 7.0));
    float shade = ridge * (0.7 + 0.5 * torch);
    // capital rings
    shade *= 1.0 - 0.35 * step(abs(q.y - 0.135), 0.004) - 0.35 * step(abs(q.y - 0.10), 0.004);
    // hieroglyph band down the middle of the shaft: 3x3 mini-glyphs per cell
    float band = step(abs(q.x - cx), w * 0.45) * step(0.16, q.y) * step(q.y, FLOOR_Y - 0.05);
    vec2 cellSz = vec2(w * 0.9, 0.036);
    vec2 cid = floor((q - vec2(cx - w * 0.45, 0.0)) / cellSz);
    vec2 cf = fract((q - vec2(cx - w * 0.45, 0.0)) / cellSz);
    vec2 sub = floor(cf * 3.0);
    float glyphOn = step(0.5, hash21(cid + sub * 7.0 + cx * 31.0)) * step(0.1, cf.y) * step(cf.y, 0.9);
    glyphOn *= step(abs(cf.x - 0.5), 0.38);
    return vec3(stone, shade, glyphOn * band);
}

// A brazier: stand, bowl, and a living flame above it. Returns (metal, flame, flame heat 0..1).
vec3 brazier(vec2 q, vec2 bowl, float t, float flicker, float seed) {
    float stand = step(abs(q.x - bowl.x), 0.003) * step(bowl.y, q.y) * step(q.y, FLOOR_Y);
    float foot = step(abs(q.x - bowl.x), 0.014) * step(FLOOR_Y - 0.006, q.y) * step(q.y, FLOOR_Y);
    vec2 bp = (q - bowl) / vec2(0.026, 0.014);
    float bowlM = step(length(bp), 1.0) * step(0.0, bp.y);
    float metal = max(max(stand, foot), bowlM);
    // flame: a wobbling teardrop rising from the bowl
    float h = 0.075 * (0.75 + 0.35 * flicker);
    float fy = (bowl.y - q.y) / h;                                      // 0 at bowl, 1 at tip
    float flame = 0.0, heat = 0.0;
    if (fy > 0.0 && fy < 1.0) {
        float wob = (noise(vec2(fy * 5.0 - t * 7.0, seed)) - 0.5) * 0.02 * fy;
        float halfW = 0.016 * (1.0 - fy) * (1.0 - fy * 0.3) + 0.002;
        float fx = abs(q.x - bowl.x - wob);
        flame = smoothstep(halfW, halfW * 0.5, fx);
        heat = 1.0 - fy;
    }
    return vec3(metal, flame, heat);
}

// The scarab: crawls the floor on a slow out-and-back, pausing at the ends.
// Its shell glint turns toward the cursor. Returns (body, gold edge, glint).
vec3 scarab(vec2 q, float aspect, float t, vec2 cursorQ) {
    float tri = abs(fract(t / 90.0) * 2.0 - 1.0);
    float x = mix(0.26, 0.74, smoothstep(0.12, 0.88, tri)) * aspect;
    float dir = (fract(t / 90.0) < 0.5) ? 1.0 : -1.0;
    vec2 c = vec2(x, FLOOR_Y + 0.045);
    vec2 p = q - c;
    float body = sdEllipse2(p, vec2(0.018, 0.011));
    float head = length(p - vec2(dir * 0.020, 0.0)) - 0.006;
    float shell = min(body, head);
    // legs: three per side, scuttling
    float legs = 1e3;
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float lx = (fk - 1.0) * 0.011;
        float moving = step(0.12, tri) * step(tri, 0.88);                 // still while it pauses at the ends
        float swing = sin(t * 14.0 + fk * 2.1) * 0.004 * moving;
        legs = min(legs, length(p - vec2(lx + swing, 0.013)) - 0.0025);
    }
    float bodyM = smoothstep(0.0015, 0.0, shell) + smoothstep(0.001, 0.0, legs);
    float edge = smoothstep(0.0, -0.002, shell) * (1.0 - smoothstep(0.0, -0.005, shell));
    vec2 toCur = cursorQ - c;
    vec2 gl = c + (length(toCur) > 1e-3 ? normalize(toCur) : vec2(0.0)) * vec2(0.009, 0.005);
    float glint = smoothstep(0.003, 0.0, length(q - gl)) * step(shell, 0.0);
    return vec3(min(bodyM, 1.0), edge, glint);
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
    float low       = 1.0 - focused;                       // braziers burn low
    float flare     = smoothstep(1.0, 0.05, focusAge) * focused;
    float torchRate = mix(3.0, 0.9, low);                  // slow flicker when low
    float torchAmp  = mix(1.0, 0.45, low) + flare * 1.2;

    // -----------------------------------------------------------------------
    // Layer 1 — Torch Flicker (two wall-mounted braziers)
    // -----------------------------------------------------------------------

    // Left torch — warm amber
    vec3 leftTorchColor = vec3(0.95, 0.65, 0.20);
    float leftFlicker = (0.7 + 0.3 * noise(vec2(time * torchRate, 10.0))) * torchAmp;
    float leftFade = smoothstep(0.35, 0.0, uv.x);
    color += leftTorchColor * leftFade * leftFlicker * 0.08;

    // Right torch — slightly cooler gold
    vec3 rightTorchColor = vec3(0.90, 0.55, 0.15);
    float rightFlicker = (0.7 + 0.3 * noise(vec2(time * torchRate, 80.0))) * torchAmp;
    float rightFade = smoothstep(0.65, 1.0, uv.x);
    color += rightTorchColor * rightFade * rightFlicker * 0.08;

    // -----------------------------------------------------------------------
    // Layer 1b — The lamp: gold flame-glow on the cursor, ember comet on jumps
    // -----------------------------------------------------------------------
    float flameFlicker = 0.8 + 0.2 * noise(vec2(time * 7.0, 42.0));
    float lamp = exp(-cursorD * 1.5) * flameFlicker;
    vec3 lampColor = vec3(0.83, 0.65, 0.20); // #d4a634 cursor gold
    color += lampColor * lamp * 0.20 * mix(0.5, 1.0, focused);

    float comet = emberComet(fragCoord, prevC, curC, moveAge, cell, time) * jumpGate;
    color += mix(lampColor, vec3(1.0, 0.9, 0.6), comet) * comet * 0.6;

    // -----------------------------------------------------------------------
    // Layer 2 — Stone Vignette (recessed niche)
    // -----------------------------------------------------------------------
    vec2 vignetteCenter = vec2(0.50, 0.48);
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.75, 0.20, vignetteDist);
    vignette = mix(0.10, 1.0, vignette);
    color *= vignette;
    // unfocused: the stone recedes into the dark
    color *= mix(1.0, 0.65, low);

    // -----------------------------------------------------------------------
    // Layer 2b — The temple: columns, braziers, floor, scarab, Nile reflections
    // -----------------------------------------------------------------------
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(uv.x * aspect, uv.y);
    vec3 stoneCol = vec3(0.16, 0.12, 0.09);
    vec3 goldCol  = vec3(0.83, 0.65, 0.20);
    vec3 glyphCol = vec3(0.45, 0.70, 0.65);                              // faience turquoise
    float colW = 0.045;
    float cxL = 0.085, cxR = aspect - 0.085;
    // columns: outer pair bold, inner pair farther and fainter
    vec3 cL = column(q, cxL, colW, leftFlicker);
    vec3 cR = column(q, cxR, colW, rightFlicker);
    vec3 cL2 = column(q, cxL + 0.19, colW * 0.75, leftFlicker * 0.6);
    vec3 cR2 = column(q, cxR - 0.19, colW * 0.75, rightFlicker * 0.6);
    float stoneNear = max(cL.x, cR.x), stoneFar = max(cL2.x, cR2.x) * (1.0 - stoneNear);
    float shadeNear = max(cL.x * cL.y, cR.x * cR.y), shadeFar = max(cL2.x * cL2.y, cR2.x * cR2.y);
    color = mix(color, stoneCol * shadeFar * 0.55, stoneFar * 0.9);
    color = mix(color, stoneCol * shadeNear, stoneNear * 0.95);
    float glyph = max(cL.z, cR.z) * stoneNear;
    color += glyphCol * glyph * 0.45 * (0.6 + 0.4 * max(leftFlicker, rightFlicker)) * mix(0.4, 1.0, focused);
    // floor: flagstones between FLOOR_Y and NILE_Y, seams offset per row
    if (uv.y >= FLOOR_Y && uv.y < NILE_Y) {
        float row = floor((uv.y - FLOOR_Y) / 0.027);
        float seamY = step(fract((uv.y - FLOOR_Y) / 0.027), 0.10);
        float seamX = step(fract(q.x / 0.09 + row * 0.5), 0.04);
        float torchLight = 0.5 + 0.5 * mix(leftFlicker, rightFlicker, uv.x) * (0.7 + 0.3 * (1.0 - abs(uv.x - 0.5) * 2.0));
        vec3 floorCol = vec3(0.13, 0.10, 0.08) * torchLight;
        color = mix(color, mix(floorCol, floorCol * 0.4, max(seamX, seamY)), 0.9);
    }
    // braziers beside the inner columns
    vec3 bL = brazier(q, vec2(cxL + 0.10, 0.50), time, leftFlicker, 1.0);
    vec3 bR = brazier(q, vec2(cxR - 0.10, 0.50), time, rightFlicker, 2.0);
    float metal = max(bL.x, bR.x), flame = max(bL.y, bR.y), heat = max(bL.z * bL.y, bR.z * bR.y);
    color = mix(color, vec3(0.07, 0.05, 0.03), metal);
    vec3 flameCol = mix(vec3(1.0, 0.45, 0.05), vec3(1.0, 0.95, 0.6), heat * heat);
    color = mix(color, flameCol, flame * mix(0.35, 1.0, focused));
    // the scarab on the floor
    vec3 sc = scarab(q, aspect, time, curC / iResolution.y);
    color = mix(color, vec3(0.06, 0.22, 0.22), sc.x);
    color += goldCol * sc.y * 0.9 + vec3(1.0, 0.95, 0.7) * sc.z * 0.9;
    // the Nile reflects the columns and flames, rippled and dim
    if (uv.y >= NILE_Y) {
        float rip = sin(uv.y * 80.0 + time * 2.0) * 0.004 + sin(uv.y * 37.0 - time * 1.4) * 0.003;
        vec2 mq = vec2(q.x + rip, 2.0 * NILE_Y - 0.08 - q.y);
        vec3 rL = column(mq, cxL, colW, leftFlicker), rR = column(mq, cxR, colW, rightFlicker);
        float rStone = max(rL.x, rR.x);
        vec3 rbL = brazier(mq, vec2(cxL + 0.10, 0.50), time, leftFlicker, 1.0);
        vec3 rbR = brazier(mq, vec2(cxR - 0.10, 0.50), time, rightFlicker, 2.0);
        float fade = smoothstep(1.0, NILE_Y, uv.y);
        color = mix(color, stoneCol * 0.5, rStone * 0.35 * fade);
        color += flameCol * max(rbL.y, rbR.y) * 0.3 * fade * focused;
    }


    // -----------------------------------------------------------------------
    // Layer 3 — Starfield (through open temple roof)
    // -----------------------------------------------------------------------
    float starMask = smoothstep(0.40, 0.15, uv.y);   // open roof: the top of the screen (y down)

    if (starMask > 0.01) {
        float starDensity = 400.0;
        vec2 starCell = floor(uv * starDensity);
        float starHash = hash21(starCell);

        if (starHash > 0.985) {
            // Per-star twinkle speed (0.5-2.0)
            float twinkleSpeed = 0.5 + 1.5 * hash21(starCell + 77.0);
            float twinkle = 0.5 + 0.5 * sin(time * twinkleSpeed + starHash * 6.28);

            // Occasional blue tint
            float blueTint = step(0.5, hash21(starCell + 33.0));
            vec3 starColor = mix(vec3(0.9, 0.88, 0.95), vec3(0.7, 0.8, 1.0), blueTint * 0.3);

            color += starColor * twinkle * starMask * mix(0.5, 0.85, low);
        }
    }

    // -----------------------------------------------------------------------
    // Layer 4 — Nile Reflections (bottom 25%)
    // -----------------------------------------------------------------------
    float nileMask = smoothstep(NILE_Y, NILE_Y + 0.12, uv.y);    // the Nile: below the floor (y down)

    if (nileMask > 0.01) {
        float ripple1 = sin(uv.x * 35.0 + time * 2.5 + uv.y * 15.0) * 0.5 + 0.5;
        float ripple2 = sin(uv.x * 20.0 - time * 1.8 + uv.y * 10.0) * 0.5 + 0.5;
        float ripple = ripple1 * 0.6 + ripple2 * 0.4;

        // Blend torch gold and lapis blue
        vec3 torchGold = vec3(0.95, 0.65, 0.20);
        vec3 lapisBlue = vec3(0.18, 0.37, 0.66);
        float colorShift = sin(uv.x * 3.0 + time * 0.2) * 0.5 + 0.5;
        vec3 nileColor = mix(torchGold, lapisBlue, colorShift);

        color += nileColor * ripple * nileMask * 0.06;
    }

    // -----------------------------------------------------------------------
    // Layer 5 — 40 Hz Gamma Entrainment
    // -----------------------------------------------------------------------
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // -----------------------------------------------------------------------
    // Text Protection
    // -----------------------------------------------------------------------
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
