// feline-homunculus.glsl
// Theme: Feline Homunculus Lost in Tokyo on a Rainy Night
// A single-pass fragment shader for Ghostty with 6 composited layers.
// Rain on glass, neon glow bleed, wet pavement reflections, asymmetric
// vignette, 40 Hz gamma entrainment, and luminance-based text protection.
//
// Scene (y down on Metal): dark facades with lit windows either side, six
// abstract neon smears (crimson, electric blue, neon green) reflected in the
// wet pavement, power lines sagging across the top with drips, an
// air-conditioner unit low on the right, and on it the homunculus — a 20x16
// pixel-art cat with amber eyes. It watches the cursor, perks up when you
// type, stares wide-eyed at a text selection, paws at the cursor when it
// lands beside it, blinks on its own clock, sleeps when unfocused, and every
// so often hops down and strolls the street to a random spot and back.
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
        st.y -= time * speed * scale;          // scroll downward (y is down on Metal)

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
// Alley scene helpers. `q` is square-space: (uv.x * aspect, uv.y), y down.
// ---------------------------------------------------------------------------

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Abstract neon: soft, out-of-focus smears of light. No frames, no glyphs —
// a ragged noise-shaped core, a wide halo, a buzz, and the odd outage.
vec3 neonBlob(vec2 q, vec2 c, vec2 r, vec3 tint, float seed, float t, float power) {
    vec2 p = (q - c) / r;
    float d2 = dot(p, p);
    if (d2 > 9.0) return vec3(0.0);
    float outage = step(0.06, fract(hash21(vec2(seed, 1.0)) * 7.0 + t * 0.09));
    float buzz = 0.9 + 0.1 * step(0.3, hash21(vec2(floor(t * 24.0), seed)));
    float on = outage * buzz * power;
    float n = noise(q * 18.0 + vec2(seed * 7.0, t * 0.25));
    float core = exp(-d2 * (1.6 + 0.8 * n));
    float halo = exp(-d2 * 0.45) * 0.35;
    return tint * (core * 1.4 + halo) * on;
}

// Six smears up the two facades: crimson, electric blue, neon green.
vec3 alleySigns(vec2 q, float aspect, float t, float power) {
    vec3 crimson = vec3(0.80, 0.04, 0.14);
    vec3 eblue   = vec3(0.10, 0.30, 1.00);
    vec3 ngreen  = vec3(0.20, 1.00, 0.40);
    vec3 col = vec3(0.0);
    col += neonBlob(q, vec2(0.065, 0.24), vec2(0.035, 0.075), crimson, 1.0, t, power);
    col += neonBlob(q, vec2(0.075, 0.44), vec2(0.045, 0.055), eblue,   2.0, t, power);
    col += neonBlob(q, vec2(0.060, 0.61), vec2(0.030, 0.060), ngreen,  3.0, t, power);
    col += neonBlob(q, vec2(aspect - 0.070, 0.20), vec2(0.040, 0.065), eblue,   4.0, t, power);
    col += neonBlob(q, vec2(aspect - 0.062, 0.39), vec2(0.032, 0.080), crimson, 5.0, t, power);
    col += neonBlob(q, vec2(aspect - 0.075, 0.57), vec2(0.045, 0.050), ngreen,  6.0, t, power);
    return col;
}

// Lit windows in the two facades (x < 0.16 and x > aspect - 0.16, above the pavement).
vec3 facadeWindows(vec2 q, float aspect, float t) {
    float inFacade = step(q.x, 0.16) + step(aspect - 0.16, q.x);
    if (inFacade < 0.5 || q.y > 0.78) return vec3(0.0);
    vec2 cell = vec2(0.045, 0.036);
    vec2 id = floor(q / cell);
    vec2 f = fract(q / cell);
    float h = hash21(id + 77.0);
    float lit = step(0.72, h) * step(0.02, fract(h * 31.0 + t * 0.013)); // some go dark over time
    float pane = step(0.22, f.x) * step(f.x, 0.78) * step(0.2, f.y) * step(f.y, 0.75);
    vec3 warmW = vec3(0.95, 0.75, 0.45), coolW = vec3(0.55, 0.75, 0.95);
    float flick = 0.85 + 0.15 * step(0.5, hash21(vec2(floor(t * 2.0), h)));
    return mix(warmW, coolW, step(0.5, hash21(id + 5.0))) * lit * pane * 0.09 * flick;
}

