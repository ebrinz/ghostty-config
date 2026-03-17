// street-shaman-static.glsl
// Static variant: vignette + text protection only. No iTime dependency.
// Use with custom-shader-animation = false for near-zero GPU cost.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec4 clean = texture(iChannel0, uv);
    float luma = dot(clean.rgb, vec3(0.299, 0.587, 0.114));
    float textMask = smoothstep(0.05, 0.12, luma);

    vec3 color = clean.rgb;

    // Vignette
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vignette = smoothstep(0.78, 0.45, dist);
    color *= mix(0.6, 1.0, vignette);

    // Text protection
    color = clamp(color, 0.0, 1.0);
    color = mix(color, clean.rgb, textMask);

    fragColor = vec4(color, clean.a);
}
