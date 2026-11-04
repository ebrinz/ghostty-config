// feline-homunculus.glsl
// Theme: Feline Homunculus Lost in Tokyo on a Rainy Night
// A single-pass fragment shader for Ghostty with 6 composited layers.
// Rain on glass, neon glow bleed, wet pavement reflections, asymmetric
// vignette, 40 Hz gamma entrainment, and luminance-based text protection.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — a paper lantern carried through the alley. Amber glow on the
//            cursor with a wet-pavement reflection smeared beneath it; on
//            jumps of 2+ cells the light streaks like a long-exposure photo.
//   focus  — unfocused, the neon signs shut off and the alley goes cold and
//            blue while the rain keeps falling. Regaining focus brings the
//            neon back with the classic stuttering tube warm-up.

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;     // gamma brainwave entrainment frequency
const float GAMMA_AMP = 0.035;   // +-3.5% brightness — subliminal

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
    // Smooth interpolation (Hermite)
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x),
               mix(c, d, u.x), u.y);
}

// ---------------------------------------------------------------------------
// Rain streak function — hash-based particle system (NOT fbm)
// ---------------------------------------------------------------------------

float rainStreak(vec2 uv, float time) {
    float rain = 0.0;

    // Two layers for depth parallax
    // Layer 0: close rain  — scale 30, speed 1.2, full brightness
    // Layer 1: far rain    — scale 50, speed 1.8, half brightness
    for (int layer = 0; layer < 2; layer++) {
        float scale     = (layer == 0) ? 14.0 : 24.0;
        float speed     = (layer == 0) ? 1.4  : 2.0;
        float brightness = (layer == 0) ? 1.0  : 0.5;

        vec2 st = uv * scale;
        st.y += time * speed * scale;          // scroll downward

        vec2 cell = floor(st);
        vec2 local = fract(st);

        // Per-cell random: does this cell have a drop?
        float cellHash = hash21(cell + float(layer) * 137.0);
        if (cellHash < 0.65) continue;          // sparsity gate: step(0.65, hash)

        // Random x-offset so drops don't align on a grid
        float xOff = hash21(cell + 0.5 + float(layer) * 73.0);

        // Wind sway — shifts the whole streak, bending more at the tail
        float wind = sin(cell.y * 0.8 + time * 2.0 + xOff * 6.28);
        float wobbleHead = wind * 0.08;
        float wobbleTail = wind * 0.16;  // tail drifts further in the wind
        float wobble = mix(wobbleTail, wobbleHead, smoothstep(0.0, 0.8, local.y));

        float dropX = fract(xOff + wobble);

        // Tapered streak: wider at the bright head, thinner at the fading tail
        float taper = 0.3 + 0.7 * smoothstep(0.0, 0.7, local.y);
        float dx = abs(local.x - dropX);
        float baseWidth = (layer == 0) ? 0.018 : 0.03;  // foreground thinner
        float lineWidth = (baseWidth + 0.01 * hash21(cell + 99.0)) * taper;
        float streak = smoothstep(lineWidth, 0.0, dx);

        // Streak fade: bright head at bottom, long trail fading above
        float trail = pow(smoothstep(0.0, 0.85, local.y), 1.8);
        float headCap = smoothstep(1.0, 0.93, local.y);  // tiny fade at leading edge
        streak *= trail * headCap;

        rain += streak * brightness;
    }

    return clamp(rain, 0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Interaction helpers
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
// ---------------------------------------------------------------------------

vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

// Long-exposure light streak from prev to cur: brightest at the head,
// fades along its length and over ~0.5 s.
float lightStreak(vec2 p, vec2 a, vec2 b, float age, float cell) {
    const float DUR = 0.5;
    float k = clamp(age / DUR, 0.0, 1.0);
    float ease = 1.0 - pow(1.0 - k, 3.0);
    vec2 head = mix(a, b, ease);
    float d = segDist(p, a, head);
    vec2 ab = head - a;
    float along = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    float core = smoothstep(cell * 0.18, 0.0, d);
    float halo = smoothstep(cell * 0.9, 0.0, d) * 0.35;
    return (core + halo) * (1.0 - k) * mix(0.15, 1.0, along);
}

// Neon tube warm-up: stutters on over ~1.2 s, then holds steady at 1.0.
float neonWarmup(float age, float seed) {
    if (age > 1.2) return 1.0;
    float ramp = smoothstep(0.0, 1.2, age);
    float stutter = step(0.45, hash21(vec2(floor(age * 24.0), seed)));
    return mix(stutter * ramp, 1.0, ramp * ramp);
}

// ---------------------------------------------------------------------------
// Main image — 6 layers
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // -----------------------------------------------------------------------
    // --- Text detection (sampled before effects) ---
    // -----------------------------------------------------------------------
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);   // 1 on text, 0 on bg

    // Start compositing on top of the terminal background
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
    // neon power: off when unfocused, stuttering back on after focus
    float neonOn    = focused * neonWarmup(focusAge, 5.0);
    float neonOn2   = focused * neonWarmup(focusAge + 0.3, 11.0);

    // -----------------------------------------------------------------------
    // Layer 1 — Rain Streaks on Glass
    // -----------------------------------------------------------------------
    float rain = rainStreak(uv, time);
    vec3 rainColor = vec3(0.6, 0.75, 0.9);           // cool white-blue
    color += rainColor * rain * 0.18;

    // -----------------------------------------------------------------------
    // Layer 2 — Neon Glow Bleed (left warm, right cool)
    // -----------------------------------------------------------------------
    // Warm neon: pink #e84a72 <-> amber #f0a500
    vec3 pink  = vec3(0.910, 0.290, 0.447);
    vec3 amber = vec3(0.941, 0.647, 0.000);
    float warmMix = noise(vec2(time * 0.15, 1.0));    // slow shift
    vec3 warmNeon = mix(pink, amber, warmMix);
    float warmFlicker = 0.7 + 0.3 * noise(vec2(time * 3.0, 10.0));
    float warmFade = smoothstep(0.35, 0.0, uv.x);
    color += warmNeon * warmFade * warmFlicker * 0.08 * neonOn;

    // Cool neon: teal #45c8c2 <-> blue #4a9cd6
    vec3 teal = vec3(0.271, 0.784, 0.761);
    vec3 blue = vec3(0.290, 0.612, 0.839);
    float coolMix = noise(vec2(time * 0.12, 50.0));   // independent seed
    vec3 coolNeon = mix(teal, blue, coolMix);
    float coolFlicker = 0.7 + 0.3 * noise(vec2(time * 2.7, 80.0));
    float coolFade = smoothstep(0.65, 1.0, uv.x);
    color += coolNeon * coolFade * coolFlicker * 0.08 * neonOn2;

    // -----------------------------------------------------------------------
    // Layer 3 — Wet Pavement Reflections (bottom 30%)
    // -----------------------------------------------------------------------
    float pavementMask = smoothstep(0.3, 0.0, uv.y);

    // Two sine-wave ripples at different frequencies
    float ripple1 = sin(uv.x * 40.0 + time * 3.0 + uv.y * 20.0) * 0.5 + 0.5;
    float ripple2 = sin(uv.x * 25.0 - time * 2.3 + uv.y * 15.0) * 0.5 + 0.5;
    float ripple = ripple1 * 0.6 + ripple2 * 0.4;

    // Reflected colors: warm/cool neon shifting across x with time
    float refShift = noise(vec2(uv.x * 2.0 + time * 0.1, 200.0));
    vec3 reflected = mix(warmNeon, coolNeon, refShift);

    // Amber lantern ripples mixed at 0.3 weight
    vec3 lantern = amber * ripple;
    vec3 pavementColor = mix(reflected * ripple, lantern, 0.3);

    color += pavementColor * pavementMask * 0.07 * mix(0.25, 1.0, neonOn);

    // -----------------------------------------------------------------------
    // Layer 3a — The lantern: amber glow on the cursor, its reflection smeared
    // down the wet pavement beneath it, and a light streak when it moves.
    // -----------------------------------------------------------------------
    float lanternFlicker = 0.85 + 0.15 * noise(vec2(time * 5.0, 7.0));
    float lampGlow = exp(-cursorD * 1.5) * lanternFlicker;
    // reflection: a vertical smear below the cursor (+Y is down the screen
    // in Ghostty's cursor space), rippled like the pavement
    vec2 below = fragCoord - curC;
    float refX = smoothstep(cell * 1.2, 0.0, abs(below.x));
    float refY = smoothstep(0.0, cell * 1.0, below.y) * smoothstep(cell * 7.0, cell * 1.5, below.y);
    float refRipple = 0.6 + 0.4 * sin(below.y / cell * 6.0 - time * 3.0);
    float reflection = refX * refY * refRipple;
    vec3 lanternColor = mix(amber, pink, 0.25);
    color += lanternColor * (lampGlow * 0.22 + reflection * 0.10) * mix(0.4, 1.0, focused);

    float streak = lightStreak(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += mix(lanternColor, vec3(1.0, 0.95, 0.85), streak) * streak * 0.6;

    // -----------------------------------------------------------------------
    // Layer 3b — Bottom Glow (city light washing upward)
    // -----------------------------------------------------------------------
    float glowMask = smoothstep(0.35, 0.0, uv.y);      // fades out by 35% up
    float glowPulse = 0.85 + 0.15 * noise(vec2(time * 0.2, 300.0));
    // Warm amber-pink blend that shifts slowly
    float glowShift = noise(vec2(uv.x * 1.5 + time * 0.08, 400.0));
    vec3 glowColor = mix(amber * 0.7 + pink * 0.3,
                         teal  * 0.5 + amber * 0.5, glowShift);
    color += glowColor * glowMask * glowPulse * 0.10 * mix(0.3, 1.0, neonOn);

    // -----------------------------------------------------------------------
    // Layer 4 — Asymmetric Vignette
    // -----------------------------------------------------------------------
    vec2 vignetteCenter = vec2(0.55, 0.45);           // darker top-left, lighter bottom-right
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.8, 0.35, vignetteDist);
    vignette = mix(0.3, 1.0, vignette);               // corner darkness floor
    color *= vignette;

    // --- Focus: unfocused, the alley goes cold — desaturate toward blue, dim ---
    float cold = 1.0 - focused;
    float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(color, mix(vec3(gray), vec3(0.45, 0.6, 0.9) * gray, 0.5), cold * 0.6);
    color *= mix(1.0, 0.7, cold);

    // -----------------------------------------------------------------------
    // Layer 5 — 40 Hz Gamma Entrainment (subliminal)
    // -----------------------------------------------------------------------
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    // Weight toward periphery — peripheral retina is most flicker-sensitive
    float centerDist = length(uv - vec2(0.5));
    float peripheryWeight = smoothstep(0.15, 0.5, centerDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // -----------------------------------------------------------------------
    // Layer 6 — Text Protection (applied last)
    // -----------------------------------------------------------------------
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
