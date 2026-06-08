class_name CollisionShapeMath
extends RefCounted

static func capsule_intersects_rect(a: Vector2, b: Vector2, radius: float, rect: Rect2) -> bool:
	return segment_rect_distance(a, b, rect) <= maxf(radius, 0.0)

static func point_in_rect(p: Vector2, rect: Rect2) -> bool:
	return p.x >= rect.position.x and p.x <= rect.position.x + rect.size.x \
		and p.y >= rect.position.y and p.y <= rect.position.y + rect.size.y

static func segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if point_in_rect(a, rect) or point_in_rect(b, rect):
		return 0.0

	var tl: Vector2 = rect.position
	var tr: Vector2 = Vector2(rect.position.x + rect.size.x, rect.position.y)
	var br: Vector2 = rect.position + rect.size
	var bl: Vector2 = Vector2(rect.position.x, rect.position.y + rect.size.y)

	if _segments_intersect(a, b, tl, tr) or _segments_intersect(a, b, tr, br) \
			or _segments_intersect(a, b, br, bl) or _segments_intersect(a, b, bl, tl):
		return 0.0

	var d: float = minf(_point_rect_distance(a, rect), _point_rect_distance(b, rect))
	for corner in [tl, tr, br, bl]:
		d = minf(d, _point_segment_distance(corner, a, b))
	return d

static func _point_rect_distance(p: Vector2, rect: Rect2) -> float:
	var dx: float = maxf(maxf(rect.position.x - p.x, p.x - (rect.position.x + rect.size.x)), 0.0)
	var dy: float = maxf(maxf(rect.position.y - p.y, p.y - (rect.position.y + rect.size.y)), 0.0)
	return Vector2(dx, dy).length()

static func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1: float = _orient(p3, p4, p1)
	var d2: float = _orient(p3, p4, p2)
	var d3: float = _orient(p1, p2, p3)
	var d4: float = _orient(p1, p2, p4)
	if ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) \
			and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0)):
		return true
	return false

static func _orient(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
