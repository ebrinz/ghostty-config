// grog-harbor-static.glsl
// Static variant: Bayer dither + scanlines + vignette + text protection only.
// No animation, no time dependence. For screenshots, recording, motion-averse users.

const float PI = 3.14159265359;

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
// Bayer 4x4 ordered dither — VGA palette quantization
// ---------------------------------------------------------------------------

const float bayer4x4[16] = float[16](
     0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
    12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
     3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
    15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

// Ordered-dither palette quantization — 6 quantization levels per channel.
// DIVISOR is (levels - 1), so floor(c * DIVISOR + 0.5) / DIVISOR snaps to
// 6 evenly spaced values: {0, 1/5, 2/5, 3/5, 4/5, 1}.
vec3 ditherQuantize(vec3 color, vec2 fragCoord) {
    ivec2 bc = ivec2(mod(fragCoord, 4.0));
    float threshold = bayer4x4[bc.y * 4 + bc.x];
    const float DIVISOR = 5.0;
    vec3 biased = color + (threshold - 0.5) / DIVISOR;
    return floor(biased * DIVISOR + 0.5) / DIVISOR;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Sample terminal content
    vec4 clean      = texture(iChannel0, uv);
    vec3 cleanText  = clean.rgb;

    // Text detection — luma mask protects text from CRT effects
    float luma = dot(cleanText, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = cleanText;

    // --- Bayer Dither: VGA 256-color ordered quantization ---
    color = ditherQuantize(color, fragCoord);

    // --- Scanlines: 12% darkening on alternating rows ---
    color *= 1.0 - 0.12 * mod(floor(fragCoord.y), 2.0);

    // --- Vignette: midnight harbor darkness at screen edges ---
    vec2 centered = uv - 0.5;
    float dist = length(centered);
    float v = smoothstep(0.85, 0.35, dist);
    v = mix(0.60, 1.0, v);
    color *= v;

    // --- Text Protection: restore clean text after CRT effects ---
    color = clamp(color, 0.0, 1.0);
    color = mix(color, cleanText, textMask);

    fragColor = vec4(color, clean.a);
}
