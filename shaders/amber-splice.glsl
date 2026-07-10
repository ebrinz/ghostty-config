// amber-splice.glsl
// Theme: Amber Splice — a DNA double helix suspended in amber, spliced with alien DNA.
// Jurassic-Park genetics-lab amber (mosquito-in-amber gold, drifting inclusions) crossed
// with a Spielberg backlight glow and a Cowboys-&-Aliens cyan energy pulse.
// Single-pass fragment shader for Ghostty with 5 composited layers:
// amber wash, suspended motes, gold double helix, alien cyan strand + traveling splice
// pulse, amber vignette, 40 Hz gamma entrainment, and luminance-based text protection.

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

    // --- Text detection ---
    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

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
        color += vec3(0.95, 0.70, 0.30) * tw * 0.35;
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
    color += goldStrand * (glowA + glowB) * (0.06 + 0.10 * node);

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
    float alienPulse = 0.6 + 0.4 * sin(time * 2.0);
    vec3 alienCyan = vec3(0.25, 0.85, 0.90);
    color += alienCyan * glowC * 0.07 * alienPulse;

    // traveling splice pulse — square by multiplication (GLSL pow(x,y) is undefined for x<0)
    float pulseY = fract(time * 0.18);
    float pd = (uv.y - pulseY) * 6.0;
    float pulse = exp(-pd * pd);
    vec3 spliceWhite = vec3(0.7, 0.9, 1.0);
    color += spliceWhite * pulse * (glowA + glowB + glowC * 1.5) * 0.5;

    // -----------------------------------------------------------------------
    // Layer 5 — Amber vignette
    // -----------------------------------------------------------------------
    vec2 vc = vec2(0.5, 0.5);
    float vDist = length(uv - vc);
    float vig = smoothstep(0.85, 0.20, vDist);
    vig = mix(0.15, 1.0, vig);
    color *= vig;

    // -----------------------------------------------------------------------
    // 40 Hz Gamma Entrainment
    // -----------------------------------------------------------------------
    float g = sin(2.0 * PI * GAMMA_HZ * time);
    float periphery = smoothstep(0.15, 0.5, vDist);
    color *= 1.0 + GAMMA_AMP * g * periphery;

    // --- Text Protection ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
