extends Node2D
class_name Tile

const SIZE := 58.0
const COLORS := [
	Color("e04b4b"), # ATTACK 
	Color("4b7be0"), # DEFENSE
	Color("a44be0"), # MAGIC  
	Color("4be08a"), # HEAL   
	Color("e0c24b"), # CHARGE 
]

const GLYPHS := ["A", "D", "M", "H", "C"]

var type: int = 0

func _init(t: int = 0) -> void:
	type = t

func _ready() -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE, SIZE)
	rect.position = -rect.size * 0.5
	rect.color = COLORS[type]
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

	var label := Label.new()
	label.text = GLYPHS[type]
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 0.55))
	label.size = Vector2(SIZE, SIZE)
	label.position = -Vector2(SIZE, SIZE) * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
