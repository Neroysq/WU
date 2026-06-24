extends "res://scripts/techniques/technique_effect.gd"

func on_dash_through(_fighter: Variant, _enemy: Variant = null) -> Dictionary:
	return {
		"posture_damage": float(params.get("posture", 18.0)),
		"momentum_gain": float(params.get("momentum", 15.0)),
		"message": str(params.get("message", "風!")),
	}