// Power lines sagging across the top, catching the neon, with occasional drips.
vec3 powerLines(vec2 q, float aspect, float t) {
    vec3 col = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float x = q.x / aspect;
        float y0 = 0.05 + fi * 0.035;
        float sag = 0.04 + fi * 0.02;
        float ly = y0 + sag * 4.0 * x * (1.0 - x);
        float d = abs(q.y - ly);
        col += vec3(0.10, 0.11, 0.15) * smoothstep(0.0025, 0.0, d);
        float cyc = floor(t / 1.7 + fi * 0.33);
        float ph = fract(t / 1.7 + fi * 0.33);
        float dx = hash21(vec2(cyc, fi + 40.0));
        if (hash21(vec2(cyc, fi + 90.0)) > 0.4) {
            float dropLy = y0 + sag * 4.0 * dx * (1.0 - dx);
            vec2 dp = vec2(dx * aspect, dropLy + (0.80 - dropLy) * ph * ph);
            float dd = length((q - dp) * vec2(1.0, 0.6));
            col += vec3(0.6, 0.75, 0.9) * smoothstep(0.006, 0.0, dd) * 0.5;
        }
    }
    return col;
}

// ---------------------------------------------------------------------------
// The homunculus: a 20 x 16 pixel-art sprite. Column x is bit (19 - x).
// Body occupies columns 2..15 facing right; tail frames use columns 0..1;
// paw frames extend to the right into columns 15..19.
// ---------------------------------------------------------------------------
const int CAT_BODY[16] = int[16](1040, 1584, 2032, 4080, 4080, 4080, 2016, 16352, 65504, 131040, 262112, 262112, 262112, 262112, 126912, 116608);
const int CAT_TAIL_A[16] = int[16](0, 0, 0, 0, 0, 0, 524288, 524288, 524288, 262144, 262144, 262144, 262144, 0, 0, 0);
const int CAT_TAIL_B[16] = int[16](0, 0, 0, 0, 0, 0, 0, 0, 0, 524288, 524288, 524288, 262144, 262144, 0, 0);
const int CAT_TAIL_C[16] = int[16](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 262144, 786432, 524288);
const int CAT_PAW_A[16] = int[16](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 0, 0, 0);
const int CAT_PAW_B[16] = int[16](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 31, 0, 0, 0);

// Walking sprite (side view, facing right): body with raised tail, two leg frames.
const int CAT_WALK[16] = int[16](34, 54, 63, 127, 127, 126, 655328, 786400, 917440, 131008, 130944, 0, 0, 0, 0, 0);
const int CAT_LEG_A[16] = int[16](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99072, 99072, 99072, 230272, 0);
const int CAT_LEG_B[16] = int[16](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 196992, 393408, 393408, 917728, 0);

bool spriteBit(int row, int x) { return ((row >> (19 - x)) & 1) == 1; }

// The stroll schedule, from the clock alone. Every STROLL_CYCLE seconds a
// coin flip decides whether the cat goes for a walk: hop down, walk along
// the street to a random spot, sit a while, walk home, hop back up.
// Returns (feet x in square-space, feet y, facing (+1 right / -1 left), walking 0/1).
const float STROLL_CYCLE = 45.0;
vec4 catStroll(float t, vec2 home, float street, float aspect) {
    float c = floor(t / STROLL_CYCLE);
    float ph = fract(t / STROLL_CYCLE);
    float goes = step(0.45, hash21(vec2(c, 9.0)));
    float destX = mix(0.12, 0.75, hash21(vec2(c, 21.0))) * aspect;
    vec2 dest = vec2(destX, street);
    float facing = 1.0, walking = 0.0;
    vec2 pos = home;
    if (goes > 0.5) {
        if (ph >= 0.10 && ph < 0.30) {                 // out
            float sgm = (ph - 0.10) / 0.20;
            float hop = smoothstep(0.0, 0.08, sgm);
            pos = vec2(mix(home.x, dest.x, smoothstep(0.08, 1.0, sgm)), mix(home.y, street, hop));
            pos.y -= 0.02 * sin(3.14159 * clamp(sgm / 0.08, 0.0, 1.0));
            facing = sign(dest.x - home.x); walking = step(0.08, sgm);
        } else if (ph >= 0.30 && ph < 0.62) {          // sitting out there
            pos = dest; facing = sign(dest.x - home.x);
        } else if (ph >= 0.62 && ph < 0.82) {          // home
            float sgm = (ph - 0.62) / 0.20;
            float hop = smoothstep(0.92, 1.0, sgm);
            pos = vec2(mix(dest.x, home.x, smoothstep(0.0, 0.92, sgm)), mix(street, home.y, hop));
            pos.y -= 0.02 * sin(3.14159 * clamp((sgm - 0.92) / 0.08, 0.0, 1.0));
            facing = sign(home.x - dest.x); walking = 1.0 - step(0.92, sgm);
        }
    }
    return vec4(pos, facing, walking);
}

