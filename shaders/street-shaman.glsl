// Street Shaman: Fighting Demons with Magic
// Ritual fire + smoke shader for Ghostty
// Effects: edge-only heat distortion, firelight flicker, smoke haze, 40Hz gamma entrainment
// Text protection: all atmospheric effects apply to background only; text stays crisp
//
// Centerpiece: a large 3D Metatron's cube — the 13 points (center + the 12
// vertices of a cuboctahedron) with every pair joined — tumbling slowly and
// morphing into an icosahedron and back on a 24 s cycle. Edges glow ritual
// green, fogged toward azure with depth; nodes burn white-green; each vertex
// carries its Fruit-of-Life circle. Glowing embers rise from the bottom of
// the screen through it.
//
// Interaction (Ghostty 1.4 uniforms):
//   cursor — the ritual candle. A warm green ember-glow sits on the cursor;
//            jumps of 2+ cells scatter a trail of sparks that drift up and die.
//   focus  — unfocused, the fire burns down to embers: flicker slows, the
//            bottom glow and smoke dim, the room darkens. Regaining focus
//            flares the fire for about a second before it settles.

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

// --- Sacred geometry ---------------------------------------------------------

float segDist(vec2 p, vec2 a, vec2 b); // defined with the interaction helpers below

const float PHI = 1.61803398875;

// Cuboctahedron: permutations of (±1, ±1, 0), radius √2. Viewed down a
// 3-fold axis this is Metatron's cube.
const vec3 CUBO[12] = vec3[12](
    vec3( 1.0,  1.0,  0.0), vec3( 1.0, -1.0,  0.0), vec3(-1.0,  1.0,  0.0), vec3(-1.0, -1.0,  0.0),
    vec3( 1.0,  0.0,  1.0), vec3( 1.0,  0.0, -1.0), vec3(-1.0,  0.0,  1.0), vec3(-1.0,  0.0, -1.0),
    vec3( 0.0,  1.0,  1.0), vec3( 0.0,  1.0, -1.0), vec3( 0.0, -1.0,  1.0), vec3( 0.0, -1.0, -1.0)
);
// Icosahedron: cyclic permutations of (0, ±1, ±φ), radius √(1+φ²).
const vec3 ICO[12] = vec3[12](
    vec3( 0.0,  1.0,  PHI), vec3( 0.0,  1.0, -PHI), vec3( 0.0, -1.0,  PHI), vec3( 0.0, -1.0, -PHI),
    vec3( 1.0,  PHI,  0.0), vec3( 1.0, -PHI,  0.0), vec3(-1.0,  PHI,  0.0), vec3(-1.0, -PHI,  0.0),
    vec3( PHI,  0.0,  1.0), vec3( PHI,  0.0, -1.0), vec3(-PHI,  0.0,  1.0), vec3(-PHI,  0.0, -1.0)
);

mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }
mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1.0, 0.0, 0.0, 0.0, c, -s, 0.0, s, c); }

// Morph weight: 0 = Metatron's cube, 1 = icosahedron. 24 s cycle:
// 8 s cube, 4 s morph, 8 s icosahedron, 4 s morph back.
float morphWeight(float t) {
    float ct = mod(t, 24.0);
    return smoothstep(8.0, 12.0, ct) - smoothstep(20.0, 24.0, ct);
}

// Project the 13 vertices. Returns screen position (square coords, y down on
// Metal) in .xy and depth 0..1 (1 = nearest) in .z.
void projectFigure(float t, float aspect, out vec3 P[13], out vec3 V[13]) {
    float m = morphWeight(t);
    // tumble; a touch faster while morphing so the change reads as motion
    float spin = t * 0.22 + m * 0.6;
    mat3 R = rotX(t * 0.13 + 0.4) * rotY(spin);
    float breathe = 1.0 + 0.04 * sin(t * 0.7);
    const float CAM = 3.4;   // camera distance
    const float FOC = 2.5;   // focal length
    const float SIZE = 0.40; // half-height of the figure in screen units
    P[0] = vec3(0.5 * aspect, 0.5, 0.5);
    V[0] = vec3(0.0);
    for (int i = 0; i < 12; i++) {
        vec3 v = normalize(mix(normalize(CUBO[i]), normalize(ICO[i]), m)) * breathe;
        v = R * v;
        V[i + 1] = v;
        float persp = FOC / (CAM + v.z);
        vec2 sp = vec2(0.5 * aspect, 0.5) + v.xy * persp * SIZE;
        // depth: v.z = -1 is nearest the camera
        P[i + 1] = vec3(sp, 0.5 - 0.5 * v.z);
    }
}

