class_name PaletteColors
extends RefCounted
## Named colours from the master palette (mirrors tools/artgen/px.py PAL).

const COLORS: Dictionary = {
	"ink": "#14101e", "night": "#2a2140", "dusk": "#3d3159", "white": "#f4f1ff",
	"stone2": "#9393b5", "stone3": "#c4c4dc",
	"teal2": "#4fe0d0", "teal3": "#b4fff0", "amber2": "#f2b23a", "amber3": "#ffe28a",
	"red2": "#e8455a", "red3": "#ff9aa2", "moss2": "#7dc94a", "vio2": "#a965ef",
	"vio3": "#e3b8ff", "blue2": "#6fb0ff",
}


static func get_color(name: String) -> Color:
	return Color(str(COLORS.get(name, "#f4f1ff")))
