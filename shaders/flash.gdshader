shader_type canvas_item;
// Hit flash: blends sprite colour toward flash_color by `flash` (0..1),
// keeping alpha. `tint` multiplies first (status effects, elites).

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb *= tint.rgb;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
