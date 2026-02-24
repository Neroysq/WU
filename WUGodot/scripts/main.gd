extends Node2D

enum SceneType {
	MAP,
	COMBAT,
	REWARD,
	GAME_OVER,
}

@onready var _combat_scene: CombatScene = $CombatScene

var _current_scene: int = SceneType.MAP
var _run_state: RunState
var _player: Fighter
var _map_selection_idx: int = 0
var _reward1: RewardOption
var _reward2: RewardOption
var _end_message: String = ""

var _prev_keys: Dictionary = {}

func _ready() -> void:
	Engine.max_fps = GameConstants.TARGET_FPS
	DataManager.initialize()
	start_new_run()
	_combat_scene.combat_end.connect(_on_combat_end)
	queue_redraw()
	_sync_prev_keys()

func start_new_run() -> void:
	_player = EnemyFactory.create_player()
	_run_state = RunState.create_simple_three_tier()
	_current_scene = SceneType.MAP
	_map_selection_idx = 0
	_reward1 = null
	_reward2 = null
	_end_message = ""
	_combat_scene.on_exit()
	_combat_scene.deactivate()

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
		return

	if _pressed(KEY_F5):
		DataManager.reload_data()

	if _pressed(KEY_R):
		start_new_run()
		_sync_prev_keys()
		queue_redraw()
		return

	match _current_scene:
		SceneType.MAP:
			_update_map()
		SceneType.COMBAT:
			pass
		SceneType.REWARD:
			_update_reward()
		SceneType.GAME_OVER:
			pass

	_sync_prev_keys()
	queue_redraw()

func _update_map() -> void:
	var next_nodes: Array[MapNode] = _run_state.get_available_next()
	if next_nodes.is_empty():
		_current_scene = SceneType.GAME_OVER
		_end_message = "Run Clear!"
		return

	if _pressed(KEY_A):
		_map_selection_idx = maxi(0, _map_selection_idx - 1)
	if _pressed(KEY_D):
		_map_selection_idx = mini(next_nodes.size() - 1, _map_selection_idx + 1)

	if _pressed(KEY_ENTER) or _pressed(KEY_J):
		var chosen: MapNode = next_nodes[_map_selection_idx]
		_run_state.advance_to(chosen.id)
		_map_selection_idx = 0

		match chosen.node_type:
			MapNode.NodeType.EVENT:
				_player.health_current = minf(_player.health_current + 20.0, _player.health_max)
				_run_state.mark_current_node_cleared()
			MapNode.NodeType.TREASURE:
				_player.posture_max += 10.0
				_player.posture_current = minf(_player.posture_current + 10.0, _player.posture_max)
				_run_state.mark_current_node_cleared()
			_:
				_combat_scene.setup_combat(_player, chosen)
				_combat_scene.on_enter()
				_current_scene = SceneType.COMBAT

func _update_reward() -> void:
	if _reward1 == null or _reward2 == null:
		_reward1 = RewardOption.random()
		_reward2 = RewardOption.random(_reward1.id)

	if _pressed(KEY_1) or _pressed(KEY_KP_1):
		_reward1.apply(_player)
		_reward1 = null
		_reward2 = null
		_current_scene = SceneType.MAP
	elif _pressed(KEY_2) or _pressed(KEY_KP_2):
		_reward2.apply(_player)
		_reward1 = null
		_reward2 = null
		_current_scene = SceneType.MAP

func _on_combat_end(victory: bool) -> void:
	_combat_scene.on_exit()
	_combat_scene.deactivate()

	if victory:
		_run_state.mark_current_node_cleared()
		var node: MapNode = _run_state.get_current_node()
		if node != null and node.node_type == MapNode.NodeType.BOSS:
			_current_scene = SceneType.GAME_OVER
			_end_message = "Victory! Run Complete!"
		else:
			_current_scene = SceneType.REWARD
	else:
		_current_scene = SceneType.GAME_OVER
		_end_message = "Defeat..."

func _draw() -> void:
	match _current_scene:
		SceneType.MAP:
			_draw_map()
		SceneType.COMBAT:
			pass
		SceneType.REWARD:
			_draw_reward()
		SceneType.GAME_OVER:
			_draw_game_over()

