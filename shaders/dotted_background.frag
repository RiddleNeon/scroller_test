#ifdef GL_ES
precision mediump float;
#endif

vec4 FlutterFragCoord() {
    return vec4(gl_FragCoord.xy, 0.0, 0.0);
}

uniform vec2 uSize;
uniform float uOffsetX;
uniform float uOffsetY;
uniform float uScale;
uniform sampler2D uTexture;
uniform vec3 uPrimary;
uniform vec3 uAccent;
uniform vec3 uBackground;

out vec4 fragColor;

const float kBaseSpacing = 25.0;
const float kBaseDotR = 2.0;
const float kAccentMult = 1.8;
const float kAccentEvery = 4.0;


const float kImageWorldRadius = kBaseSpacing * 0.001;
const float kRevealStartPx = 4.0;
const float kRevealFullPx = 30.0;


const float kEdgeSoftStart = 0.70;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 world = (fragCoord - vec2(uOffsetX, uOffsetY)) / uScale;

    float feather = 1.0 / uScale;

    float primaryR = max(kBaseDotR, 0.6 / uScale);
    primaryR *= mix(0.5, 1.0, min(1.3, uScale));
    float accentR = max(kBaseDotR * kAccentMult, 1.0 / uScale);

    float spacing = kBaseSpacing;
    float accentSpacing = kBaseSpacing * kAccentEvery;

    vec2 primCell = mod(world, spacing) - spacing * 0.5;
    vec2 accCell = mod(world, accentSpacing) - accentSpacing * 0.5;

    float primDist  = length(primCell);
    float primAlpha = 1.0 - smoothstep(primaryR - feather, primaryR + feather, primDist);

    float accDist  = length(accCell);
    float accAlpha = 1.0 - smoothstep(accentR - feather, accentR + feather, accDist);

    float scaleVis = clamp(uScale * 1.2, 0.15, 1.0);
    float primOpacity = 0.38 * scaleVis;
    float accOpacity = 0.60;

    float dotAlpha = max(primAlpha * primOpacity, accAlpha * accOpacity);
    vec3  dotColor = mix(uPrimary, uAccent, accAlpha);

    float imageScreenRadius = kImageWorldRadius * uScale;

    float zoomReveal = smoothstep(kRevealStartPx, kRevealFullPx, imageScreenRadius);


    vec2 texUV = primCell / (kImageWorldRadius * 2.0) + 0.5;

    float normDist  = length(primCell) / kImageWorldRadius;
    float edgeMask  = 1.0 - smoothstep(kEdgeSoftStart, 1.0, normDist);

    texUV = clamp(texUV, 0.0, 1.0);
    vec4 texColor = texture(uTexture, texUV);

    float imgAlpha = zoomReveal * edgeMask * texColor.a;

    vec3 color = uBackground;

    float zoomFade = smoothstep(0.15, 1.0, uScale * 10);

    dotAlpha = smoothstep(0.0, 1.0, dotAlpha);
    dotAlpha *= zoomFade;

    color = mix(color, dotColor, dotAlpha);

    color = mix(color, texColor.rgb, imgAlpha);

    fragColor = vec4(color, 1.0);
}
