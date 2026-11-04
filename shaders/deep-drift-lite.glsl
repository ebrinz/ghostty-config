// deep-drift-lite.glsl
// Lite variant: CRT artifacts + burn-in only, no animated noise.
// Drops: power flicker, radiation bursts, h-sync wobble (all noise removed).
// Effects: barrel distortion, chromatic aberration, scanlines, burn-in,
//          vignette, 40Hz gamma entrainment, text protection.
// Interaction: amber phosphor ghost at the cursor's previous position and a
// bloom on the current one; unfocused is standby (half brightness); focus
// gain is a CRT power-on raster unfold.
// Scene (lite): tumbling parallax starfield, the dead planet's limb, the
// navigation reticle. No debris, tape, or telemetry.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;
const float GAMMA_AMP = 0.035;

// ---------------------------------------------------------------------------
// CRT barrel distortion
// ---------------------------------------------------------------------------

vec2 barrelDistort(vec2 uv, float strength) {
    vec2 center = uv - 0.5;
    float dist2 = dot(center, center);
    return uv + center * dist2 * strength;
}

// ---------------------------------------------------------------------------
// Phosphor burn-in — permanent damage from decades of static UI
// ---------------------------------------------------------------------------

float burnIn(vec2 uv) {
    float burn = 0.0;

    // Old status bar
    float statusBar = smoothstep(0.005, 0.0, abs(uv.y - 0.82));
    burn += statusBar * 0.04;

    // Old window border
    float borderL = smoothstep(0.006, 0.0, abs(uv.x - 0.05));
    float borderR = smoothstep(0.006, 0.0, abs(uv.x - 0.95));
    float borderT = smoothstep(0.006, 0.0, abs(uv.y - 0.95));
    float borderB = smoothstep(0.006, 0.0, abs(uv.y - 0.05));
    float vertRange = step(0.05, uv.y) * step(uv.y, 0.95);
    float horizRange = step(0.05, uv.x) * step(uv.x, 0.95);
    burn += (borderL + borderR) * vertRange * 0.03;
    burn += (borderT + borderB) * horizRange * 0.03;

    // Old cursor position
    float cursorX = smoothstep(0.02, 0.0, abs(uv.x - 0.12));
    float cursorY = smoothstep(0.008, 0.0, abs(uv.y - 0.50));
    burn += cursorX * cursorY * 0.05;

    return burn;
}

// --- Forward sensor view helpers (see deep-drift.glsl) ---
float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

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

// --- Interaction helpers (Ghostty 1.4 uniforms) ---
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

float cursorBox(vec2 p, vec4 c, float soft) {
    vec2 halfSize = max(c.zw * 0.5, vec2(1.0));
    vec2 d = abs(p - cursorCenter(c)) - halfSize;
    return 1.0 - smoothstep(0.0, soft, length(max(d, 0.0)));
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
    float jumpGate  = step(0.5, iPreviousCursor.w) * smoothstep(1.2, 3.0, moveCells);
    float cursorD   = length(fragCoord - curC) / cell;
    float hasPrev   = step(0.5, iPreviousCursor.w);
    float standby   = 1.0 - focused;

    // --- Power-on: raster unfolds from a horizontal line over 0.45 s ---
    float unfold = focused * (1.0 - smoothstep(0.0, 0.45, focusAge));
    float vScale = max(1.0 - unfold * unfold, 0.015);
    rawUV.y = 0.5 + (rawUV.y - 0.5) / vScale;
    float rasterLine = unfold * smoothstep(0.02, 0.0, abs(fragCoord.y / iResolution.y - 0.5))
                     * smoothstep(0.0, 0.1, unfold);
    float rasterMask = step(0.0, rawUV.y) * step(rawUV.y, 1.0);

    // --- Layer 1: CRT Screen Artifacts ---

    // Barrel distortion (no h-sync wobble in lite)
    float barrelStrength = 0.08;
    vec2 uv = barrelDistort(rawUV, barrelStrength);

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

    // Text detection
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    // --- Forward sensor view (lite): stars, the planet's limb, the reticle ---
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(uv.x * aspect, uv.y);
    float pxl = 1.0 / iResolution.y;
    vec3 phosphorA = vec3(0.91, 0.63, 0.06);
    float sensorLit = mix(0.45, 1.0, focused);
    vec2 pl = planet(q, aspect, time);
    float stars = starField(q, aspect, time, pxl) * (1.0 - pl.x);
    float ret = reticle(q, aspect, time, pxl);
    vec3 sensor = phosphorA * (pl.y * 0.22 + stars * 0.55 + ret * 0.32);
    color = mix(color, vec3(0.012, 0.009, 0.004), pl.x * 0.6 * (1.0 - textMask));
    color += sensor * sensorLit;

    // Scanlines (deeper in standby)
    float scanline = 1.0 - mix(0.20, 0.35, standby) * mod(floor(fragCoord.y), 2.0);
    color *= scanline;

    // --- Layer 2: Phosphor Burn-In ---
    vec3 amberBurn = vec3(0.76, 0.64, 0.28);
    float burn = burnIn(uv);
    color += amberBurn * burn;

    // --- Phosphor persistence: ghost of the previous cursor, bloom on the current ---
    vec3 phosphor = vec3(0.91, 0.63, 0.06);
    float ghost = cursorBox(fragCoord, iPreviousCursor, cell * 0.35)
                * pow(1.0 - clamp(moveAge / 1.4, 0.0, 1.0), 1.6) * hasPrev * smoothstep(1.0, 2.0, moveCells);
    color += phosphor * ghost * 0.55;
    color += phosphor * exp(-cursorD * 1.7) * 0.16 * mix(0.4, 1.0, focused);

    // --- Layer 6: Vignette (Aggressive, asymmetric) ---
    vec2 vignetteCenter = vec2(0.52, 0.53);
    float vignetteDist = length(rawUV - vignetteCenter);
    float vignette = smoothstep(0.78, 0.25, vignetteDist);
    vignette = mix(0.15, 1.0, vignette);
    color *= vignette;

    // --- Focus: standby brightness, power-on raster ---
    color *= mix(1.0, 0.5, standby) * rasterMask;
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

    // CRT edge fade
    float edgeFade = smoothstep(0.0, 0.015, uv.x) * smoothstep(1.0, 0.985, uv.x)
                   * smoothstep(0.0, 0.015, uv.y) * smoothstep(1.0, 0.985, uv.y);
    color *= edgeFade;

    fragColor = vec4(color, clean.a);
}
