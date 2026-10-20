extends Node
## Builds and caches SpriteFrames / textures from the asset manifest.

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
