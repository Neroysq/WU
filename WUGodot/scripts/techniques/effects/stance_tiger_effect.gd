extends "res://scripts/techniques/technique_effect.gd"

const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

var _timer: float = 0.0

func _init() -> void:
	id = "D2"
	exclusive_group = "stance"
	priority = 20

func on_stance_activate(_fighter: Variant) -> void:
	if _timer <= 0.0:
		_timer = float(params.get("duration", 15.0))

func on_stance_deactivate(_fighter: Variant) -> void:
	_timer = 0.0

func update(dt: float, fighter: Variant) -> void:
	if _timer > 0.0:
		_timer = maxf(_timer - dt, 0.0)

func is_expired() -> bool:
	return _timer <= 0.0

func attack_override(is_heavy: bool) -> Variant:
	return AttackCatalogScript.tiger_heavy() if is_heavy else AttackCatalogScript.tiger_light()

func should_auto_chain_light(def: Variant) -> bool:
	return def != null and def.id == "tiger_light"

func modify_block(ctx: Variant) -> void:
	if ctx.defender == null or ctx.defender.technique_engine == null:
		return
	if ctx.defender.technique_engine.active_stance() != id:
		return
	ctx.reflect_to_attacker += ctx.base_hp_damage * float(params.get("reflect", 0.10))

func state() -> Dictionary:
	return {"timer": _timer}

func restore(data: Dictionary) -> void:
	_timer = float(data.get("timer", 0.0))
