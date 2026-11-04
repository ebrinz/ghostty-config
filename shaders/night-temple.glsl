// night-temple.glsl
// Theme: Egyptian Night Ritual — Torchlit Temple Open to the Stars
// Deep indigo, gold, turquoise. Tutankhamun's death mask palette.
// Single-pass fragment shader for Ghostty with 5 composited layers.
// Torch flicker, stone vignette, starfield, Nile reflections,
// 40 Hz gamma entrainment, and luminance-based text protection.
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
    // Layer 3 — Starfield (through open temple roof)
    // -----------------------------------------------------------------------
    float starMask = smoothstep(0.6, 0.85, uv.y);

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
    float nileMask = smoothstep(0.25, 0.0, uv.y);

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
