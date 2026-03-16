#ifdef GL_ES
precision mediump float;
#endif

vec4 FlutterFragCoord() {
    return vec4(gl_FragCoord.xy, 0.0, 0.0);
}

uniform vec2      uSize;
uniform float     uOffsetX;
uniform float     uOffsetY;
uniform float     uScale;
uniform sampler2D uTexture;

out vec4 fragColor;

const vec3 kPrimary = vec3(0.424, 0.478, 0.588);
const vec3 kAccent  = vec3(0.545, 0.624, 0.749);

const float kBaseSpacing = 28.0;
const float kBaseDotR    =  2.0;
const float kAccentMult  =  1.8;
const float kAccentEvery =  4.0;


const float kImageWorldRadius = kBaseSpacing * 0.001;
const float kRevealStartPx    = 4.0;
const float kRevealFullPx     = 30.0;


const float kEdgeSoftStart = 0.70;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 world = (fragCoord - vec2(uOffsetX, uOffsetY)) / uScale;

    float feather = 1.0 / uScale;

    float primaryR = max(kBaseDotR, 0.6 / uScale);
    float accentR  = max(kBaseDotR * kAccentMult, 1.0 / uScale);

    float spacing       = kBaseSpacing;
    float accentSpacing = kBaseSpacing * kAccentEvery;

    vec2 primCell = mod(world, spacing)       - spacing       * 0.5;
    vec2 accCell  = mod(world, accentSpacing) - accentSpacing * 0.5;

    float primDist  = length(primCell);
    float primAlpha = 1.0 - smoothstep(primaryR - feather, primaryR + feather, primDist);

    float accDist  = length(accCell);
    float accAlpha = 1.0 - smoothstep(accentR - feather, accentR + feather, accDist);

    float scaleVis    = clamp(uScale * 1.2, 0.15, 1.0);
    float primOpacity = 0.38 * scaleVis;
    float accOpacity  = 0.60;

    float dotAlpha = max(primAlpha * primOpacity, accAlpha * accOpacity);
    vec3  dotColor = mix(kPrimary, kAccent, accAlpha);
    
    float imageScreenRadius = kImageWorldRadius * uScale;

    float zoomReveal = smoothstep(kRevealStartPx, kRevealFullPx, imageScreenRadius);


    vec2 texUV = primCell / (kImageWorldRadius * 2.0) + 0.5;

    float normDist  = length(primCell) / kImageWorldRadius;
    float edgeMask  = 1.0 - smoothstep(kEdgeSoftStart, 1.0, normDist);

    texUV = clamp(texUV, 0.0, 1.0);
    vec4 texColor = texture(uTexture, texUV);

    float imgAlpha = zoomReveal * edgeMask * texColor.a;
    
    vec3  finalColor = mix(dotColor * dotAlpha, texColor.rgb, imgAlpha);
    float finalAlpha = dotAlpha + imgAlpha * (1.0 - dotAlpha);

    fragColor = finalAlpha > 0.0
    ? vec4(finalColor / finalAlpha * finalAlpha, finalAlpha)
    : vec4(0.0);
}
