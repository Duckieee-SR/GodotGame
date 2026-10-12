class_name EnemyView
extends Node2D

signal clicked(index: int)

const BAR_WIDTH := 70.0
const BAR_HEIGHT := 6.0
const BAR_OFFSET_Y := 52.0   # abaixo do sprite

var index: int = 0
var data: EnemyData
var hp: int = 0
var max_hp: int = 0
var is_dead := false

var _sprite: Sprite2D
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _name_label: Label
var _hp_label: Label
var _click_area: Area2D

func setup(p_data: EnemyData, p_index: int) -> void:
	data = p_data
	index = p_index
	max_hp = p_data.max_hp
	hp = max_hp

func _ready() -> void:
	# --- sprite ---
	_sprite = Sprite2D.new()
	if data and data.sprite:
		_sprite.texture = data.sprite
	else:
		# fallback: retângulo colorido do EnemyData
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(data.color if data else Color.WHITE)
		_sprite.texture = ImageTexture.create_from_image(img)
	add_child(_sprite)

	# --- barra de fundo ---
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.1, 0.1, 0.12, 0.9)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.position = Vector2(-BAR_WIDTH * 0.5, BAR_OFFSET_Y)
	add_child(_bar_bg)

	# --- barra de preenchimento ---
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("e04b4b")
	_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_fill.position = _bar_bg.position
	add_child(_bar_fill)

	# --- nome ---
	_name_label = Label.new()
	_name_label.text = data.display_name if data else "?"
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.size = Vector2(120, 14)
	_name_label.position = Vector2(-60, BAR_OFFSET_Y + BAR_HEIGHT + 2)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	# --- HP texto ---
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.size = Vector2(120, 12)
	_hp_label.position = Vector2(-60, BAR_OFFSET_Y - 14)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hp_label)

	# --- área clicável ---
	_click_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 56)
	col.shape = shape
	_click_area.add_child(col)
	_click_area.input_pickable = true
	add_child(_click_area)
	_click_area.input_event.connect(_on_input)

	_refresh()

func _on_input(_viewport, event: InputEvent, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_dead:
			clicked.emit(index)

# ---------------------------------------------------------------- API

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	_refresh()
	_flash()
	if hp <= 0:
		_die()

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	_refresh()

func _refresh() -> void:
	var ratio := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	_bar_fill.size.x = BAR_WIDTH * ratio
	_hp_label.text = "%d/%d" % [hp, max_hp]

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(3, 3, 3), 0.06)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)

func _die() -> void:
	is_dead = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.4)
