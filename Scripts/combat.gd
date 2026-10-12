class_name Combat
extends RefCounted

signal changed()
signal message(text: String)
signal enemy_damaged(index: int, amount: int)
signal enemy_died(index: int)

const ATK_PER_TILE   := 3
const MAGIC_PER_TILE := 4
const DEF_PER_TILE   := 3
const HEAL_PER_TILE  := 4
const CHARGE_PER_TILE := 7.0
const ULT_COST   := 100.0
const ULT_DAMAGE := 45

var player := {
	"hp": 120, "max_hp": 120,
	"shield": 0,
	"charge": 0.0,
}

# Lista de inimigos. Cada entrada é um dict com estado runtime.
var enemies: Array[Dictionary] = []
var enemy_datas: Array[EnemyData] = []
var target: int = 0

# ---------------------------------------------------------------- setup

func setup_enemies(datas: Array[EnemyData]) -> void:
	enemy_datas = datas
	enemies.clear()
	for d in datas:
		enemies.append({
			"hp": d.max_hp,
			"max_hp": d.max_hp,
			"armor": d.armor,
			"atk": d.base_attack,
			"charging": false,
			"pattern_index": 0,
		})
	target = 0
	changed.emit()

func set_target(i: int) -> void:
	if i >= 0 and i < enemies.size() and enemies[i].hp > 0:
		target = i

func all_enemies_dead() -> bool:
	for e in enemies:
		if e.hp > 0:
			return false
	return true

func reset_turn() -> void:
	player.shield = 0

# ---------------------------------------------------------------- jogador

func apply_tally(tally: Dictionary, cascade: int) -> void:
	if target >= enemies.size() or enemies[target].hp <= 0:
		return

	var mult := 1.0 + 0.25 * float(cascade - 1)
	var parts: Array[String] = []
	var e := enemies[target]      # referência direta ao dict

	var n_atk: int = tally.get(Board.T.ATTACK, 0)
	var n_mag: int = tally.get(Board.T.MAGIC, 0)
	var n_def: int = tally.get(Board.T.DEFENSE, 0)
	var n_hea: int = tally.get(Board.T.HEAL, 0)
	var n_chg: int = tally.get(Board.T.CHARGE, 0)

	if n_atk > 0:
		var per := maxi(1, ATK_PER_TILE - e.armor)
		var dmg := int(round(n_atk * per * mult))
		_damage_enemy(target, dmg)
		parts.append("%d físico" % dmg)

	if n_mag > 0:
		var dmg := int(round(n_mag * MAGIC_PER_TILE * mult))
		_damage_enemy(target, dmg)
		parts.append("%d mágico" % dmg)

	if n_def > 0:
		var sh := int(round(n_def * DEF_PER_TILE * mult))
		player.shield += sh
		parts.append("%d escudo" % sh)

	if n_hea > 0:
		var h := int(round(n_hea * HEAL_PER_TILE * mult))
		player.hp = mini(player.max_hp, player.hp + h)
		parts.append("%d cura" % h)

	if n_chg > 0:
		var c: float = n_chg * CHARGE_PER_TILE * mult
		player.charge = min(ULT_COST, player.charge + c)
		parts.append("+%d%% carga" % int(c))

	var prefix := "" if cascade == 1 else "Combo x%d! " % cascade
	var body := ", ".join(parts) if parts.size() > 0 else "nada"
	message.emit(prefix + body)
	changed.emit()

# ---------------------------------------------------------------- inimigos

func enemy_take_turn() -> void:
	# cada inimigo vivo age
	for i in enemies.size():
		if enemies[i].hp <= 0:
			continue
		_enemy_act(i)

	changed.emit()

func _enemy_act(i: int) -> void:
	var e := enemies[i]
	var d := enemy_datas[i]
	if d.pattern.is_empty():
		return

	var action: String = d.pattern[e.pattern_index]
	e.pattern_index = (e.pattern_index + 1) % d.pattern.size()

	match action:
		"attack":
			_deal_damage_to_player(e.atk)
			message.emit("%s ataca: %d de dano" % [d.display_name, e.atk])

		"defend":
			e.armor += 2
			message.emit("%s se protege (+2 armadura)" % d.display_name)

		"charge":
			e.charging = true
			message.emit("%s está carregando algo..." % d.display_name)

		"breathe":
			var dmg := int(e.atk * d.charge_multiplier)
			_deal_damage_to_player(dmg)
			e.charging = false
			message.emit("%s SOLTA UM ATAQUE PESADO: %d!" % [d.display_name, dmg])

		_:
			_deal_damage_to_player(e.atk)
			message.emit("%s ataca: %d de dano" % [d.display_name, e.atk])

func _damage_enemy(i: int, dmg: int) -> void:
	var e := enemies[i]
	if e.hp <= 0:
		return
	e.hp = maxi(0, e.hp - dmg)
	enemy_damaged.emit(i, dmg)
	if e.hp <= 0:
		enemy_died.emit(i)

func _deal_damage_to_player(dmg: int) -> void:
	var absorbed: int = mini(player.shield, dmg)
	player.shield -= absorbed
	dmg -= absorbed
	player.hp = maxi(0, player.hp - dmg)

# ---------------------------------------------------------------- ultimate

func can_ultimate() -> bool:
	return player.charge >= ULT_COST

func use_ultimate() -> bool:
	if not can_ultimate():
		return false
	player.charge = 0.0
	# Ultimate atinge TODOS os inimigos vivos
	for i in enemies.size():
		if enemies[i].hp > 0:
			_damage_enemy(i, ULT_DAMAGE)
	message.emit("ULTIMATE! %d de dano em todos!" % ULT_DAMAGE)
	changed.emit()
	return true
