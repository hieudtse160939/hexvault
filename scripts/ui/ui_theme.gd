class_name UiTheme
extends RefCounted
## Builds the shared pixel UI theme in code (font, panels, buttons, sliders).

const INK: Color = Color("#14101e")
const NIGHT: Color = Color("#2a2140")
const DUSK: Color = Color("#3d3159")
const STONE: Color = Color("#6b6b8f")
const TEXT: Color = Color("#f4f1ff")
const DIM: Color = Color("#9393b5")
const ACCENT: Color = Color("#4fe0d0")
const GOLD: Color = Color("#f2b23a")
const RED: Color = Color("#e8455a")
const GREEN: Color = Color("#7dc94a")

const WOOD: Color = Color("#2a1c16")
const BRASS: Color = Color("#c8963e")

static var _theme: Theme = null


## Adventurers' Guild frame: dark varnished wood with a brass border.
static func guild_box(border_w: int = 1, pad: int = 3) -> StyleBoxFlat:
	var s: StyleBoxFlat = box(Color(WOOD, 0.95), BRASS, border_w, pad)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 0
	s.shadow_offset = Vector2(2, 2)
	return s


static func box(bg: Color, border: Color, border_w: int = 1, pad: int = 3) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	var f: Font = load("res://assets/fonts/hexvault.fnt") as Font
	t.default_font = f
	t.default_font_size = 8
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_stylebox("normal", "Button", box(NIGHT, STONE))
	t.set_stylebox("hover", "Button", box(DUSK, ACCENT))
	t.set_stylebox("pressed", "Button", box(INK, GOLD))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT))
	t.set_stylebox("disabled", "Button", box(Color(NIGHT, 0.6), Color(STONE, 0.5)))
	t.set_stylebox("panel", "Panel", box(Color(INK, 0.92), STONE, 1, 4))
	t.set_stylebox("panel", "PanelContainer", box(Color(INK, 0.92), STONE, 1, 4))
	t.set_stylebox("slider", "HSlider", box(NIGHT, STONE, 1, 1))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, ACCENT, 0, 1))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, GOLD, 0, 1))
	var grab: ImageTexture = _square_texture(5, ACCENT)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", _square_texture(5, GOLD))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", ACCENT)
	t.set_color("font_focus_color", "CheckBox", ACCENT)
	t.set_stylebox("normal", "CheckBox", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 1))
	t.set_stylebox("hover", "CheckBox", box(Color(DUSK, 0.6), Color(0, 0, 0, 0), 0, 1))
	t.set_stylebox("focus", "CheckBox", box(Color(0, 0, 0, 0), ACCENT, 1, 1))
	t.set_stylebox("pressed", "CheckBox", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 1))
	t.set_icon("checked", "CheckBox", _check_texture(true))
	t.set_icon("unchecked", "CheckBox", _check_texture(false))
	t.set_stylebox("normal", "LineEdit", box(INK, STONE))
	t.set_stylebox("focus", "LineEdit", box(INK, ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("background", "ProgressBar", box(INK, STONE, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(RED, RED, 0, 0))
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_stylebox("panel", "TooltipPanel", box(INK, ACCENT))
	t.set_stylebox("scroll", "VScrollBar", box(INK, INK, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(STONE, STONE, 0, 1))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT, ACCENT, 0, 1))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, GOLD, 0, 1))
	_theme = t
	return t


static func _square_texture(size: int, c: Color) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


static func _check_texture(on: bool) -> ImageTexture:
	var img: Image = Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i: int in 7:
		img.set_pixel(i, 0, STONE); img.set_pixel(i, 6, STONE)
		img.set_pixel(0, i, STONE); img.set_pixel(6, i, STONE)
	if on:
		for y: int in range(2, 5):
			for x: int in range(2, 5):
				img.set_pixel(x, y, ACCENT)
	return ImageTexture.create_from_image(img)


## A label with the pixel font, optional colour and outline for world-space readability.
static func label(text: String, color: Color = TEXT, outline: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	# Explicit font + size: world-space labels do not inherit the UI theme.
	l.add_theme_font_override("font", load("res://assets/fonts/hexvault.fnt") as Font)
	l.add_theme_font_size_override("font_size", 8)
	if outline:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", 2)
	return l


static func button(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		on_press.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move", -6.0))
	return b
