extends "res://scripts/techniques/technique_effect.gd"

func _init() -> void:
	id = "A2"

func roll_stagger(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < float(params.get("chance", 0.2))
