// Street Shaman: Fighting Demons with Magic
// Ritual fire + smoke shader for Ghostty
// Effects: edge-only heat distortion, firelight flicker, smoke haze, 40Hz gamma entrainment
// Text protection: all atmospheric effects apply to background only; text stays crisp

const float PI = 3.14159265359;
const float GAMMA_HZ = 40.0;      // gamma brainwave entrainment frequency
const float GAMMA_AMP = 0.035;    // +-3.5% brightness — subliminal, below flicker fusion

// --- Noise functions ---

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// --- Main ---

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;

    // Sample the clean terminal texture before any effects
    vec4 clean = texture(iChannel0, uv);

    // --- Text detection ---
    // The background is #0a0a0f (luma ~0.04). Anything significantly brighter is text.
    // We use this mask to shield text from all atmospheric effects.
    float luma = dot(clean.rgb, vec3(0.299, 0.587, 0.114));
    float textMask = smoothstep(0.05, 0.12, luma);

    // --- 1. Heat Distortion (far edges only — text area untouched) ---
    vec2 center = uv - 0.5;
    float dist = length(center);
    float edgeMask = smoothstep(0.5, 0.75, dist);
    float heatStrength = edgeMask * 0.004;
    float distortX = sin(uv.y * 15.0 + time * 0.8) * heatStrength;
    float distortY = cos(uv.x * 12.0 + time * 0.6) * heatStrength * 0.5;
    vec2 distortedUV = clamp(uv + vec2(distortX, distortY), 0.0, 1.0);

    vec4 color = texture(iChannel0, distortedUV);

    // --- 2. Firelight Flicker + Vignette ---
    // Wider safe zone: vignette only bites past dist=0.45
    float vignette = smoothstep(0.78, 0.45, dist);

    // Organic fire flicker
    float flickerNoise = noise(vec2(time * 3.0, uv.y * 5.0));
    float flicker = mix(0.6, 1.0, flickerNoise);

    // Apply flicker to edges, center stays at full brightness
    float edgeFactor = mix(flicker * 0.35, 1.0, vignette);
    color.rgb *= edgeFactor;

    // --- 3. Smoke Haze (far edges, never over text) ---
    vec2 smokeUV = uv * 3.0;
    smokeUV.y -= time * 0.04;
    smokeUV.x += time * 0.02;

    float smoke = fbm(smokeUV);
    float smoke2 = fbm(smokeUV * 1.8 + vec2(time * 0.03, -time * 0.02));
    float smokeFinal = (smoke + smoke2) * 0.5;

    // Push smoke to outer frame only
    vec3 smokeColor = vec3(0.0, 0.2, 0.08);
    float smokeEdge = smoothstep(0.4, 0.7, dist);
    color.rgb += smokeColor * smokeFinal * 0.15 * smokeEdge;

    // --- 4. Azure Smoke Wisps (rising from bottom) ---
    // Tall, thin wisps of blue smoke that drift upward and dissipate.
    // Vertically stretched UV gives them that elongated, wispy character.
    float bottomFade = pow(1.0 - uv.y, 2.5);  // strong at bottom, gone by mid-screen

    // Three wisp columns at different speeds and offsets for organic layering
    vec2 wispUV1 = vec2(uv.x * 2.0, uv.y * 0.8 - time * 0.07);
    vec2 wispUV2 = vec2(uv.x * 2.5 + 1.7, uv.y * 0.6 - time * 0.05);
    vec2 wispUV3 = vec2(uv.x * 1.8 + 3.3, uv.y * 1.0 - time * 0.09);

    float wisp1 = fbm(wispUV1);
    float wisp2 = fbm(wispUV2);
    float wisp3 = fbm(wispUV3);

    // Shape into narrow wisps — threshold and sharpen the noise
    wisp1 = smoothstep(0.35, 0.65, wisp1);
    wisp2 = smoothstep(0.40, 0.70, wisp2);
    wisp3 = smoothstep(0.38, 0.68, wisp3);

    float wisps = (wisp1 + wisp2 * 0.7 + wisp3 * 0.5) * bottomFade;

    // Gentle lateral sway as they rise
    float sway = sin(uv.y * 4.0 + time * 0.5) * 0.02;
    wisps *= smoothstep(0.0, 0.15, uv.x + sway) * smoothstep(0.0, 0.15, 1.0 - uv.x + sway);

    // Azure blue — cool contrast against the green ritual fire
    vec3 azureWisp = vec3(0.0, 0.35, 0.7);
    color.rgb += azureWisp * wisps * 0.12;

    // --- 5. Green ambient glow at bottom edge (fire below) ---
    float bottomGlow = (1.0 - uv.y) * (1.0 - uv.y);
    float glowPulse = 0.5 + 0.5 * sin(time * 1.2);
    vec3 fireGlow = vec3(0.0, 0.12, 0.03) * bottomGlow * mix(0.3, 0.6, glowPulse);
    color.rgb += fireGlow;

    // --- 6. 40 Hz Gamma Entrainment ---
    // Subliminal sinusoidal pulse at 40 Hz — at/above flicker fusion threshold.
    // Conscious perception merges it into steady light; the visual cortex still
    // entrains to the rhythm, promoting gamma-band oscillations associated with
    // sustained attention, learning, and memory (Tsai Lab, MIT Picower Institute).
    //
    // Applied through peripheral vision (edges + background glow) where the
    // retina is most sensitive to temporal modulation. The organic fire noise
    // provides conscious camouflage — you see dancing firelight, your brain
    // receives a steady 40 Hz carrier underneath.
    float gamma = sin(2.0 * PI * GAMMA_HZ * time);
    float gammaModulation = 1.0 + gamma * GAMMA_AMP;
    // Weight toward periphery — peripheral retina is most flicker-sensitive
    float gammaZone = smoothstep(0.15, 0.5, dist);
    color.rgb *= mix(1.0, gammaModulation, gammaZone);

    // --- 7. Text Protection ---
    // Overwrite with the clean, unmodified texture wherever text is detected.
    // All the atmosphere lives on the background; text is untouched and razor-sharp.
    color.rgb = mix(color.rgb, clean.rgb, textMask);

    fragColor = color;
}