// Draw the figure at square-space point q. Returns (edge glow, node glow, circles).
vec3 drawFigure(vec2 q, float t, float aspect, float m) {
    vec3 P[13];
    vec3 V[13];
    projectFigure(t, aspect, P, V);
    float edge = 0.0, node = 0.0, ring = 0.0;
    for (int i = 0; i < 13; i++) {
        vec2 a = P[i].xy;
        float da = length(q - a);
        float depthA = mix(0.45, 1.0, P[i].z);
        node += smoothstep(0.012, 0.0, da) * depthA + smoothstep(0.05, 0.0, da) * 0.25 * depthA;
        // Fruit-of-Life circle: radius ≈ half an edge, scaled with depth
        float r = 0.085 * mix(0.75, 1.25, P[i].z);
        ring += smoothstep(0.004, 0.0, abs(da - r)) * 0.35 * depthA;
        for (int j = i + 1; j < 13; j++) {
            vec2 b = P[j].xy;
            float d = segDist(q, a, b);
            // true solid edges (3D length ≈ 1.0 on the unit figure) and the
            // centre spokes burn bright; longer chords (≥ 1.41) stay faint
            float len = length(V[j] - V[i]);
            float w = mix(1.0, 0.22, smoothstep(1.12, 1.38, len));
            float depth = mix(0.35, 1.0, 0.5 * (P[i].z + P[j].z));
            edge += (smoothstep(0.0022, 0.0, d) + smoothstep(0.016, 0.0, d) * 0.22) * w * depth;
        }
    }
    return vec3(edge, node, ring);
}

// Rising embers: hash-placed glowing motes that drift upward (toward the top
// of the screen, which is -y on Metal), sway, and flicker.
float emberField(vec2 q, float t) {
    float acc = 0.0;
    for (int layer = 0; layer < 2; layer++) {
        float scale = (layer == 0) ? 9.0 : 15.0;
        float speed = (layer == 0) ? 0.055 : 0.035;
        vec2 st = q * scale;
        st.y += t * speed * scale;            // pattern scrolls toward -y: rises
        vec2 cell = floor(st);
        vec2 f = fract(st);
        float h = hash(cell + float(layer) * 53.0);
        if (h < 0.72) continue;
        vec2 pos = vec2(hash(cell + 1.3), hash(cell + 7.1)) * 0.7 + 0.15;
        pos.x += sin(t * 1.3 + h * 6.28) * 0.12;
        float d = length(f - pos);
        float flick = 0.55 + 0.45 * sin(t * (3.0 + h * 6.0) + h * 30.0);
        float r = 0.035 + 0.03 * h;
        float core = smoothstep(r, 0.0, d);
        float halo = smoothstep(r * 3.0, 0.0, d) * 0.3;
        acc += (core + halo) * flick * ((layer == 0) ? 1.0 : 0.55);
    }
    return acc;
}

// --- Interaction helpers ---
// iCurrentCursor / iPreviousCursor: xy = left edge and +Y edge in fragCoord
// pixels, zw = size. Same convention as fragCoord on every backend.
vec2 cursorCenter(vec4 c) { return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5); }

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

// Spark trail: hash-placed embers along the prev->cur path. Each spark is
// born at a point on the path, drifts upward and fades over its lifetime.
float sparkTrail(vec2 p, vec2 a, vec2 b, float age, float cell) {
    const float LIFE = 0.9;
    if (age > LIFE) return 0.0;
    vec2 ab = b - a;
    float len = max(length(ab), 1e-3);
    vec2 dir = ab / len;
    // project p onto the path to find which spark slots are nearby
    float along = clamp(dot(p - a, dir), 0.0, len);
    float slot = cell * 0.55;                      // one spark every ~half cell
    float idx = floor(along / slot);
    float acc = 0.0;
    for (int i = -1; i <= 1; i++) {
        float si = idx + float(i);
        if (si < 0.0 || si * slot > len) continue;
        float h1 = hash(vec2(si, 17.0) + floor(a.x + a.y));
        float h2 = hash(vec2(si, 91.0) + floor(b.x + b.y));
        if (h1 < 0.45) continue;                   // sparse
        vec2 born = a + dir * (si * slot + h2 * slot);
        // the head of the path lights later than the tail
        float delay = (si * slot / len) * 0.25;
        float t = age - delay;
        if (t < 0.0) continue;
        vec2 pos = born + vec2((h2 - 0.5) * cell * 1.2 * t, -cell * (0.8 + h1) * t * 1.6);
        float d = length(p - pos);
        float r = cell * 0.09 * (1.0 - t / LIFE) + 0.5;
        float life = 1.0 - t / LIFE;
        acc += smoothstep(r * 2.5, 0.0, d) * life * life;
    }
    return acc;
}

