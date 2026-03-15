#ifdef GL_ES
precision mediump float;
#endif

// Flutter injiziert diese Funktion auf Native via runtime_effect.glsl —
// auf Web definieren wir sie selbst über gl_FragCoord.
vec4 FlutterFragCoord() {
    return vec4(gl_FragCoord.xy, 0.0, 0.0);
}

uniform vec2  uSize;
uniform float uOffsetX;
uniform float uOffsetY;
uniform float uScale;

out vec4 fragColor;

const vec3 kPrimary = vec3(0.424, 0.478, 0.588);
const vec3 kAccent  = vec3(0.545, 0.624, 0.749);

const float kBaseSpacing = 28.0;
const float kBaseDotR    =  2.0;
const float kAccentMult  =  1.8;
const float kAccentEvery =  4.0;

float dotSDF(vec2 uv, float baseSpacing) {
    vec2 cell = mod(uv, baseSpacing) - baseSpacing * 0.5;
    return length(cell);
}


void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 world = (fragCoord - vec2(uOffsetX, uOffsetY)) / uScale;

    float feather = 1.0 / uScale;

    float primaryR = max(kBaseDotR, 0.6 / uScale);
    float accentR  = max(kBaseDotR * kAccentMult, 1.0 / uScale);

    float spacing       = kBaseSpacing;
    float accentSpacing = kBaseSpacing * kAccentEvery;

    float primDist  = dotSDF(world, spacing);
    float primAlpha = 1.0 - smoothstep(primaryR - feather, primaryR + feather, primDist);

    float accDist   = dotSDF(world, accentSpacing);
    float accAlpha  = 1.0 - smoothstep(accentR - feather, accentR + feather, accDist);

    float scaleVis    = clamp(uScale * 1.2, 0.15, 1.0);
    float primOpacity = 0.38 * scaleVis;
    float accOpacity  = 0.60;

    float alpha = max(primAlpha * primOpacity, accAlpha * accOpacity);
    vec3  color = mix(kPrimary, kAccent, accAlpha);

    fragColor = vec4(color * alpha, alpha);
}
