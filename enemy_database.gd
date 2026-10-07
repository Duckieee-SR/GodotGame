class_name EnemyDB
extends RefCounted

# Cada inimigo é um Dictionary. Fácil de ler, fácil de estender.
const DATA := {
	"slime": {
		"name": "Slime Verde",
		"max_hp": 60,
		"armor": 0,
		"atk": 8,
		"color": Color("66cc66"),
		"patterns": ["attack", "attack", "charge"],
	},
	"goblin": {
		"name": "Goblin Ancião",
		"max_hp": 160,
		"armor": 1,
		"atk": 16,
		"color": Color("cc8844"),
		"patterns": ["attack", "attack", "defend", "attack"],
	},
	"dragon": {
		"name": "Dragão Vermelho",
		"max_hp": 400,
		"armor": 3,
		"atk": 32,
		"color": Color("cc4444"),
		"patterns": ["charge", "attack", "attack", "breathe"],
	},
}

static func get_enemy(id: String) -> Dictionary:
	if not DATA.has(id):
		push_error("Inimigo não encontrado: " + id)
		return DATA["slime"]   # fallback
	# duplica pra não mutar o original
	return DATA[id].duplicate(true)

static func all_ids() -> Array:
	return DATA.keys()