// --- Main ---

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;
    float aspectRatio = iResolution.x / iResolution.y;

    // Sample the clean terminal texture before any effects
    vec4 clean = texture(iChannel0, uv);

    // --- Text detection ---
    // The background is #0a0a0f (luma ~0.04). Anything significantly brighter is text.
    // We use this mask to shield text from all atmospheric effects.
    float luma = dot(clean.rgb, vec3(0.299, 0.587, 0.114));
    float textMask = smoothstep(0.05, 0.12, luma);

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
    float embers    = 1.0 - focused;                       // unfocused: fire burns low
    // focus flare: 1.0 at the instant of focus, settles to 0 by ~1.1 s
    float flare     = smoothstep(1.1, 0.05, focusAge) * focused;

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
    float flickerNoise = noise(vec2(time * mix(3.0, 0.8, embers), uv.y * 5.0));
    float flicker = mix(0.6, 1.0, flickerNoise);
    flicker *= mix(1.0, 0.55, embers);           // embers glow, they don't dance
    flicker += flare * 0.5;                      // the flare lights the walls

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
    color.rgb += smokeColor * smokeFinal * mix(0.15, 0.22, embers) * smokeEdge;

    // --- 4. Azure Smoke Wisps (rising from bottom) ---
    // Tall, thin wisps of blue smoke that drift upward and dissipate.
    // Vertically stretched UV gives them that elongated, wispy character.
    float bottomFade = pow(uv.y, 2.5);  // strong at the bottom of the screen (y down), gone by mid-screen

    // Three wisp columns at different speeds and offsets for organic layering
    vec2 wispUV1 = vec2(uv.x * 2.0, uv.y * 0.8 + time * 0.07);        // + : the wisps rise
    vec2 wispUV2 = vec2(uv.x * 2.5 + 1.7, uv.y * 0.6 + time * 0.05);
    vec2 wispUV3 = vec2(uv.x * 1.8 + 3.3, uv.y * 1.0 + time * 0.09);

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

    // --- 4b. Sacred geometry centerpiece ---
    // Square-space coords so circles are round and lines have even width.
    vec2 q = vec2(uv.x * aspectRatio, uv.y);
    float morph = morphWeight(time);
    vec3 fig = drawFigure(q, time, aspectRatio, morph);
    vec3 ritualGreen = vec3(0.0, 1.0, 0.25);
    vec3 azure = vec3(0.0, 0.45, 0.85);
    vec3 whiteHot = vec3(0.85, 1.0, 0.8);
    // edges: green, pulled toward azure during the morph (spectral shift)
    vec3 edgeColor = mix(ritualGreen, azure, morph * 0.6);
    float figDim = mix(1.0, 0.45, 1.0 - focused);
    color.rgb += edgeColor * min(fig.x, 2.0) * 0.5 * figDim;
    color.rgb += whiteHot * min(fig.y, 1.5) * 0.7 * figDim;
    color.rgb += mix(azure, ritualGreen, 0.5) * min(fig.z, 1.0) * 0.4 * figDim;

    // --- 4c. Rising embers: strongest low on the screen, fading as they climb ---
    float ember = emberField(q, time);
    float climbFade = smoothstep(0.05, 0.55, uv.y);       // y down: large = low on screen
    vec3 emberColor = mix(vec3(0.3, 1.0, 0.2), vec3(0.95, 1.0, 0.6), ember * 0.5);
    color.rgb += emberColor * ember * climbFade * 0.55 * mix(0.5, 1.0, focused);

    // --- 5. Green ambient glow at bottom edge (fire below) ---
    float bottomGlow = uv.y * uv.y;   // fire below: the bottom of the screen (y down)
    float glowPulse = 0.5 + 0.5 * sin(time * 1.2);
    vec3 fireGlow = vec3(0.0, 0.12, 0.03) * bottomGlow * mix(0.3, 0.6, glowPulse);
    fireGlow *= mix(1.0, 0.35, embers) + flare * 2.5;
    color.rgb += fireGlow;

    // --- 5b. The candle: ember glow on the cursor, sparks when it moves ---
    float candle = exp(-cursorD * 1.4) * (0.8 + 0.2 * noise(vec2(time * 6.0, 3.0)));
    vec3 candleColor = vec3(0.0, 1.0, 0.25);
    color.rgb += candleColor * candle * 0.18 * mix(0.35, 1.0, focused);

    float sparks = sparkTrail(fragCoord, prevC, curC, moveAge, cell) * jumpGate;
    vec3 sparkColor = mix(vec3(0.0, 1.0, 0.25), vec3(0.9, 1.0, 0.7), sparks);
    color.rgb += sparkColor * sparks * 0.7;

    // --- Focus: embers only when the window is in the background ---
    color.rgb *= mix(1.0, 0.65, embers);

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
