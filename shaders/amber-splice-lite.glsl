// amber-splice-lite.glsl
// Lite variant: DNA helix (gold double strand + cyan alien strand + nodes) + amber vignette.
// Drops: amber wash, suspended motes, base-pair rungs, traveling splice pulse.
// Effects: helix (0 noise calls — pure sine math), amber vignette, 40 Hz gamma, text protection.

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
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // --- Layer: DNA helix (gold double strand + nodes) ---
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
    color += goldStrand * (glowA + glowB) * (0.06 + 0.10 * node);

    // --- Layer: alien cyan strand ---
    float xC = cx + (R * 0.7) * sin(phaseY + PI * 0.66);
    float depthC = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI * 0.66));
    float glowC = smoothstep(0.008, 0.0, abs(uv.x - xC)) * depthC;
    float alienPulse = 0.6 + 0.4 * sin(time * 2.0);
    vec3 alienCyan = vec3(0.25, 0.85, 0.90);
    color += alienCyan * glowC * 0.07 * alienPulse;

    // --- Layer: amber vignette ---
    vec2 vc = vec2(0.5, 0.5);
    float vDist = length(uv - vc);
    float vig = smoothstep(0.85, 0.20, vDist);
    vig = mix(0.15, 1.0, vig);
    color *= vig;

    // --- 40 Hz Gamma Entrainment ---
    float g = sin(2.0 * PI * GAMMA_HZ * time);
    float periphery = smoothstep(0.15, 0.5, vDist);
    color *= 1.0 + GAMMA_AMP * g * periphery;

    // --- Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
