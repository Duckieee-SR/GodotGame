class_name EnemyData
extends Resource

var rng = RandomNumberGenerator.new()
var random_gold_reward = rng.randf_range(gold_reward_min, 10.0)

@export var display_name: String = "Novo Inimigo"
@export var sprite: Texture2D
@export var color: Color = Color.WHITE

@export_group("Stats")
@export var max_hp: int = 100
@export var armor: int = 0
@export var base_attack: int = 10

@export_group("Comportamento")
## Ciclo de ações. Ações válidas: attack, defend, charge, breathe
@export var pattern: PackedStringArray = ["attack", "attack"]

@export_group("Recompensas")
@export var gold_reward_min: float = 1
@export var gold_reward_max: float = 10
@export var xp_reward: int = 5
var gold_reward = rng.randf_range(gold_reward_min, gold_reward_max)

## Multiplicador de dano aplicado quando o inimigo está "charging"
@export var charge_multiplier: float = 2.0
