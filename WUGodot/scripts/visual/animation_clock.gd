class_name AnimationClock
extends RefCounted

static func resolve(delta: float, time_scale: float) -> Dictionary:
	return {
		"combat": delta * time_scale,
		"presentation": delta,
		"input_active": time_scale > 0.0,
	}
