extends SceneTree

const CombatSetupScript = preload("res://scripts/sim/combat_setup.gd")
const CombatStepScript = preload("res://scripts/sim/combat_step.gd")
const ShapeMathScript = preload("res://scripts/visual/collision_shape_math.gd")

const OUT_DIR: String = "/tmp/light_deadzone_probe"
const STEP: float = 1.0 / 60.0
const DISTANCES: Array[int] = [
	0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
	110, 120, 130, 140, 150, 160, 170, 180, 190, 200,
]
const PASSES: Array[Dictionary] = [
	{"name": "grounded", "enemy_y_offset": 0.0},
	{"name": "elevated_20", "enemy_y_offset": -20.0},
]
const LIVE_SIGNED_DISTANCES: Array[int] = [
	-80, -70, -60, -50, -40, -30, -20, -10,
	0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
	110, 120, 130, 140, 150, 160, 170, 180, 190, 200,
]

func _init() -> void:
	DataManager.initialize()
	RngService.set_run_seed(4242)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var rows: Array[Dictionary] = []
	var summaries: Array[Dictionary] = []
	var first_miss: Dictionary = {}

	for pass_cfg in PASSES:
		var pass_rows: Array[Dictionary] = _run_pass(str(pass_cfg["name"]), float(pass_cfg["enemy_y_offset"]))
		rows.append_array(pass_rows)
		var pass_summary: Dictionary = _summarize_pass(str(pass_cfg["name"]), pass_rows)
		summaries.append(pass_summary)
		if first_miss.is_empty():
			for row in pass_rows:
				if bool(row.get("is_hit_active", false)) and not bool(row.get("resolve_connect", false)):
					first_miss = row
					break

	var report: Dictionary = {
		"step": STEP,
		"distances": DISTANCES,
		"passes": PASSES,
		"summaries": summaries,
		"first_miss": first_miss,
		"live_signed_overlap": _run_live_signed_overlap(),
		"rows": rows,
	}
	_write_json(OUT_DIR.path_join("probe.json"), report)
	_write_csv(OUT_DIR.path_join("probe.csv"), rows)
	_print_summary(summaries, first_miss)

	if first_miss.is_empty():
		var row_for_png: Dictionary = _first_active_row(rows)
		if not row_for_png.is_empty():
			_save_debug_png(row_for_png, OUT_DIR.path_join("debug_no_miss_first_active.png"))
	else:
		_save_debug_png(first_miss, OUT_DIR.path_join("first_miss.png"))

	RngService.clear_run_seed()
	quit(0)

