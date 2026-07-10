// amber-splice-static.glsl
// Static variant: frozen DNA helix + amber vignette + text protection.
// No iTime dependency. Use with custom-shader-animation = false.

const float PI = 3.14159265359;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.2126, 0.7152, 0.0722));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // Frozen helix (phase at t=0)
    float cx = 0.5;
    float R = 0.13;
    float twist = 6.0 * 2.0 * PI;
    float phaseY = uv.y * twist;

    float xA = cx + R * sin(phaseY);
    float xB = cx + R * sin(phaseY + PI);
    float depthA = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY));
    float depthB = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI));
    float w = 0.010;
    float glowA = smoothstep(w, 0.0, abs(uv.x - xA)) * depthA;
    float glowB = smoothstep(w, 0.0, abs(uv.x - xB)) * depthB;
    vec3 goldStrand = vec3(0.95, 0.68, 0.22);
    color += goldStrand * (glowA + glowB) * 0.05;

    // Frozen alien cyan strand
    float xC = cx + (R * 0.7) * sin(phaseY + PI * 0.66);
    float depthC = 0.35 + 0.65 * (0.5 + 0.5 * cos(phaseY + PI * 0.66));
    float glowC = smoothstep(0.008, 0.0, abs(uv.x - xC)) * depthC;
    color += vec3(0.25, 0.85, 0.90) * glowC * 0.04;

    // Amber vignette
    vec2 vc = vec2(0.5, 0.5);
    float vDist = length(uv - vc);
    float vig = smoothstep(0.85, 0.20, vDist);
    vig = mix(0.15, 1.0, vig);
    color *= vig;

    // Text protection
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
