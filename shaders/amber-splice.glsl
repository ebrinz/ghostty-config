// amber-splice.glsl
// Theme: Amber Splice — a DNA double helix suspended in amber, spliced with alien DNA.
// Jurassic-Park genetics-lab amber (mosquito-in-amber gold, drifting inclusions) crossed
// with a Spielberg backlight glow and a Cowboys-&-Aliens cyan energy pulse.
// Single-pass fragment shader for Ghostty with 5 composited layers:
// amber wash, suspended motes, gold double helix, alien cyan strand + traveling splice
// pulse, amber vignette, 40 Hz gamma entrainment, and luminance-based text protection.
// Red highlights: rust mutation markers on every third helix node, a blood-amber
// bloom at the vignette edge, rust motes, and a red core in the cursor's inclusion.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — the inclusion. A warm amber glow breathes around the resting
//            cursor like light through resin; a jump of 2+ cells is a splice:
//            a blue-white charge races to the new position and the cyan
//            strand it leaves behind decays.
//   focus  — unfocused, the lab lights go down: amber dims, the traveling
//            splice pulse stops, the alien strand idles. Regaining focus
//            fires one splice pulse up the helix from the cursor's row.

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

// --- Interaction helpers (Ghostty 1.4 uniforms) ---
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

// Splice run: a blue-white charge races prev -> cur with ease-out and the
// cyan strand it leaves behind decays over 0.5 s.
float spliceRun(vec2 p, vec2 a, vec2 b, float age, float cell) {
    const float DUR = 0.5;
    float k = clamp(age / DUR, 0.0, 1.0);
    vec2 head = mix(a, b, 1.0 - pow(1.0 - k, 3.0));
    vec2 ab = head - a;
    float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    float d = length(p - a - ab * h);
    float strand = smoothstep(cell * 0.22, 0.0, d) * (1.0 - k) * mix(0.3, 1.0, h);
    float charge = smoothstep(cell * 0.7, 0.0, length(p - head)) * (1.0 - k);
    return strand + charge;
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
    float dark      = 1.0 - focused;                       // lab lights down
    // focus gain: a splice pulse fires from the cursor's row and runs up the
    // helix (toward the top of the screen, -y on Metal) over ~0.9 s
    float fpY       = curC.y / iResolution.y - focusAge * 0.9;
    float fpd       = (uv.y - fpY) * 6.0;
    float focusPulse = exp(-fpd * fpd) * smoothstep(0.9, 0.2, focusAge) * focused;

    // -----------------------------------------------------------------------
    // Layer 1 — Amber depth wash (light through resin)
    // -----------------------------------------------------------------------
    vec3 amberWarm = vec3(0.55, 0.35, 0.10);
    float wash = noise(uv * 2.5 + vec2(0.0, time * 0.05));
    color += amberWarm * wash * 0.05;

    // -----------------------------------------------------------------------
    // Layer 2 — Suspended motes (gold inclusions drifting upward)
    // -----------------------------------------------------------------------
    float moteDensity = 90.0;
    vec2 moteUV = uv + vec2(0.0, time * 0.02);
    vec2 moteCell = floor(moteUV * moteDensity);
    float moteHash = hash21(moteCell);
    if (moteHash > 0.99) {
        float tw = 0.5 + 0.5 * sin(time * (0.8 + moteHash) + moteHash * 6.28);
        // a quarter of the inclusions are rust-red flecks
        float rustMote = step(0.9975, moteHash);
        color += mix(vec3(0.95, 0.70, 0.30), vec3(0.91, 0.48, 0.31), rustMote) * tw * 0.35;
    }

    // -----------------------------------------------------------------------
    // Layer 3 — DNA double helix (HERO)
    // -----------------------------------------------------------------------
    float cx = 0.5;
    float R = 0.13;
    float twist = 6.0 * 2.0 * PI;
    float phaseY = (uv.y + time * 0.05) * twist + time * 0.6;

    float xA = cx + R * sin(phaseY);
    float xB = cx + R * sin(phaseY + PI);

    float depthA = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY));
    float depthB = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI));

    float w = 0.010;
    float glowA = smoothstep(w, 0.0, abs(uv.x - xA)) * depthA;
    float glowB = smoothstep(w, 0.0, abs(uv.x - xB)) * depthB;

    float beads = 0.5 + 0.5 * sin(phaseY * 3.0);
    float node = pow(beads, 6.0);
    vec3 goldStrand = vec3(0.95, 0.68, 0.22);
    vec3 rust = vec3(0.78, 0.35, 0.18);        // #c85a2e palette red
    vec3 rustBright = vec3(0.91, 0.48, 0.31);  // #e87a4e
    // every third bead is a mutation marker: rust-red instead of gold
    float beadIdx = floor(phaseY * 3.0 / (2.0 * PI) + 0.25);
    float marker = step(2.5, mod(beadIdx, 3.0));
    vec3 nodeColor = mix(goldStrand, rustBright, marker);
    color += goldStrand * (glowA + glowB) * 0.06;
    color += nodeColor * (glowA + glowB) * node * mix(0.10, 0.16, marker);

    // base-pair rungs
    float rungGate = pow(0.5 + 0.5 * sin(phaseY * 3.0 + PI * 0.5), 8.0);
    float betweenX = smoothstep(0.0, 0.01, uv.x - min(xA, xB)) *
                     smoothstep(0.0, 0.01, max(xA, xB) - uv.x);
    color += goldStrand * rungGate * betweenX * 0.04;

    // -----------------------------------------------------------------------
    // Layer 4 — Alien splice strand + traveling pulse
    // -----------------------------------------------------------------------
    float xC = cx + (R * 0.7) * sin(phaseY + PI * 0.66);
    float depthC = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI * 0.66));
    float glowC = smoothstep(0.008, 0.0, abs(uv.x - xC)) * depthC;
    float alienPulse = mix(0.6 + 0.4 * sin(time * 2.0), 0.4, dark);  // idles when dark
    vec3 alienCyan = vec3(0.25, 0.85, 0.90);
    color += alienCyan * glowC * 0.07 * alienPulse;

    // traveling splice pulse — square by multiplication (GLSL pow(x,y) is undefined for x<0)
    float pulseY = 1.0 - fract(time * 0.18);   // runs up the helix (y down)
    float pd = (uv.y - pulseY) * 6.0;
    float pulse = exp(-pd * pd) * focused + focusPulse;
    vec3 spliceWhite = vec3(0.7, 0.9, 1.0);
    color += spliceWhite * pulse * (glowA + glowB + glowC * 1.5) * 0.5;

    // -----------------------------------------------------------------------
    // Layer 4b — The inclusion: amber glow on the cursor, splice run on jumps
    // -----------------------------------------------------------------------
    vec3 inclusion = vec3(1.0, 0.72, 0.22); // #ffb838 cursor amber
    float resin = exp(-cursorD * 1.5) * (0.85 + 0.15 * sin(time * 1.3));
    color += inclusion * resin * 0.20 * mix(0.45, 1.0, focused);
    color += rustBright * exp(-cursorD * 4.0) * 0.14 * mix(0.45, 1.0, focused); // red core
    float run = spliceRun(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += mix(alienCyan, spliceWhite, min(run, 1.0)) * run * 0.6;

    // -----------------------------------------------------------------------
    // Layer 5 — Amber vignette
    // -----------------------------------------------------------------------
    vec2 vc = vec2(0.5, 0.5);
    float vDist = length(uv - vc);
    float vig = smoothstep(0.85, 0.20, vDist);
    vig = mix(0.15, 1.0, vig);
    color *= vig;
    // blood-amber bloom where the resin thickens at the edges
    color += rust * (1.0 - vig) * 0.09;
    color *= mix(1.0, 0.6, dark);   // lab lights down when unfocused

    // -----------------------------------------------------------------------
    // 40 Hz Gamma Entrainment
    // -----------------------------------------------------------------------
    float g = sin(2.0 * PI * GAMMA_HZ * time);
    float periphery = smoothstep(0.15, 0.5, vDist);
    color *= 1.0 + GAMMA_AMP * g * periphery;

    // --- Icy text halo: a 4-tap bloom of the glyphs, tinted ice blue, laid on
    // the background just outside each glyph. Cores are restored below.
    vec2 px = 1.0 / iResolution.xy;
    float halo = 0.0;
    halo += dot(texture(iChannel0, uv + vec2( px.x * 1.5, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722));
    halo += dot(texture(iChannel0, uv + vec2(-px.x * 1.5, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722));
    halo += dot(texture(iChannel0, uv + vec2(0.0,  px.y * 1.5)).rgb, vec3(0.2126, 0.7152, 0.0722));
    halo += dot(texture(iChannel0, uv + vec2(0.0, -px.y * 1.5)).rgb, vec3(0.2126, 0.7152, 0.0722));
    halo = smoothstep(0.08, 0.6, halo * 0.25) * (1.0 - textMask);
    vec3 ice = vec3(0.55, 0.85, 1.0);
    color += ice * halo * 0.28;

    // --- Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
