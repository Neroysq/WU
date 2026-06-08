class_name AnchorMath
extends RefCounted

static func pose_to_world(px: Vector2, foot_anchor: Vector2, root: Vector2, scale: float, facing: int) -> Vector2:
	var local: Vector2 = (px - foot_anchor) * scale
	if facing < 0:
		local.x = -local.x
	return root + local
