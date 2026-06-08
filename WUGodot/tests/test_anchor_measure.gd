extends RefCounted

const AnchorMeasureScript = preload("res://scripts/visual/anchor_measure.gd")

func _make_image() -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var solid := Color(1, 1, 1, 1)
	for y in range(40, 200):
		for x in range(100, 150):
			img.set_pixel(x, y, solid)
	for y in range(119, 122):
		for x in range(150, 210):
			img.set_pixel(x, y, solid)
	img.set_pixel(0, 255, solid)
	img.set_pixel(255, 5, solid)
	return img

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var m: Dictionary = AnchorMeasureScript.measure(_make_image())

	var foot: Vector2 = m["footAnchor"] as Vector2
	if foot.y == 199 and absf(foot.x - 124.5) <= 2.0:
		passed += 1
	else:
		failed += 1
		failures.append("footAnchor should be body bottom-center, got %s" % str(foot))

	var hb: Rect2 = m["hurtbox"] as Rect2
	if hb.position.x + hb.size.x <= 152.0 and hb.size.x >= 40.0 and hb.size.x <= 60.0:
		passed += 1
	else:
		failed += 1
		failures.append("hurtbox must exclude the blade, got %s" % str(hb))

	var tip: Vector2 = m["weaponTip"] as Vector2
	if tip.x == 209 and absf(tip.y - 120.0) <= 2.0:
		passed += 1
	else:
		failed += 1
		failures.append("weaponTip should be the blade end, not a speck, got %s" % str(tip))

	var chest: Vector2 = m["chestAnchor"] as Vector2
	if chest.x >= 100 and chest.x <= 150 and chest.y > 40 and chest.y < 199:
		passed += 1
	else:
		failed += 1
		failures.append("chestAnchor should sit in the body, got %s" % str(chest))

	var empty := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	empty.fill(Color(0, 0, 0, 0))
	if AnchorMeasureScript.measure(empty).has("footAnchor"):
		passed += 1
	else:
		failed += 1
		failures.append("empty image should still return a footAnchor")

	return {"passed": passed, "failed": failed, "failures": failures}
