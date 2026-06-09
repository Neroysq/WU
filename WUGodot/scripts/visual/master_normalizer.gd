class_name MasterNormalizer
extends RefCounted

static func base_scale(reference_character_px: float, target_texels: int, density: int) -> float:
	if reference_character_px <= 0.0 or target_texels <= 0 or density <= 0:
		return 0.0
	return (float(target_texels) * float(density)) / reference_character_px

static func plan(base: float, native_size: Vector2, bbox: Rect2, foot_anchor: Vector2, scale_norm: float = 1.0) -> Dictionary:
	var scale: float = base * scale_norm
	return {
		"scale": scale,
		"scaled_size": native_size * scale,
		"scaled_bbox": Rect2(bbox.position * scale, bbox.size * scale),
		"scaled_foot": foot_anchor * scale,
	}
