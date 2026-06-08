class_name AnchorMeasure
extends RefCounted

const ALPHA_MIN: float = 0.05
const TIP_MIN_RUN: int = 2

static func measure(img: Image) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()

	var op := PackedByteArray()
	op.resize(w * h)
	for y in range(h):
		for x in range(w):
			op[y * w + x] = 1 if img.get_pixel(x, y).a > ALPHA_MIN else 0

	var lbl := PackedInt32Array()
	lbl.resize(w * h)
	lbl.fill(-1)
	var best_pixels := PackedInt32Array()
	var cur: int = 0
	for s in range(w * h):
		if op[s] == 1 and lbl[s] == -1:
			var stack: Array = [s]
			var pixels := PackedInt32Array()
			lbl[s] = cur
			while not stack.is_empty():
				var p: int = stack.pop_back()
				pixels.append(p)
				var px: int = p % w
				var py: int = p / w
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = px + int(d[0])
					var ny: int = py + int(d[1])
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						var np: int = ny * w + nx
						if op[np] == 1 and lbl[np] == -1:
							lbl[np] = cur
							stack.append(np)
			if pixels.size() > best_pixels.size():
				best_pixels = pixels
			cur += 1

	if best_pixels.is_empty():
		var cx: float = float(w) * 0.5
		return {
			"footAnchor": Vector2(cx, float(h - 1)),
			"weaponTip": Vector2(cx, float(h) * 0.5),
			"chestAnchor": Vector2(cx, float(h) * 0.5),
			"hurtbox": Rect2(cx - 1.0, float(h) * 0.5, 2.0, 2.0),
			"bbox": Rect2(cx - 1.0, float(h) * 0.5, 2.0, 2.0),
		}

	var col_count := PackedInt32Array()
	col_count.resize(w)
	var col_top := PackedInt32Array()
	col_top.resize(w)
	col_top.fill(-1)
	var col_bot := PackedInt32Array()
	col_bot.resize(w)
	col_bot.fill(-1)
	var sil_left: int = w
	var sil_right: int = -1
	var sil_top: int = h
	var sil_bot: int = -1
	for p in best_pixels:
		var px: int = p % w
		var py: int = p / w
		col_count[px] += 1
		if col_top[px] < 0:
			col_top[px] = py
		col_bot[px] = py
		sil_left = mini(sil_left, px)
		sil_right = maxi(sil_right, px)
		sil_top = mini(sil_top, py)
		sil_bot = maxi(sil_bot, py)

	var comp_h: int = sil_bot - sil_top + 1
	var body_col_min: int = maxi(8, int(float(comp_h) * 0.25))
	var body_left: int = w
	var body_right: int = -1
	var body_top: int = h
	var body_bot: int = -1
	for x in range(w):
		if col_count[x] >= body_col_min:
			body_left = mini(body_left, x)
			body_right = maxi(body_right, x)
			body_top = mini(body_top, col_top[x])
			body_bot = maxi(body_bot, col_bot[x])
	if body_right < 0:
		body_left = sil_left
		body_right = sil_right
		body_top = sil_top
		body_bot = sil_bot

	var foot_y: int = sil_bot
	var foot_x: float = float(body_left + body_right) * 0.5

	var tip_x: int = sil_right
	var tip_y: float = float(body_top + body_bot) * 0.5
	for x in range(w - 1, -1, -1):
		if col_count[x] >= TIP_MIN_RUN:
			tip_x = x
			tip_y = float(col_top[x] + col_bot[x]) * 0.5
			break

	var chest_x: float = float(body_left + body_right) * 0.5
	var chest_y: float = float(body_top) + float(foot_y - body_top) * 0.45

	return {
		"footAnchor": Vector2(foot_x, float(foot_y)),
		"weaponTip": Vector2(float(tip_x), tip_y),
		"chestAnchor": Vector2(chest_x, chest_y),
		"hurtbox": Rect2(float(body_left), float(body_top), float(body_right - body_left), float(body_bot - body_top)),
		"bbox": Rect2(float(sil_left), float(sil_top), float(sil_right - sil_left), float(sil_bot - sil_top)),
	}