func _run_pass(pass_name: String, enemy_y_offset: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for d in DISTANCES:
		var player: Fighter = EnemyFactory.create_player()
		var node: MapNode = MapNode.new(0, 0, MapNode.NodeType.BATTLE, [])
		var setup: Dictionary = CombatSetupScript.prepare(player, node, "bandit_swordsman")
		var enemy: Fighter = setup["enemy"] as Fighter
		var combat_system: CombatSystem = setup["combat_system"] as CombatSystem
		var hit_geometry: Variant = setup["hit_geometry"]
		enemy.is_ai = false
		enemy.ai_brain = null
		_place_pair(player, enemy, float(d), enemy_y_offset)
		player.start_light_attack()

		var attack_def: Variant = player._attack_state.def
		var frame: int = 0
		var elapsed: float = float(attack_def.windup_end)
		while elapsed < float(attack_def.active_end) - 0.000001:
			player._attack_state.elapsed = elapsed
			player.current_animation = Fighter.AnimationState.ATTACKING_LIGHT
			player.facing = 1
			enemy.facing = -1
			_reset_defender_for_sample(enemy, float(d), enemy_y_offset)
			player.was_hit_this_swing = false

			var cap: Dictionary = hit_geometry.debug_capsule_world(player)
			var hurt: Rect2 = hit_geometry.debug_hurtbox_world(enemy)
			var query_hit: bool = hit_geometry.query_hit(player, enemy)
			var segment_distance: float = INF
			if not cap.is_empty():
				segment_distance = ShapeMathScript.segment_rect_distance(cap["a"] as Vector2, cap["b"] as Vector2, hurt)

			var before_health: float = enemy.health_current
			combat_system.resolve_hits(player, enemy)
			var resolve_connect: bool = player.was_hit_this_swing or enemy.health_current < before_health

			rows.append({
				"pass": pass_name,
				"D": d,
				"enemy_y_offset": enemy_y_offset,
				"frame": frame,
				"elapsed": elapsed,
				"phase": player._attack_state.phase(),
				"is_hit_active": player.is_hit_active(),
				"resolve_connect": resolve_connect,
				"query_hit": query_hit,
				"segment_distance": segment_distance,
				"capsule_a": _v2(cap.get("a", Vector2.ZERO)),
				"capsule_b": _v2(cap.get("b", Vector2.ZERO)),
				"capsule_r": float(cap.get("r", 0.0)),
				"hurtbox": _rect(hurt),
				"player_pos": _v2(player.position),
				"enemy_pos": _v2(enemy.position),
				"enemy_health_after": enemy.health_current,
			})
			frame += 1
			elapsed += STEP
	return rows

func _place_pair(player: Fighter, enemy: Fighter, center_distance: float, enemy_y_offset: float) -> void:
	player.position = Vector2(360.0, GameConstants.GROUND_Y)
	player.velocity = Vector2.ZERO
	player.is_grounded = true
	player.facing = 1
	enemy.position = Vector2(player.position.x + center_distance, GameConstants.GROUND_Y + enemy_y_offset)
	enemy.velocity = Vector2.ZERO
	enemy.is_grounded = enemy_y_offset >= 0.0
	enemy.facing = -1

func _reset_defender_for_sample(enemy: Fighter, center_distance: float, enemy_y_offset: float) -> void:
	enemy.position = Vector2(360.0 + center_distance, GameConstants.GROUND_Y + enemy_y_offset)
	enemy.velocity = Vector2.ZERO
	enemy.health_current = enemy.health_max
	enemy.posture_current = enemy.posture_max
	enemy.current_animation = Fighter.AnimationState.IDLE
	enemy.animation_timer = 0.0
	enemy.is_invulnerable = false
	enemy.is_blocking = false
	enemy.is_stunned = false
	enemy.is_grabbed = false
	enemy.was_hit_this_swing = false

func _summarize_pass(pass_name: String, rows: Array[Dictionary]) -> Dictionary:
	var distances_with_miss: Array[int] = []
	var distances_all_hit: Array[int] = []
	for d in DISTANCES:
		var has_active: bool = false
		var any_miss: bool = false
		var any_hit: bool = false
		for row in rows:
			if int(row["D"]) != d:
				continue
			if bool(row["is_hit_active"]):
				has_active = true
				if bool(row["resolve_connect"]):
					any_hit = true
				else:
					any_miss = true
		if has_active and any_miss:
			distances_with_miss.append(d)
		elif has_active and any_hit:
			distances_all_hit.append(d)
	return {
		"pass": pass_name,
		"distances_all_hit": distances_all_hit,
		"distances_with_miss": distances_with_miss,
	}

func _first_active_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if bool(row.get("is_hit_active", false)):
			return row
	return {}

func _print_summary(summaries: Array[Dictionary], first_miss: Dictionary) -> void:
	print("LIGHT DEADZONE PROBE")
	for summary in summaries:
		print("%s all-hit D: %s" % [str(summary["pass"]), str(summary["distances_all_hit"])])
		print("%s miss D: %s" % [str(summary["pass"]), str(summary["distances_with_miss"])])
	if first_miss.is_empty():
		print("FIRST MISS: none")
		print("DEBUG PNG: %s" % OUT_DIR.path_join("debug_no_miss_first_active.png"))
	else:
		print("FIRST MISS: pass=%s D=%d frame=%d elapsed=%.4f segment_distance=%.2f r=%.2f" % [
			str(first_miss["pass"]),
			int(first_miss["D"]),
			int(first_miss["frame"]),
			float(first_miss["elapsed"]),
			float(first_miss["segment_distance"]),
			float(first_miss["capsule_r"]),
		])
		print("DEBUG PNG: %s" % OUT_DIR.path_join("first_miss.png"))
	print("JSON: %s" % OUT_DIR.path_join("probe.json"))
	print("CSV: %s" % OUT_DIR.path_join("probe.csv"))

func _run_live_signed_overlap() -> Dictionary:
	var rows: Array[Dictionary] = []
	var summary: Dictionary = {}
	for d in LIVE_SIGNED_DISTANCES:
		var player: Fighter = EnemyFactory.create_player()
		var node: MapNode = MapNode.new(0, 0, MapNode.NodeType.BATTLE, [])
		var setup: Dictionary = CombatSetupScript.prepare(player, node, "bandit_swordsman")
		var enemy: Fighter = setup["enemy"] as Fighter
		var combat_system: CombatSystem = setup["combat_system"] as CombatSystem
		var hit_geometry: Variant = setup["hit_geometry"]
		enemy.is_ai = false
		enemy.ai_brain = null
		_place_pair(player, enemy, float(d), 0.0)

		var input: Dictionary = _light_input()
		var any_damage: bool = false
		var active_frames: int = 0
		var first_damage_frame: int = -1
		for frame in range(40):
			_place_pair(player, enemy, float(d), 0.0)
			var health_before: float = enemy.health_current
			CombatStepScript.advance(combat_system, player, enemy, input, STEP)
			input = _neutral_input()
			var cap: Dictionary = hit_geometry.debug_capsule_world(player)
			var hurt: Rect2 = hit_geometry.debug_hurtbox_world(enemy)
			var query_hit: bool = hit_geometry.query_hit(player, enemy)
			var segment_distance: float = INF
			if not cap.is_empty():
				segment_distance = ShapeMathScript.segment_rect_distance(cap["a"] as Vector2, cap["b"] as Vector2, hurt)
			var damaged: bool = enemy.health_current < health_before
			if damaged and first_damage_frame < 0:
				first_damage_frame = frame
			any_damage = any_damage or damaged
			if player.is_hit_active():
				active_frames += 1
			rows.append({
				"D": d,
				"frame": frame,
				"elapsed": player._attack_state.elapsed,
				"facing": player.facing,
				"is_hit_active": player.is_hit_active(),
				"query_hit": query_hit,
				"damaged": damaged,
				"segment_distance": segment_distance,
				"capsule_a": _v2(cap.get("a", Vector2.ZERO)),
				"capsule_b": _v2(cap.get("b", Vector2.ZERO)),
				"capsule_r": float(cap.get("r", 0.0)),
				"hurtbox": _rect(hurt),
				"player_pos": _v2(player.position),
				"enemy_pos": _v2(enemy.position),
				"enemy_health": enemy.health_current,
			})
		summary[str(d)] = {
			"hit": any_damage,
			"active_frames": active_frames,
			"first_damage_frame": first_damage_frame,
			"final_enemy_health": enemy.health_current,
		}
	_write_json(OUT_DIR.path_join("live_signed_overlap.json"), {"summary": summary, "rows": rows})
	var missed: Array[int] = []
	for d in LIVE_SIGNED_DISTANCES:
		if not bool((summary[str(d)] as Dictionary)["hit"]):
			missed.append(d)
	print("live_signed_overlap miss D: %s" % str(missed))
	print("LIVE JSON: %s" % OUT_DIR.path_join("live_signed_overlap.json"))
	return {"summary": summary, "rows_path": OUT_DIR.path_join("live_signed_overlap.json"), "miss_distances": missed}

func _light_input() -> Dictionary:
	var input: Dictionary = _neutral_input()
	input["light_pressed"] = true
	return input

func _neutral_input() -> Dictionary:
	return {
		"move": 0.0,
		"jump_pressed": false,
		"dash_pressed": false,
		"parry_pressed": false,
		"light_pressed": false,
		"heavy_pressed": false,
		"block_down": false,
		"block_pressed": false,
		"stance_pressed": false,
	}

func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()

func _write_csv(path: String, rows: Array[Dictionary]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_line("pass,D,enemy_y_offset,frame,elapsed,is_hit_active,resolve_connect,query_hit,segment_distance,capsule_ax,capsule_ay,capsule_bx,capsule_by,capsule_r,hurt_x,hurt_y,hurt_w,hurt_h,player_x,player_y,enemy_x,enemy_y")
	for row in rows:
		var a: Array = row["capsule_a"] as Array
		var b: Array = row["capsule_b"] as Array
		var hurt: Array = row["hurtbox"] as Array
		var player_pos: Array = row["player_pos"] as Array
		var enemy_pos: Array = row["enemy_pos"] as Array
		file.store_line("%s,%d,%.1f,%d,%.6f,%s,%s,%s,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [
			str(row["pass"]),
			int(row["D"]),
			float(row["enemy_y_offset"]),
			int(row["frame"]),
			float(row["elapsed"]),
			str(bool(row["is_hit_active"])),
			str(bool(row["resolve_connect"])),
			str(bool(row["query_hit"])),
			float(row["segment_distance"]),
			float(a[0]), float(a[1]),
			float(b[0]), float(b[1]),
			float(row["capsule_r"]),
			float(hurt[0]), float(hurt[1]), float(hurt[2]), float(hurt[3]),
			float(player_pos[0]), float(player_pos[1]),
			float(enemy_pos[0]), float(enemy_pos[1]),
		])
	file.close()

func _save_debug_png(row: Dictionary, path: String) -> void:
	var img: Image = Image.create(960, 540, false, Image.FORMAT_RGBA8)
	img.fill(Color8(20, 22, 28))
	var cap_a: Vector2 = _arr_v2(row["capsule_a"] as Array)
	var cap_b: Vector2 = _arr_v2(row["capsule_b"] as Array)
	var r: float = float(row["capsule_r"])
	var hurt_values: Array = row["hurtbox"] as Array
	var hurt := Rect2(float(hurt_values[0]), float(hurt_values[1]), float(hurt_values[2]), float(hurt_values[3]))
	var player_pos: Vector2 = _arr_v2(row["player_pos"] as Array)
	var enemy_pos: Vector2 = _arr_v2(row["enemy_pos"] as Array)

	var world_rect: Rect2 = Rect2(Vector2(player_pos.x - 80.0, GameConstants.GROUND_Y - 330.0), Vector2(520.0, 380.0))
	var map_scale: float = minf(860.0 / world_rect.size.x, 450.0 / world_rect.size.y)
	var origin := Vector2(50.0, 40.0)
	_draw_rect(img, Rect2(_map(hurt.position, world_rect, origin, map_scale), hurt.size * map_scale), Color8(240, 80, 80), false)
	_draw_circle(img, _map(cap_a, world_rect, origin, map_scale), r * map_scale, Color8(255, 220, 70), false)
	_draw_circle(img, _map(cap_b, world_rect, origin, map_scale), r * map_scale, Color8(255, 220, 70), false)
	_draw_line(img, _map(cap_a, world_rect, origin, map_scale), _map(cap_b, world_rect, origin, map_scale), Color8(255, 220, 70), 4)
	_draw_line(img, _map(Vector2(world_rect.position.x, GameConstants.GROUND_Y), world_rect, origin, map_scale), _map(Vector2(world_rect.end.x, GameConstants.GROUND_Y), world_rect, origin, map_scale), Color8(120, 180, 130), 2)
	_draw_circle(img, _map(player_pos, world_rect, origin, map_scale), 5.0, Color8(100, 180, 255), true)
	_draw_circle(img, _map(enemy_pos, world_rect, origin, map_scale), 5.0, Color8(255, 100, 100), true)
	img.save_png(path)

func _map(p: Vector2, world_rect: Rect2, origin: Vector2, scale: float) -> Vector2:
	return origin + Vector2((p.x - world_rect.position.x) * scale, (p.y - world_rect.position.y) * scale)

func _draw_rect(img: Image, rect: Rect2, color: Color, fill: bool) -> void:
	if fill:
		for y in range(int(rect.position.y), int(rect.end.y) + 1):
			for x in range(int(rect.position.x), int(rect.end.x) + 1):
				_set_px(img, x, y, color)
	else:
		_draw_line(img, rect.position, Vector2(rect.end.x, rect.position.y), color, 2)
		_draw_line(img, Vector2(rect.end.x, rect.position.y), rect.end, color, 2)
		_draw_line(img, rect.end, Vector2(rect.position.x, rect.end.y), color, 2)
		_draw_line(img, Vector2(rect.position.x, rect.end.y), rect.position, color, 2)

func _draw_circle(img: Image, center: Vector2, radius: float, color: Color, fill: bool) -> void:
	var r_int: int = int(ceil(radius))
	var r_sq: float = radius * radius
	for y in range(int(center.y) - r_int, int(center.y) + r_int + 1):
		for x in range(int(center.x) - r_int, int(center.x) + r_int + 1):
			var d_sq: float = Vector2(float(x), float(y)).distance_squared_to(center)
			if (fill and d_sq <= r_sq) or ((not fill) and absf(sqrt(d_sq) - radius) <= 1.5):
				_set_px(img, x, y, color)

func _draw_line(img: Image, a: Vector2, b: Vector2, color: Color, width: int = 1) -> void:
	var steps: int = int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	if steps <= 0:
		_set_px(img, int(a.x), int(a.y), color)
		return
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		for oy in range(-width, width + 1):
			for ox in range(-width, width + 1):
				_set_px(img, int(round(p.x)) + ox, int(round(p.y)) + oy, color)

func _set_px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)

func _v2(v: Variant) -> Array[float]:
	var p: Vector2 = v as Vector2
	return [p.x, p.y]

func _rect(r: Rect2) -> Array[float]:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func _arr_v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