func _draw_map() -> void:
	draw_rect(Rect2(0, 0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)
	draw_rect(Rect2(0, 0, GameConstants.VIEW_WIDTH, 90), GameConstants.COLOR_INK_MID, true)
	draw_rect(Rect2(0, GameConstants.VIEW_HEIGHT - 110, GameConstants.VIEW_WIDTH, 110), GameConstants.COLOR_INK_DARK, true)
	draw_rect(Rect2(20, 20, GameConstants.VIEW_WIDTH - 40, GameConstants.VIEW_HEIGHT - 40), Color(0, 0, 0, 0.16), true)

	var next_nodes: Array[MapNode] = _run_state.get_available_next()
	var tiers: int = _run_state.max_tier + 1
	var top: int = 120
	var bottom: int = GameConstants.VIEW_HEIGHT - 140
	var tier_height: int = int((bottom - top) / maxi(1, tiers - 1))

	for node in _run_state.nodes:
		for to_id in node.next_ids:
			var target: MapNode = _run_state.get_node(to_id)
			if target == null:
				continue
			var a: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
			var b: Vector2 = _get_map_node_position(target, tiers, top, tier_height)
			draw_line(a, b, Color8(60, 60, 72), 3.0)

	for node in _run_state.nodes:
		var pos: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
		var size: int = 18
		var rect: Rect2 = Rect2(pos.x - size, pos.y - size, size * 2, size * 2)

		var node_color: Color = Color.WHITE
		match node.node_type:
			MapNode.NodeType.BATTLE:
				node_color = Color8(90, 160, 255)
			MapNode.NodeType.ELITE:
				node_color = Color8(255, 140, 90)
			MapNode.NodeType.TREASURE:
				node_color = Color8(255, 215, 120)
			MapNode.NodeType.EVENT:
				node_color = Color8(180, 180, 210)
			MapNode.NodeType.BOSS:
				node_color = Color8(255, 80, 110)

		if node.cleared:
			node_color = node_color.darkened(0.5)
		draw_rect(rect, node_color, true)

		if next_nodes.has(node):
			var idx: int = next_nodes.find(node)
			if idx == _map_selection_idx:
				draw_rect(Rect2(rect.position.x - 4, rect.position.y - 4, rect.size.x + 8, rect.size.y + 8), Color(1, 1, 1, 0.18), false)

	_draw_text("Map: A/D select  Enter travel  R restart", 36, 42, GameConstants.COLOR_SCROLL_WHITE, 18)

func _draw_reward() -> void:
	draw_rect(Rect2(0, 0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)

	var w: int = GameConstants.VIEW_WIDTH - 300
	var h: int = 200
	var rect: Rect2 = Rect2((GameConstants.VIEW_WIDTH - w) / 2, (GameConstants.VIEW_HEIGHT - h) / 2 - 40, w, h)
	_draw_panel(rect)
	_draw_text("Choose a reward: 1 or 2", rect.position.x + 28, rect.position.y + 36, GameConstants.COLOR_SCROLL_WHITE, 20)

	var box_w: int = (w - 60) / 2
	var box_h: int = 80
	var box1: Rect2 = Rect2(rect.position.x + 20, rect.position.y + 80, box_w, box_h)
	var box2: Rect2 = Rect2(rect.position.x + 40 + box_w, rect.position.y + 80, box_w, box_h)
	draw_rect(box1, Color8(24, 22, 28), true)
	draw_rect(box2, Color8(24, 22, 28), true)
	draw_rect(Rect2(box1.position.x, box1.position.y, box1.size.x, 2), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(box2.position.x, box2.position.y, box2.size.x, 2), GameConstants.COLOR_GOLD_DARK)
	_draw_text(_reward1.label if _reward1 != null else "...", box1.position.x + 16, box1.position.y + 44, Color8(200, 220, 255), 18)
	_draw_text(_reward2.label if _reward2 != null else "...", box2.position.x + 16, box2.position.y + 44, Color8(200, 220, 255), 18)

func _draw_game_over() -> void:
	draw_rect(Rect2(0, 0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)
	var rect: Rect2 = Rect2((GameConstants.VIEW_WIDTH - 420) / 2, (GameConstants.VIEW_HEIGHT - 120) / 2 - 24, 420, 120)
	_draw_panel(rect)
	_draw_text(_end_message, rect.position.x + 28, rect.position.y + 44, GameConstants.COLOR_SCROLL_WHITE, 22)
	_draw_text("R: restart run", rect.position.x + 28, rect.position.y + 78, Color(0.86, 0.86, 0.86, 0.7), 16)

func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, Color8(16, 14, 18, 200), true)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 2), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(rect.position.x, rect.end.y - 2, rect.size.x, 2), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(rect.position.x, rect.position.y, 2, rect.size.y), GameConstants.COLOR_GOLD_DARK)
	draw_rect(Rect2(rect.end.x - 2, rect.position.y, 2, rect.size.y), GameConstants.COLOR_GOLD_DARK)

func _draw_text(text: String, x: float, y: float, color: Color, size: int = 16) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _get_map_node_position(node: MapNode, tiers: int, top: int, tier_height: int) -> Vector2:
	var y: int = top + node.tier * tier_height
	var count_in_tier: int = _run_state.count_in_tier(node.tier)
	var idx_in_tier: int = _run_state.index_in_tier(node)
	var left: int = 140
	var right: int = GameConstants.VIEW_WIDTH - 140
	var x: int = (left + right) / 2
	if count_in_tier > 1:
		x = left + idx_in_tier * (right - left) / (count_in_tier - 1)
	return Vector2(x, y)

func _pressed(keycode: int) -> bool:
	var current: bool = Input.is_key_pressed(keycode)
	var previous: bool = bool(_prev_keys.get(keycode, false))
	return current and not previous

func _sync_prev_keys() -> void:
	var keys: Array[int] = [KEY_ESCAPE, KEY_F5, KEY_R, KEY_A, KEY_D, KEY_ENTER, KEY_J, KEY_1, KEY_2, KEY_KP_1, KEY_KP_2]
	for key in keys:
		_prev_keys[key] = Input.is_key_pressed(key)
