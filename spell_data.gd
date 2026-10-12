class_name SpellData
extends Resource

enum Target { ENEMY_SINGLE, ENEMY_ALL, SELF }

@export var id: String = "fireball"
@export var display_name: String = "Bola de Fogo"
@export var description: String = "Dano em um alvo"
@export var icon: Texture2D

@export_group("Custo")
@export var mana_cost: int = 10
@export var hp_cost: int = 0                  # magia de sangue paga vida

@export_group("Requisitos de Match")
## Tipo de tile que precisa estar no match (Board.T)
@export var required_tile: int = 0
## Mínimo de tiles desse tipo no match
@export var required_count: int = 3
## Bônus por tile extra acima do requerido (ex: 0.10 = +10%)
@export var bonus_per_extra: float = 0.0

@export_group("Efeito")
@export var target_type: Target = Target.ENEMY_SINGLE
@export var base_damage: int = 15
@export var base_heal: int = 0
@export var base_shield: int = 0
## Aplica burn por N turnos (0 = não aplica)
@export var apply_burn: int = 0

# ---------------------------------------------------------------- util

## Dado um match (Dictionary tipo_tile -> count), retorna {valid: bool, damage: int, ...}
func evaluate(match_tally: Dictionary, player_has_mana: bool) -> Dictionary:
	var have := int(match_tally.get(required_tile, 0))
	if have < required_count:
		return {"valid": false, "reason": "poucos tiles"}
	if not player_has_mana:
		return {"valid": false, "reason": "mana insuficiente"}

	var extras := have - required_count
	var mult := 1.0 + bonus_per_extra * extras

	return {
		"valid": true,
		"multiplier": mult,
		"damage": int(round(base_damage * mult)),
		"heal":   int(round(base_heal   * mult)),
		"shield": int(round(base_shield * mult)),
		"extras": extras,
	}
