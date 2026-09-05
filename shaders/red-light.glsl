#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 source = texture(tex, v_texcoord);
    float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Preserve perceived brightness while strongly suppressing the green and
    // blue channels. The small residual channels retain useful tonal detail.
    vec3 redLight = vec3(luminance, luminance * 0.035, luminance * 0.015);
    fragColor = vec4(redLight, source.a);
}
