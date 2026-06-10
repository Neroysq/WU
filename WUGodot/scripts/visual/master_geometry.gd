class_name MasterGeometry
extends RefCounted

const ALPHA_THRESHOLD: float = 0.5

static func resolve(img: Image, sidecar: Dictionary) -> Dictionary:
	var native := Vector2(float(img.get_width()), float(img.get_height()))
	var side_native: Vector2 = _vec(sidecar.get("native_size"))
	var bbox: Rect2 = _rect(sidecar.get("bbox"))
	var foot: Vector2 = _vec(sidecar.get("foot_anchor"))

	var native_lies: bool = side_native.distance_to(native) > 1.0
	var bbox_oob: bool = bbox.size.x <= 0.0 or bbox.size.y <= 0.0 \
		or bbox.position.x < -1.0 or bbox.position.y < -1.0 \
		or bbox.position.x + bbox.size.x > native.x + 1.0 \
		or bbox.position.y + bbox.size.y > native.y + 1.0
	var foot_oob: bool = foot.x < -1.0 or foot.y < -1.0 or foot.x > native.x + 1.0 or foot.y > native.y + 1.0

	if not native_lies and not bbox_oob and not foot_oob:
		return {"native": native, "bbox": bbox, "foot": foot, "remeasured": false}

	var measured: Dictionary = _measure_alpha_geometry(img)
	return {
		"native": native,
		"bbox": measured["bbox"] as Rect2,
		"foot": measured["foot"] as Vector2,
		"remeasured": true,
	}

static func _measure_alpha_geometry(img: Image) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var left: int = w
	var right: int = -1
	var top: int = h
	var bottom: int = -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > ALPHA_THRESHOLD:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = maxi(bottom, y)

	if right < 0:
		return {
			"bbox": Rect2(0.0, 0.0, float(w), float(h)),
			"foot": Vector2(float(w) * 0.5, float(h)),
		}

	var foot_left: int = w
	var foot_right: int = -1
	for x in range(w):
		if img.get_pixel(x, bottom).a > ALPHA_THRESHOLD:
			foot_left = mini(foot_left, x)
			foot_right = maxi(foot_right, x)
	if foot_right < 0:
		foot_left = left
		foot_right = right

	return {
		"bbox": Rect2(float(left), float(top), float(right - left + 1), float(bottom - top + 1)),
		"foot": Vector2(float(foot_left + foot_right) * 0.5, float(bottom)),
	}

static func _vec(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return Vector2.ZERO

static func _rect(raw: Variant) -> Rect2:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw as Array
		if arr.size() >= 4:
			return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return Rect2()
