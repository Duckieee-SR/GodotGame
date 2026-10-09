extends Node2D
class_name Board

signal cascade_resolved(tally: Dictionary, cascade_index: int)
signal board_settled()

enum T { ATTACK, DEFENSE, MAGIC, HEAL, CHARGE }

const TYPE_COUNT := 5
const COLS := 12
const ROWS := 6
const TILE_SIZE := 64.0
const SWAP_TIME := 0.15
const FALL_TIME := 0.16

var grid: Array = []      # grid[y][x] -> int (T) ou -1
var nodes: Array = []     # nodes[y][x] -> Tile ou null
var input_locked := false
var enabled := true       # controlado pela batalha (turno do inimigo)
var selected := Vector2i(-1, -1)

func _ready() -> void:
	randomize()
	_build_grid()
	_clear_initial_matches()
	_spawn_all()
	
func _make_bar(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = size
	bar.show_percentage = false

	# fundo
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)

	# preenchimento
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)

	parent.add_child(bar)
	return bar

# ---------------------------------------------------------------- setup

func _build_grid() -> void:
	grid.clear()
	nodes.clear()
	for y in ROWS:
		var row: Array = []
		var nrow: Array = []
		for x in COLS:
			row.append(randi() % TYPE_COUNT)
			nrow.append(null)
		grid.append(row)
		nodes.append(nrow)

func _clear_initial_matches() -> void:
	for _i in 200:
		var m := find_matches()
		if m.is_empty():
			return
		for pos in m.keys():
			grid[pos.y][pos.x] = randi() % TYPE_COUNT

func _spawn_all() -> void:
	for y in ROWS:
		for x in COLS:
			nodes[y][x] = _spawn_tile(grid[y][x], Vector2i(x, y))

func _spawn_tile(t: int, cell: Vector2i) -> Tile:
	var node := Tile.new(t)
	add_child(node)
	node.position = _cell_to_pos(cell)
	return node

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if input_locked or not enabled:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_from_global(event.position)
		if cell.x < 0:
			return
		if selected.x < 0:
			selected = cell
			_highlight(cell, true)
		elif cell == selected:
			_highlight(cell, false)
			selected = Vector2i(-1, -1)
		elif _is_adjacent(selected, cell):
			var a := selected
			_highlight(a, false)
			selected = Vector2i(-1, -1)
			try_swap(a, cell)
		else:
			_highlight(selected, false)
			selected = cell
			_highlight(cell, true)

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

func _highlight(cell: Vector2i, on: bool) -> void:
	var n: Tile = nodes[cell.y][cell.x]
	if n == null:
		return
	n.scale = Vector2(1.12, 1.12) if on else Vector2.ONE

# ---------------------------------------------------------------- troca

func try_swap(a: Vector2i, b: Vector2i) -> void:
	input_locked = true
	_swap_data(a, b)
	await _animate_swap(a, b)

	if find_matches().is_empty():
		_swap_data(a, b)          # desfaz
		await _animate_swap(a, b)
		input_locked = false
		return

	await _resolve_board()
	input_locked = false
	board_settled.emit()

func _swap_data(a: Vector2i, b: Vector2i) -> void:
	var t = grid[a.y][a.x];  grid[a.y][a.x]  = grid[b.y][b.x];  grid[b.y][b.x]  = t
	var n = nodes[a.y][a.x]; nodes[a.y][a.x] = nodes[b.y][b.x]; nodes[b.y][b.x] = n

func _animate_swap(a: Vector2i, b: Vector2i) -> void:
	var na: Tile = nodes[a.y][a.x]
	var nb: Tile = nodes[b.y][b.x]
	var ta := create_tween().set_parallel()
	var tb := create_tween().set_parallel()
	if na: ta.tween_property(na, "position", _cell_to_pos(a), SWAP_TIME)
	if nb: tb.tween_property(nb, "position", _cell_to_pos(b), SWAP_TIME)
	await get_tree().create_timer(SWAP_TIME).timeout

# ---------------------------------------------------------------- matches

func find_matches() -> Dictionary:
	var matched := {}

	# horizontal
	for y in ROWS:
		var start := 0
		for x in range(1, COLS + 1):
			var same : bool = x < COLS and grid[y][x] != -1 and grid[y][x] == grid[y][start]
			if same:
				continue
			if x - start >= 3:
				for i in range(start, x):
					matched[Vector2i(i, y)] = true
			start = x

	# vertical
	for x in COLS:
		var start := 0
		for y in range(1, ROWS + 1):
			var same : bool = y < ROWS and grid[y][x] != -1 and grid[y][x] == grid[start][x]
			if same:
				continue
			if y - start >= 3:
				for i in range(start, y):
					matched[Vector2i(x, i)] = true
			start = y

	return matched

# ---------------------------------------------------------------- cascatas

func _resolve_board() -> void:
	var cascade := 0
	while true:
		var matches := find_matches()
		if matches.is_empty():
			return
		cascade += 1

		var tally := _tally(matches)
		for pos in matches.keys():
			_remove_tile(pos)

		cascade_resolved.emit(tally, cascade)
		await get_tree().create_timer(0.10).timeout

		await _apply_gravity_and_refill()

func _tally(matches: Dictionary) -> Dictionary:
	var t := {}
	for pos in matches.keys():
		var kind: int = grid[pos.y][pos.x]
		t[kind] = t.get(kind, 0) + 1
	return t

func _remove_tile(pos: Vector2i) -> void:
	var n: Tile = nodes[pos.y][pos.x]
	if n:
		var tw := create_tween().set_parallel()
		tw.tween_property(n, "scale", Vector2.ZERO, 0.10)
		tw.tween_property(n, "modulate:a", 0.0, 0.10)
		tw.chain().tween_callback(n.queue_free)
	nodes[pos.y][pos.x] = null
	grid[pos.y][pos.x] = -1

func _apply_gravity_and_refill() -> void:
	var tweens: Array[Tween] = []

	for x in COLS:
		var write_y := ROWS - 1
		# desce peças existentes
		for y in range(ROWS - 1, -1, -1):
			if grid[y][x] == -1:
				continue
			if write_y != y:
				grid[write_y][x] = grid[y][x]
				nodes[write_y][x] = nodes[y][x]
				grid[y][x] = -1
				nodes[y][x] = null
				tweens.append(_tween_to(nodes[write_y][x], Vector2i(x, write_y)))
			write_y -= 1

		# spawna novas acima do tabuleiro
		for y in range(write_y, -1, -1):
			var t := randi() % TYPE_COUNT
			grid[y][x] = t
			var node := _spawn_tile(t, Vector2i(x, y - write_y - 1))
			nodes[y][x] = node
			tweens.append(_tween_to(node, Vector2i(x, y)))

	for tw in tweens:
		await tw.finished
	await get_tree().create_timer(0.03).timeout

# ---------------------------------------------------------------- helpers

func _tween_to(node: Node2D, cell: Vector2i) -> Tween:
	if node == null:
		return create_tween()
	var tw := create_tween()
	tw.tween_property(node, "position", _cell_to_pos(cell), FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw

func _cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5,
				   cell.y * TILE_SIZE + TILE_SIZE * 0.5)

func _cell_from_global(gp: Vector2) -> Vector2i:
	var local := to_local(gp)
	var x := int(floor(local.x / TILE_SIZE))
	var y := int(floor(local.y / TILE_SIZE))
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)
