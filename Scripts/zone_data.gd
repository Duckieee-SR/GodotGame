class_name ZoneData
extends Resource

@export var zone_id: String = "floresta"
@export var display_name: String = "Floresta Sombria"

@export_group("Visual")
@export var background: Texture2D
@export var background_color: Color = Color("2a3040")
@export var bgm: AudioStream

@export_group("Encontros")
## Quantos inimigos no máximo nessa zona (1 a 5)
@export_range(1, 5) var max_enemies: int = 3
## Peso pra sair 1, 2, 3... inimigos (índice 0 = 1 inimigo)
@export var count_weights: PackedFloat32Array = [50.0, 35.0, 15.0]
## Quem pode aparecer aqui
@export var spawns: Array[SpawnEntry] = []

# ---------------------------------------------------------------- sorteio

## Escolhe N inimigos respeitando os pesos. Retorna Array[EnemyData].
func roll_encounter() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	if spawns.is_empty():
		return result

	# 1. Quantos inimigos?
	var n := _roll_count()

	# 2. Cada inimigo é sorteado independente (pode repetir)
	for i in n:
		var entry := _weighted_pick()
		if entry and entry.enemy:
			result.append(entry.enemy)

	return result

func _roll_count() -> int:
	var total := 0.0
	for w in count_weights:
		total += w
	if total <= 0.0:
		return 1

	var r := randf() * total
	var acc := 0.0
	for i in count_weights.size():
		acc += count_weights[i]
		if r <= acc:
			return mini(i + 1, max_enemies)
	return mini(count_weights.size(), max_enemies)

func _weighted_pick() -> SpawnEntry:
	var total := 0.0
	for s in spawns:
		if s and s.enemy:
			total += s.weight
	if total <= 0.0:
		return null

	var r := randf() * total
	var acc := 0.0
	for s in spawns:
		if s == null or s.enemy == null:
			continue
		acc += s.weight
		if r <= acc:
			return s
	return null

## Debug: quantas chances cada inimigo tem (%)
func spawn_chances() -> Dictionary:
	var total := 0.0
	for s in spawns:
		if s and s.enemy:
			total += s.weight
	var out := {}
	for s in spawns:
		if s and s.enemy:
			out[s.enemy.display_name] = (s.weight / total) * 100.0 if total > 0 else 0.0
	return out
