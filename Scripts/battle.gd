extends Node2D

@onready var board: Board        = $Board
@onready var player_hp: ProgressBar  = $UI/PlayerHP
@onready var player_info: Label      = $UI/PlayerInfo
@onready var charge_bar: ProgressBar = $UI/ChargeBar
@onready var enemy_hp: ProgressBar   = $UI/EnemyHP
@onready var enemy_info: Label       = $UI/EnemyInfo
@onready var log_label: RichTextLabel = $UI/Log
@onready var ult_button: Button      = $UI/UltButton

var combat := Combat.new()
var battle_over := false
var current_enemy_id := "green_slime"

func _ready() -> void:
	# 1. Carrega o inimigo ANTES de qualquer coisa
	var data := EnemyDB.load_enemy(current_enemy_id)
	if data == null:
		push_error("Inimigo não existe: " + current_enemy_id)
		return

	# 2. Configura o combat com os dados do inimigo
	combat.setup_enemy(data)

	# 3. Conecta sinais
	board.cascade_resolved.connect(_on_cascade)
	board.board_settled.connect(_on_board_settled)
	combat.changed.connect(_refresh_ui)
	combat.message.connect(_log)
	ult_button.pressed.connect(_on_ultimate)

	# 4. Ajusta barras
	player_hp.max_value  = combat.player.max_hp
	enemy_hp.max_value   = combat.enemy.max_hp
	charge_bar.max_value = Combat.ULT_COST

	# 5. Atualiza UI
	_refresh_ui()
	_log("[color=#ff8888]Um %s aparece![/color]" % combat.enemy_data.display_name)
	_log("Seu turno. Combine peças para agir.")

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
	if combat.enemy.hp <= 0:
		_end_battle(true)
		return

	await get_tree().create_timer(0.45).timeout
	combat.enemy_take_turn()          # <<< era enemy_attack()

	if combat.player.hp <= 0:
		_end_battle(false)
		return

	await get_tree().create_timer(0.45).timeout
	combat.reset_turn()
	board.enabled = true
	ult_button.disabled = not combat.can_ultimate()
	_log("[color=#88aaff]Seu turno.[/color]")

func _end_battle(victory: bool) -> void:
	battle_over = true
	board.enabled = false
	ult_button.disabled = true
	if victory:
		_log("[color=#88ff88]VITÓRIA![/color]")
	else:
		_log("[color=#ff6666]Você foi derrotado...[/color]")

# ---------------------------------------------------------------- UI

func _on_ultimate() -> void:
	if battle_over or not combat.can_ultimate():
		return
	combat.use_ultimate()
	if combat.enemy.hp <= 0:
		_end_battle(true)

func _refresh_ui() -> void:
	player_hp.value  = combat.player.hp
	enemy_hp.value   = combat.enemy.hp
	charge_bar.value = combat.player.charge

	player_info.text = "HP %d/%d   Escudo %d" % [
		combat.player.hp, combat.player.max_hp, combat.player.shield]

	# <<< usa display_name em vez de current_enemy_id
	enemy_info.text = "%s   HP %d/%d   Armadura %d" % [
		combat.enemy_data.display_name,
		combat.enemy.hp, combat.enemy.max_hp,
		combat.enemy.armor]

	ult_button.disabled = not combat.can_ultimate() or battle_over
	if combat.can_ultimate():
		ult_button.text = "ULTIMATE!"
	else:
		ult_button.text = "ULTIMATE (%d%%)" % int(combat.player.charge)

func _log(text: String) -> void:
	log_label.append_text(text + "\n")
