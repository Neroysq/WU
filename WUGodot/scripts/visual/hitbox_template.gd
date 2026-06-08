class_name HitboxTemplate
extends RefCounted

static func build(weapon_class: String, chest: Vector2, tip: Vector2, is_heavy: bool, is_grab: bool) -> Dictionary:
	if is_grab:
		var grab_radius: float = 28.0 + (6.0 if is_heavy else 0.0)
		return {"a": tip, "b": tip, "radius": grab_radius}

	var heavy_bonus: float = 6.0 if is_heavy else 0.0
	match weapon_class:
		"spear", "staff":
			return {"a": chest, "b": tip, "radius": 10.0 + heavy_bonus}
		"fan":
			return {"a": chest.lerp(tip, 0.5), "b": tip, "radius": 16.0 + heavy_bonus}
		"unarmed":
			return {"a": chest.lerp(tip, 0.4), "b": tip, "radius": 14.0 + heavy_bonus}
		_:
			return {"a": chest.lerp(tip, 0.35), "b": tip, "radius": 20.0 + heavy_bonus}
