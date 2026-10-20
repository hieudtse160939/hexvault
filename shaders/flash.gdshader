shader_type canvas_item;
// Hit flash: blends sprite colour toward flash_color by `flash` (0..1),
// keeping alpha. `tint` multiplies first (status effects, elites).
//
// Sampling is pixel-art aware: at integer scales it is identical to nearest
// filtering; at fractional scales (HD sprites on a window that is not a
// multiple of their density) texel edges get a one-screen-pixel blend instead
// of uneven pixel widths. Needs the item's texture_filter set to linear to
// blend (SpriteLib.apply does that for HD sprites); with nearest it degrades
// to plain nearest sampling.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// (inlined: the Compatibility renderer cannot pass TEXTURE to a function)
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 box = clamp(fwidth(UV) * size, vec2(1e-5), vec2(1.0));
	vec2 tx = UV * size - 0.5 * box;
	vec2 edge = smoothstep(vec2(1.0) - box, vec2(1.0), fract(tx));
	vec2 snapped = (floor(tx) + 0.5 + edge) / size;
	vec4 c = textureGrad(TEXTURE, snapped, dFdx(UV), dFdy(UV)) * COLOR;
	c.rgb *= tint.rgb;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
