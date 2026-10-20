extends Node
## Builds and caches SpriteFrames / textures from the asset manifest.
##
## Pixel density: every manifest entry may carry "density" = art pixels per
## world unit (1 for the original 16 px art, 4 for HD art). World code always
## works in world units; use apply() to put a sprite on a node at the right
## size, and the *_world() helpers for offsets measured on the art.

var _frames: Dictionary = {}   # key -> SpriteFrames
var _textures: Dictionary = {} # key -> Texture2D
var _font: Font = null


func frames(key: String) -> SpriteFrames:
	if _frames.has(key):
		return _frames[key]
	var entry: Variant = SpriteManifest.sprites().get(key, null)
	var sf: SpriteFrames = SpriteFrames.new()
	if entry is Dictionary:
		var e: Dictionary = entry
		var tex: Texture2D = load(str(e["path"])) as Texture2D
		var fw: int = int(e["frame_w"])
		var fh: int = int(e["frame_h"])
		if sf.has_animation(&"default"):
			sf.remove_animation(&"default")
		var anims: Dictionary = e["anims"]
		for anim_name: String in anims:
			var a: Dictionary = anims[anim_name]
			sf.add_animation(anim_name)
			sf.set_animation_speed(anim_name, float(a.get("fps", 8)))
			sf.set_animation_loop(anim_name, bool(a.get("loop", false)))
			var row: int = int(a["row"])
			for i: int in int(a["frames"]):
				var at: AtlasTexture = AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * fw, row * fh, fw, fh)
				sf.add_frame(anim_name, at)
	else:
		push_warning("SpriteLib: unknown sprite '%s'" % key)
	_frames[key] = sf
	return sf


## Art pixels per world unit for a sprite or image key (1 when unspecified).
func density(key: String) -> float:
	var entry: Variant = SpriteManifest.sprites().get(key, SpriteManifest.images().get(key, null))
	if entry is Dictionary:
		return maxf(float((entry as Dictionary).get("density", 1.0)), 0.01)
	return 1.0


func is_hd(key: String) -> bool:
	return density(key) > 1.0


## Puts the sprite `key` on an AnimatedSprite2D (frames) or Sprite2D (first
## frame / image) and sizes it to world units. HD art also gets linear
## filtering + the pixel-aware shader so fractional window scales stay clean.
## `scale_mul` multiplies the density scale (elite size-ups, pulsing FX...).
func apply(node: Node2D, key: String, scale_mul: float = 1.0) -> void:
	if node is AnimatedSprite2D:
		(node as AnimatedSprite2D).sprite_frames = frames(key)
	elif node is Sprite2D:
		(node as Sprite2D).texture = texture(key) if SpriteManifest.has_image(key) else still(key)
	node.scale = Vector2.ONE * (scale_mul / density(key))
	if is_hd(key):
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if node.material == null:
			FX.make_flashable(node)
	else:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE


## Frame size in world units.
func frame_size_world(key: String) -> Vector2:
	return Vector2(frame_size(key)) / density(key)


## Pivot in world units.
func pivot_world(key: String) -> Vector2:
	return pivot(key) / density(key)


func frame_size(key: String) -> Vector2i:
	var entry: Variant = SpriteManifest.sprites().get(key, null)
	if entry is Dictionary:
		return Vector2i(int(entry["frame_w"]), int(entry["frame_h"]))
	return Vector2i(16, 16)


func pivot(key: String) -> Vector2:
	var entry: Variant = SpriteManifest.sprites().get(key, null)
	if entry is Dictionary and (entry as Dictionary).has("pivot"):
		var p: Array = entry["pivot"]
		return Vector2(float(p[0]), float(p[1]))
	return Vector2.ZERO


## First frame of a sprite's first animation (for icons / previews).
func still(key: String, anim: String = "") -> Texture2D:
	var sf: SpriteFrames = frames(key)
	var names: PackedStringArray = sf.get_animation_names()
	if names.is_empty():
		return null
	var a: StringName = StringName(anim) if anim != "" and sf.has_animation(anim) else StringName(names[0])
	return sf.get_frame_texture(a, 0)


func texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var entry: Variant = SpriteManifest.images().get(key, null)
	var tex: Texture2D = null
	if entry is Dictionary:
		tex = load(str(entry["path"])) as Texture2D
	elif SpriteManifest.has_sprite(key):
		tex = still(key)
	else:
		push_warning("SpriteLib: unknown image '%s'" % key)
	_textures[key] = tex
	return tex


func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/hexvault.fnt") as Font
	return _font
