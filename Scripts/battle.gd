extends Node2D

@onready var board: Board            = $Board
@onready var enemy_row: Node2D       = $EnemyRow
@onready var background: Sprite2D    = $Background
@onready var player_hp: ProgressBar  = $UI/PlayerHP
@onready var player_info: Label      = $UI/PlayerInfo
@onready var charge_bar: ProgressBar = $UI/ChargeBar
@onready var log_label: RichTextLabel = $UI/Log
@onready var ult_button: Button      = $UI/UltButton
@onready var target_label: Label     = $UI/TargetLabel

var combat := Combat.new()
var battle_over := false

var current_zone: ZoneData
var enemy_views: Array[EnemyView] = []
var target_index: int = 0

const ENEMY_SPACING := 130.0

func _ready() -> void:
	board.cascade_resolved.connect(_on_cascade)
	board.board_settled.connect(_on_board_settled)
	combat.changed.connect(_refresh_ui)
	combat.message.connect(_log)
	ult_button.pressed.connect(_on_ultimate)

	player_hp.max_value  = combat.player.max_hp
	charge_bar.max_value = Combat.ULT_COST
	
	var test_zone: ZoneData = load("res://Zones/forest.tres")
	start_encounter(test_zone)

# ---------------------------------------------------------------- entrada

## Chamado pelo overworld OU no _ready pra testar
func start_encounter(zone: ZoneData) -> void:
	current_zone = zone
	battle_over = false
	target_index = 0

	# limpa inimigos antigos
	for v in enemy_views:
		v.queue_free()
	enemy_views.clear()

	# fundo
	_apply_background(zone)

	# sorteia inimigos
	var picked := zone.roll_encounter()
	if picked.is_empty():
		push_error("Zona sem spawns válidos: " + zone.zone_id)
		return

	# monta o combat (o Combat agora aceita Array[EnemyData])
	combat.setup_enemies(picked)

	# cria as views lado a lado, centralizadas
	var n := picked.size()
	var total_w := ENEMY_SPACING * (n - 1)
	var start_x := -total_w * 0.5
	var viewport_center := get_viewport_rect().size.x * 0.5

	for i in n:
		var view := EnemyView.new()
		view.setup(picked[i], i)
		enemy_row.add_child(view)
		view.position = Vector2(viewport_center + start_x + ENEMY_SPACING * i, 0)
		view.clicked.connect(_on_enemy_clicked)
		enemy_views.append(view)

	# conecta o combat às views pra que dano apareça nelas
	combat.enemy_damaged.connect(_on_enemy_damaged)
	combat.enemy_died.connect(_on_enemy_died)

	board.enabled = true
	_select_target(0)

	_refresh_ui()
	_log("[color=#ff8888]Emboscada em %s![/color]" % zone.display_name)
	_log("Seu turno. Combine peças para agir.")

func _apply_background(zone: ZoneData) -> void:
	if zone.background:
		background.texture = zone.background
		var vp := get_viewport_rect().size
		background.scale = Vector2(
			vp.x / background.texture.get_width(),
			vp.y / background.texture.get_height())
	else:
		# fallback: cor sólida via um ColorRect atrás
		var vp := get_viewport_rect().size
		background.texture = null
		RenderingServer.set_default_clear_color(zone.background_color)

# ---------------------------------------------------------------- alvo

func _on_enemy_clicked(index: int) -> void:
	if battle_over:
		return
	_select_target(index)

func _select_target(index: int) -> void:
	if index < 0 or index >= enemy_views.size():
		return
	if enemy_views[index].is_dead:
		return
	target_index = index

	# destaca visualmente
	for i in enemy_views.size():
		var v := enemy_views[i]
		v.scale = Vector2(1.15, 1.15) if i == index else Vector2.ONE

	#target_label.text = "Alvo: %s" % enemy_views[index].data.display_name
	combat.set_target(index)

# ---------------------------------------------------------------- turnos

func _on_cascade(tally: Dictionary, cascade: int) -> void:
	combat.apply_tally(tally, cascade)

func _on_board_settled() -> void:
	if battle_over:
		return
	board.enabled = false
	ult_button.disabled = true
	await _enemy_turn()

func _enemy_turn() -> void:
	if combat.all_enemies_dead():
		_end_battle(true)
		return

	await get_tree().create_timer(0.45).timeout
	combat.enemy_take_turn()

	if combat.player.hp <= 0:
		_end_battle(false)
		return

	# se o alvo morreu, escolhe o próximo vivo
	if enemy_views[target_index].is_dead:
		_auto_select_alive()

	await get_tree().create_timer(0.45).timeout
	combat.reset_turn()
	board.enabled = true
	ult_button.disabled = not combat.can_ultimate()
	_log("[color=#88aaff]Seu turno.[/color]")

func _auto_select_alive() -> void:
	for i in enemy_views.size():
		if not enemy_views[i].is_dead:
			_select_target(i)
			return

func _end_battle(victory: bool) -> void:
	battle_over = true
	board.enabled = false
	ult_button.disabled = true
	if victory:
		_log("[color=#88ff88]VITÓRIA![/color]")
	else:
		_log("[color=#ff6666]Você foi derrotado...[/color]")

# ---------------------------------------------------------------- hooks do combat

func _on_enemy_damaged(index: int, amount: int) -> void:
	if index < enemy_views.size():
		enemy_views[index].take_damage(amount)

func _on_enemy_died(index: int) -> void:
	_log("[color=#ffaa66]Inimigo %d caiu![/color]" % (index + 1))

# ---------------------------------------------------------------- UI

func _on_ultimate() -> void:
	if battle_over or not combat.can_ultimate():
		return
	combat.use_ultimate()
	if combat.all_enemies_dead():
		_end_battle(true)

func _refresh_ui() -> void:
	player_hp.value  = combat.player.hp
	charge_bar.value = combat.player.charge
	player_info.text = "HP %d/%d   Escudo %d" % [
		combat.player.hp, combat.player.max_hp, combat.player.shield]

	ult_button.disabled = not combat.can_ultimate() or battle_over
	if combat.can_ultimate():
		ult_button.text = "ULTIMATE!"
	else:
		ult_button.text = "ULTIMATE (%d%%)" % int(combat.player.charge)

func _log(text: String) -> void:
	log_label.append_text(text + "\n")
