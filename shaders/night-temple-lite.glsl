// night-temple-lite.glsl
// Lite variant: torch flicker + stone vignette only.
// Drops: starfield, Nile reflections (0 noise saved — those were hash/sin based).
// Effects: torch flicker (2 noise calls), stone vignette, 40Hz gamma, text protection.
// Interaction: gold lamp glow on the cursor, ember comet on jumps of 2+
// cells; unfocused, the braziers burn low; focus gain flares them.

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

// Comet trail: head glides prev -> cur with ease-out, tail fades over 0.5 s.
float cometTrail(vec2 p, vec2 a, vec2 b, float age, float cell) {
    const float DUR = 0.5;
    float k = clamp(age / DUR, 0.0, 1.0);
    vec2 head = mix(a, b, 1.0 - pow(1.0 - k, 3.0));
    vec2 ab = head - a;
    float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
    float d = length(p - a - ab * h);
    return smoothstep(cell * mix(0.25, 0.6, h), 0.0, d) * (1.0 - k) * mix(0.3, 1.0, h);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

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
    float low       = 1.0 - focused;
    float flare     = smoothstep(1.0, 0.05, focusAge) * focused;
    float torchRate = mix(3.0, 0.9, low);
    float torchAmp  = mix(1.0, 0.45, low) + flare * 1.2;

    // --- Layer 1: Torch Flicker ---
    vec3 leftTorchColor = vec3(0.95, 0.65, 0.20);
    float leftFlicker = (0.7 + 0.3 * noise(vec2(time * torchRate, 10.0))) * torchAmp;
    float leftFade = smoothstep(0.35, 0.0, uv.x);
    color += leftTorchColor * leftFade * leftFlicker * 0.08;

    vec3 rightTorchColor = vec3(0.90, 0.55, 0.15);
    float rightFlicker = (0.7 + 0.3 * noise(vec2(time * torchRate, 80.0))) * torchAmp;
    float rightFade = smoothstep(0.65, 1.0, uv.x);
    color += rightTorchColor * rightFade * rightFlicker * 0.08;

    // --- The lamp: gold glow on the cursor, ember comet on jumps ---
    vec3 lampColor = vec3(0.83, 0.65, 0.20);
    color += lampColor * exp(-cursorD * 1.5) * 0.20 * mix(0.5, 1.0, focused);
    float comet = cometTrail(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    color += mix(lampColor, vec3(1.0, 0.9, 0.6), comet) * comet * 0.6;

    // --- Layer 2: Stone Vignette ---
    vec2 vignetteCenter = vec2(0.50, 0.48);
    float vignetteDist = length(uv - vignetteCenter);
    float vignette = smoothstep(0.75, 0.20, vignetteDist);
    vignette = mix(0.10, 1.0, vignette);
    color *= vignette;
    color *= mix(1.0, 0.65, low);   // unfocused: the stone recedes

    // --- Layer 5: 40 Hz Gamma Entrainment ---
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float peripheryWeight = smoothstep(0.15, 0.5, vignetteDist);
    float gammaModulation = 1.0 + GAMMA_AMP * gamma * peripheryWeight;
    color *= gammaModulation;

    // --- Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