// ---------------------------------------------------------------------------
// Main image — 6 layers
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;
    float aspect = iResolution.x / iResolution.y;
    vec2 q = vec2(uv.x * aspect, uv.y);          // square-space, y down

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
    // Warm side: deep crimson <-> amber (the lantern's gold stays for the cursor)
    vec3 pink  = vec3(0.80, 0.04, 0.14);               // crimson now
    vec3 amber = vec3(0.941, 0.647, 0.000);
    float warmMix = noise(vec2(time * 0.15, 1.0));    // slow shift
    vec3 warmNeon = mix(pink, amber * 0.6, warmMix * 0.5);
    float warmFlicker = 0.7 + 0.3 * noise(vec2(time * 3.0, 10.0));
    float warmFade = smoothstep(0.35, 0.0, uv.x);
    color += warmNeon * warmFade * warmFlicker * 0.08 * neonOn;

    // Cool side: electric blue <-> neon green
    vec3 teal = vec3(0.20, 1.00, 0.40);                // neon green
    vec3 blue = vec3(0.10, 0.30, 1.00);                // electric blue
    float coolMix = noise(vec2(time * 0.12, 50.0));   // independent seed
    vec3 coolNeon = mix(teal, blue, coolMix);
    float coolFlicker = 0.7 + 0.3 * noise(vec2(time * 2.7, 80.0));
    float coolFade = smoothstep(0.65, 1.0, uv.x);
    color += coolNeon * coolFade * coolFlicker * 0.08 * neonOn2;

    // -----------------------------------------------------------------------
    // Layer 3 — Wet Pavement Reflections (bottom 30%)
    // -----------------------------------------------------------------------
    float pavementMask = smoothstep(0.78, 0.92, uv.y);   // the street, low on the screen (y down)

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
    // Layer 3c — The alley: facades, neon signs, power lines, their reflections
    // -----------------------------------------------------------------------
    color += facadeWindows(q, aspect, time) * mix(0.5, 1.0, focused);
    vec3 signs = alleySigns(q, aspect, time, neonOn);
    color += signs * 0.9;
    color += powerLines(q, aspect, time);
    // signs reflected in the wet street: mirrored about the kerb, rippled, dim
    if (uv.y > 0.80) {
        float rip = sin(uv.y * 90.0 + time * 3.0) * 0.004 + sin(uv.y * 47.0 - time * 2.1) * 0.003;
        vec2 mq = vec2(q.x + rip, 1.60 - q.y);
        color += alleySigns(mq, aspect, time, neonOn) * 0.35 * smoothstep(1.0, 0.82, uv.y);
    }

    // -----------------------------------------------------------------------
    // Layer 3d — The homunculus on its air-conditioner unit (pixel art)
    // -----------------------------------------------------------------------
    vec2 acC = vec2(aspect - 0.085, 0.83);
    vec2 acHalf = vec2(0.048, 0.030);
    float ac = sdBox(q - acC, acHalf);
    if (ac < 0.0) {
        color = mix(color, vec3(0.07, 0.08, 0.10), 0.85);
        float grille = step(0.5, fract((q.y - acC.y) * 120.0)) * step(abs(q.x - acC.x), acHalf.x - 0.012);
        color = mix(color, vec3(0.04, 0.045, 0.06), grille * 0.7);
        float led = smoothstep(0.004, 0.0, length(q - (acC + vec2(acHalf.x - 0.010, -acHalf.y + 0.008))));
        color += vec3(0.2, 1.0, 0.4) * led * step(0.5, fract(time * 0.7));
    }
    // sprite blocks are a third of a cell; the cat lives on top of the unit
    // and strolls the street from time to time (asleep, it stays home)
    float bp = max(cell / 3.0, 3.0);
    vec2 home = vec2(acC.x, acC.y - acHalf.y);
    vec4 stroll = catStroll(time, home, 0.86, aspect);
    float asleep = 1.0 - focused;
    vec2 feet = mix(stroll.xy, home, asleep);
    float facing = mix(stroll.z, 1.0, asleep);
    bool walking = stroll.w > 0.5 && asleep < 0.5;
    vec2 catOrigin = vec2(feet.x * iResolution.y - 9.5 * bp, feet.y * iResolution.y - 16.0 * bp);
    vec2 cb = floor((fragCoord - catOrigin) / bp);
    if (cb.x >= 0.0 && cb.x < 20.0 && cb.y >= 0.0 && cb.y < 16.0) {
        int x = int(cb.x), y = int(cb.y);
        if (facing < 0.0) x = 19 - x;                                      // mirror to face left
        vec2 eyesPx = catOrigin + vec2(9.5 + facing * (walking ? 6.5 : 3.0), walking ? 4.5 : 4.5) * bp;
        // what is it watching? the cursor, or a selection if there is one
        vec2 target = curC;
        float selCount = 0.0;
        vec2 selSum = vec2(0.0);
        for (int sy = 0; sy < 5; sy++) {
            for (int sx = 0; sx < 8; sx++) {
                vec2 suv = (vec2(float(sx), float(sy)) + 0.5) / vec2(8.0, 5.0);
                vec3 sc = texture(iChannel0, suv).rgb;
                float m = step(length(sc - iSelectionBackgroundColor), 0.06);
                selCount += m;
                selSum += suv * m;
            }
        }
        float hasSel = step(0.5, selCount);
        if (hasSel > 0.5) target = (selSum / selCount) * iResolution.xy;
        vec2 look = target - eyesPx;
        look.x *= facing;                                                  // in sprite space
        // state
        float alert = max(smoothstep(0.8, 0.0, moveAge), smoothstep(1.0, 0.0, focusAge)) * focused;
        bool blink = fract(time * 0.19 + 0.3) < 0.03 && alert < 0.5;
        bool wide = (alert > 0.5 || hasSel > 0.5) && asleep < 0.5;
        bool eyesOpen = asleep < 0.5 && !blink;
        bool sil, eye, pupil;
        if (walking) {
            int lf = int(mod(floor(time * 6.0), 2.0));
            int legRow = (lf == 0) ? CAT_LEG_A[y] : CAT_LEG_B[y];
            sil = spriteBit(CAT_WALK[y], x) || spriteBit(legRow, x);
            bool eyeCol = (x == 15 || x == 18);
            eye = eyesOpen && eyeCol && (y == 4 || (wide && y == 3));
            pupil = false;                                                 // single-pixel eyes while walking
        } else {
            // the cursor landing beside the cat: it paws at it
            float near = step(length(curC - eyesPx), cell * 7.0) * focused;
            float pawAmt = smoothstep(0.0, 0.12, moveAge) * smoothstep(0.9, 0.5, moveAge) * near;
            float tailRate = mix(1.5, 6.0, alert) * (1.0 - asleep * 0.9);
            int tf = int(mod(floor(time * tailRate), 3.0));
            int tailRow = (tf == 0) ? CAT_TAIL_A[y] : ((tf == 1) ? CAT_TAIL_B[y] : CAT_TAIL_C[y]);
            if (asleep > 0.5) tailRow = CAT_TAIL_C[y];
            int pawRow = (pawAmt > 0.66) ? CAT_PAW_B[y] : ((pawAmt > 0.2) ? CAT_PAW_A[y] : 0);
            bool body = spriteBit(CAT_BODY[y], x);
            if (asleep > 0.5 && y < 2) body = false;                       // ears flatten
            sil = body || spriteBit(tailRow, x) || spriteBit(pawRow, x);
            bool eyeCol = (x == 10 || x == 11 || x == 13 || x == 14);
            bool eyeRow = (y == 4) || (wide && y == 3);
            eye = eyesOpen && eyeCol && eyeRow;
            int pupilL = (look.x < 0.0) ? 10 : 11;
            int pupilR = (look.x < 0.0) ? 13 : 14;
            int pupilY = (wide && look.y < -cell) ? 3 : 4;
            pupil = eye && (x == pupilL || x == pupilR) && y == pupilY;
            if (asleep > 0.5 && y == 4 && eyeCol) { sil = true; }
        }
        if (sil) color = vec3(0.02, 0.02, 0.04);
        if (sil && x <= 3) color += vec3(0.80, 0.04, 0.14) * 0.18;         // crimson rim on the tail side
        if (eye) color = mix(amber, vec3(1.0, 0.85, 0.4), hasSel) * (0.9 + 0.3 * alert + 0.3 * hasSel);
        if (pupil) color = vec3(0.02, 0.02, 0.03);
        if (asleep > 0.5 && y == 4 && (x == 10 || x == 11 || x == 13 || x == 14)) color = vec3(0.06, 0.05, 0.06); // shut lids
    }

    // -----------------------------------------------------------------------
    // Layer 3b — Bottom Glow (city light washing upward)
    // -----------------------------------------------------------------------
    float glowMask = smoothstep(0.62, 1.0, uv.y);      // city light washing up from the street
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
