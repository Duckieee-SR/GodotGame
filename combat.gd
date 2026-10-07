class_name Combat
extends RefCounted

signal changed()
signal message(text: String)

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

var enemy := {
	"name": "Goblin Ancião",
	"hp": 160, "max_hp": 160,
	"armor": 1,      # reduz dano físico POR peça
	"atk": 16,
}

func reset_turn() -> void:
	player.shield = 0

# Aplica o resultado de UMA cascata
func apply_tally(tally: Dictionary, cascade: int) -> void:
	var mult := 1.0 + 0.25 * float(cascade - 1)
	var parts: Array[String] = []

	var n_atk: int = tally.get(Board.T.ATTACK, 0)
	var n_mag: int = tally.get(Board.T.MAGIC, 0)
	var n_def: int = tally.get(Board.T.DEFENSE, 0)
	var n_hea: int = tally.get(Board.T.HEAL, 0)
	var n_chg: int = tally.get(Board.T.CHARGE, 0)

	if n_atk > 0:
		var per := maxi(1, ATK_PER_TILE - enemy.armor)
		var dmg := int(round(n_atk * per * mult))
		enemy.hp = maxi(0, enemy.hp - dmg)
		parts.append("%d físico" % dmg)

	if n_mag > 0:
		var dmg := int(round(n_mag * MAGIC_PER_TILE * mult))   # ignora armadura
		enemy.hp = maxi(0, enemy.hp - dmg)
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

func enemy_attack() -> void:
	var dmg: int = enemy.atk
	var absorbed: int = mini(player.shield, dmg)
	player.shield -= absorbed
	dmg -= absorbed
	player.hp = maxi(0, player.hp - dmg)

	var txt := "%s ataca: %d de dano" % [enemy.name, dmg]
	if absorbed > 0:
		txt += " (%d absorvido)" % absorbed
	message.emit(txt)
	changed.emit()

func can_ultimate() -> bool:
	return player.charge >= ULT_COST

func use_ultimate() -> bool:
	if not can_ultimate():
		return false
	player.charge = 0.0
	enemy.hp = maxi(0, enemy.hp - ULT_DAMAGE)
	message.emit("ULTIMATE! %d de dano puro!" % ULT_DAMAGE)
	changed.emit()
	return true
