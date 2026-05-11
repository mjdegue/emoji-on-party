shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.49, 0.36, 0.99, 1.0);
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed : hint_range(0.1, 3.0) = 0.6;
uniform float width : hint_range(0.05, 0.5) = 0.15;

void fragment() {
	float t = fract(TIME * speed);
	float pos = t * (1.0 + width * 2.0) - width;
	float dist = abs(UV.x - pos);
	float shimmer = smoothstep(width, 0.0, dist);
	vec4 tex = texture(TEXTURE, UV);
	vec4 tinted = vec4(mix(base_color.rgb, shimmer_color.rgb, shimmer), tex.a);
	COLOR = tinted;
}
