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
var _reward_selection_idx: int = 0
var _end_message: String = ""
var _game_over_hover_restart: bool = false

var _input_tracker: InputTracker = InputTracker.new()
var _cursor_flash: float = 0.0

func _ready() -> void:
	Engine.max_fps = GameConstants.TARGET_FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DataManager.initialize()
	start_new_run()
	_combat_scene.combat_end.connect(_on_combat_end)
	queue_redraw()
	_sync_input_tracker()

func start_new_run() -> void:
	_player = EnemyFactory.create_player()
	_run_state = RunState.create_procedural_run()
	_current_scene = SceneType.MAP
	_map_selection_idx = 0
	_reward_selection_idx = 0
	_reward1 = null
	_reward2 = null
	_end_message = ""
	_game_over_hover_restart = false
	_input_tracker.clear()
	_combat_scene.on_exit()
	_combat_scene.deactivate()

func _process(delta: float) -> void:
	_cursor_flash += delta

	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
		return

	if _input_tracker.pressed_key(KEY_F5):
		DataManager.reload_data()

	if _input_tracker.pressed_key(KEY_R):
		start_new_run()
		_sync_input_tracker()
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
			_update_game_over()

	_sync_input_tracker()
	queue_redraw()

func _update_map() -> void:
	var next_nodes: Array[MapNode] = _run_state.get_available_next()
	if next_nodes.is_empty():
		_current_scene = SceneType.GAME_OVER
		_end_message = "Run Clear!"
		return

	_map_selection_idx = clampi(_map_selection_idx, 0, next_nodes.size() - 1)

	if _input_tracker.pressed_key(KEY_A) or _input_tracker.pressed_key(KEY_LEFT):
		_map_selection_idx = maxi(0, _map_selection_idx - 1)
	if _input_tracker.pressed_key(KEY_D) or _input_tracker.pressed_key(KEY_RIGHT):
		_map_selection_idx = mini(next_nodes.size() - 1, _map_selection_idx + 1)

	var hovered_idx: int = _get_hovered_map_index(next_nodes)
	if hovered_idx >= 0:
		_map_selection_idx = hovered_idx

	if _accept_pressed() or (hovered_idx >= 0 and _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT)):
		var chosen: MapNode = next_nodes[_map_selection_idx]
		_travel_to_node(chosen)

func _update_reward() -> void:
	if _reward1 == null or _reward2 == null:
		_reward1 = RewardOption.random()
		_reward2 = RewardOption.random(_reward1.id)

	if _input_tracker.pressed_key(KEY_A) or _input_tracker.pressed_key(KEY_LEFT):
		_reward_selection_idx = 0
	if _input_tracker.pressed_key(KEY_D) or _input_tracker.pressed_key(KEY_RIGHT):
		_reward_selection_idx = 1

	if _input_tracker.pressed_key(KEY_1) or _input_tracker.pressed_key(KEY_KP_1):
		_apply_reward_by_index(0)
		return
	if _input_tracker.pressed_key(KEY_2) or _input_tracker.pressed_key(KEY_KP_2):
		_apply_reward_by_index(1)
		return

	var hovered_idx: int = _get_hovered_reward_index()
	if hovered_idx >= 0:
		_reward_selection_idx = hovered_idx

	if _accept_pressed():
		_apply_reward_by_index(_reward_selection_idx)
	elif hovered_idx >= 0 and _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		_apply_reward_by_index(hovered_idx)

func _update_game_over() -> void:
	var restart_rect: Rect2 = _get_restart_button_rect()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	_game_over_hover_restart = restart_rect.has_point(mouse_pos)

	if _accept_pressed() or (_game_over_hover_restart and _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT)):
		start_new_run()

func _travel_to_node(chosen: MapNode) -> void:
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

func _apply_reward_by_index(index: int) -> void:
	var selected: RewardOption = null
	if index == 0:
		selected = _reward1
	else:
		selected = _reward2
	if selected == null:
		return

	selected.apply(_player)
	_reward1 = null
	_reward2 = null
	_reward_selection_idx = 0
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
	_draw_background()

	var next_nodes: Array[MapNode] = _run_state.get_available_next()
	var tiers: int = _run_state.max_tier + 1
	var top: int = 160
	var bottom: int = GameConstants.VIEW_HEIGHT - 170
	var tier_height: int = int((bottom - top) / maxi(1, tiers - 1))

	for node in _run_state.nodes:
		for to_id in node.next_ids:
			var target: MapNode = _run_state.get_node(to_id)
			if target == null:
				continue
			var from_pos: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
			var to_pos: Vector2 = _get_map_node_position(target, tiers, top, tier_height)
			draw_line(from_pos, to_pos, Color(1.0, 1.0, 1.0, 0.12), 2.0)

	for node in _run_state.nodes:
		var pos: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
		var node_color: Color = _get_node_color(node.node_type)
		if node.cleared:
			node_color = node_color.darkened(0.55)
		draw_circle(pos, 12.0, node_color)

		if next_nodes.has(node):
			var idx: int = next_nodes.find(node)
			if idx == _map_selection_idx:
				draw_arc(pos, 20.0, 0.0, TAU, 40, Color(0.95, 0.95, 1.0, 0.8), 2.0, true)
				_draw_menu_cursor(pos + Vector2(-26.0, 4.0))

	_draw_text("Path Select", 60.0, 74.0, Color(0.95, 0.95, 0.98, 0.95), 28)
	_draw_text("Arrows/A-D to move, Enter/J or click to travel", 60.0, 106.0, Color(0.72, 0.74, 0.78, 0.85), 16)

	if not next_nodes.is_empty():
		var selected_node: MapNode = next_nodes[_map_selection_idx]
		var selected_label: String = _get_node_type_label(selected_node.node_type)
		_draw_text("Selected: %s" % selected_label, 60.0, GameConstants.VIEW_HEIGHT - 54.0, Color(0.88, 0.90, 0.95, 0.9), 18)

func _draw_reward() -> void:
	_draw_background()

	var panel: Rect2 = _get_reward_panel_rect()
	var box1: Rect2 = _get_reward_box_rect(0)
	var box2: Rect2 = _get_reward_box_rect(1)
	_draw_panel(panel)
	_draw_text("Choose Reward", panel.position.x + 26.0, panel.position.y + 40.0, Color(0.95, 0.95, 0.98, 0.95), 24)
	_draw_text("Arrows, 1/2, Enter or click", panel.position.x + 26.0, panel.position.y + 68.0, Color(0.72, 0.74, 0.78, 0.85), 15)

	var reward1_label: String = "..."
	if _reward1 != null:
		reward1_label = _reward1.label
	var reward2_label: String = "..."
	if _reward2 != null:
		reward2_label = _reward2.label

	_draw_reward_option(box1, reward1_label, _reward_selection_idx == 0)
	_draw_reward_option(box2, reward2_label, _reward_selection_idx == 1)

func _draw_game_over() -> void:
	_draw_background()
	var panel: Rect2 = _get_game_over_panel_rect()
	_draw_panel(panel)
	_draw_text(_end_message, panel.position.x + 26.0, panel.position.y + 48.0, Color(0.95, 0.95, 0.98, 0.95), 26)
	_draw_text("Press Enter / click to restart", panel.position.x + 26.0, panel.position.y + 78.0, Color(0.72, 0.74, 0.78, 0.85), 15)

	var restart_rect: Rect2 = _get_restart_button_rect()
	var border: Color = Color(0.6, 0.62, 0.68, 0.4)
	if _game_over_hover_restart:
		border = Color(0.9, 0.92, 0.98, 0.95)
	draw_rect(restart_rect, Color(0.06, 0.07, 0.08, 0.88), true)
	draw_rect(restart_rect, border, false, 2.0)
	_draw_text("Restart Run", restart_rect.position.x + 28.0, restart_rect.position.y + 34.0, Color(0.9, 0.92, 0.96, 0.95), 18)
	_draw_menu_cursor(restart_rect.position + Vector2(-14.0, 30.0))

func _draw_background() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color8(14, 15, 18), true)
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, 1.0), Color(1.0, 1.0, 1.0, 0.08), true)
	draw_rect(Rect2(0.0, GameConstants.VIEW_HEIGHT - 1.0, GameConstants.VIEW_WIDTH, 1.0), Color(1.0, 1.0, 1.0, 0.08), true)

func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.05, 0.06, 0.08, 0.88), true)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.10), false, 2.0)
	draw_line(rect.position + Vector2(0.0, 2.0), rect.position + Vector2(rect.size.x, 2.0), Color(1.0, 1.0, 1.0, 0.16), 1.0)

func _draw_reward_option(rect: Rect2, label: String, selected: bool) -> void:
	var border: Color = Color(1.0, 1.0, 1.0, 0.12)
	if selected:
		border = Color(0.92, 0.93, 0.98, 0.92)
	draw_rect(rect, Color(0.09, 0.10, 0.12, 0.85), true)
	draw_rect(rect, border, false, 2.0)
	_draw_text(label, rect.position.x + 18.0, rect.position.y + 54.0, Color(0.90, 0.92, 0.96, 0.95), 18)
	if selected:
		_draw_menu_cursor(Vector2(rect.position.x - 16.0, rect.position.y + 54.0))

func _draw_menu_cursor(position: Vector2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_cursor_flash * 8.0)
	var cursor_color: Color = Color(1.0, 1.0, 1.0, 0.55 + 0.35 * pulse)
	draw_circle(position, 2.5 + pulse, cursor_color)
	draw_line(position + Vector2(-10.0, -4.0), position + Vector2(-2.0, 0.0), cursor_color, 2.0)
	draw_line(position + Vector2(-10.0, 4.0), position + Vector2(-2.0, 0.0), cursor_color, 2.0)

func _draw_text(text: String, x: float, y: float, color: Color, size: int = 16) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _get_map_node_position(node: MapNode, tiers: int, top: int, tier_height: int) -> Vector2:
	var y: int = top + node.tier * tier_height
	var count_in_tier: int = _run_state.count_in_tier(node.tier)
	var idx_in_tier: int = _run_state.index_in_tier(node)
	var left: int = 180
	var right: int = GameConstants.VIEW_WIDTH - 180
	var x: int = (left + right) / 2
	if count_in_tier > 1:
		x = left + idx_in_tier * (right - left) / (count_in_tier - 1)
	return Vector2(x, y)

func _get_hovered_map_index(next_nodes: Array[MapNode]) -> int:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var tiers: int = _run_state.max_tier + 1
	var top: int = 160
	var bottom: int = GameConstants.VIEW_HEIGHT - 170
	var tier_height: int = int((bottom - top) / maxi(1, tiers - 1))

	for i in range(next_nodes.size()):
		var node: MapNode = next_nodes[i]
		var pos: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
		if mouse_pos.distance_to(pos) <= 22.0:
			return i
	return -1

func _get_reward_panel_rect() -> Rect2:
	var width: float = minf(960.0, float(GameConstants.VIEW_WIDTH) - 320.0)
	var height: float = 230.0
	return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - height) * 0.5 - 20.0, width, height)

func _get_reward_box_rect(index: int) -> Rect2:
	var panel: Rect2 = _get_reward_panel_rect()
	var gap: float = 24.0
	var box_width: float = (panel.size.x - gap * 3.0) * 0.5
	var box_height: float = 104.0
	var x: float = panel.position.x + gap + float(index) * (box_width + gap)
	var y: float = panel.position.y + 96.0
	return Rect2(x, y, box_width, box_height)

func _get_hovered_reward_index() -> int:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var box1: Rect2 = _get_reward_box_rect(0)
	if box1.has_point(mouse_pos):
		return 0
	var box2: Rect2 = _get_reward_box_rect(1)
	if box2.has_point(mouse_pos):
		return 1
	return -1

func _get_game_over_panel_rect() -> Rect2:
	var width: float = 560.0
	var height: float = 200.0
	return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - height) * 0.5 - 30.0, width, height)

func _get_restart_button_rect() -> Rect2:
	var panel: Rect2 = _get_game_over_panel_rect()
	return Rect2(panel.position.x + 22.0, panel.position.y + 104.0, 220.0, 46.0)

func _get_node_color(node_type: int) -> Color:
	match node_type:
		MapNode.NodeType.BATTLE:
			return Color8(104, 186, 255)
		MapNode.NodeType.ELITE:
			return Color8(255, 165, 115)
		MapNode.NodeType.TREASURE:
			return Color8(248, 224, 142)
		MapNode.NodeType.EVENT:
			return Color8(182, 194, 214)
		MapNode.NodeType.BOSS:
			return Color8(255, 105, 128)
		_:
			return Color8(210, 210, 220)

func _get_node_type_label(node_type: int) -> String:
	match node_type:
		MapNode.NodeType.BATTLE:
			return "Battle"
		MapNode.NodeType.ELITE:
			return "Elite"
		MapNode.NodeType.TREASURE:
			return "Treasure"
		MapNode.NodeType.EVENT:
			return "Event"
		MapNode.NodeType.BOSS:
			return "Boss"
		_:
			return "Unknown"

func _accept_pressed() -> bool:
	return _input_tracker.pressed_key(KEY_ENTER) or _input_tracker.pressed_key(KEY_KP_ENTER) or _input_tracker.pressed_key(KEY_SPACE) or _input_tracker.pressed_key(KEY_J)

func _sync_input_tracker() -> void:
	var keys: Array[int] = [
		KEY_ESCAPE,
		KEY_F5,
		KEY_R,
		KEY_A,
		KEY_D,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_ENTER,
		KEY_KP_ENTER,
		KEY_SPACE,
		KEY_J,
		KEY_1,
		KEY_2,
		KEY_KP_1,
		KEY_KP_2
	]
	_input_tracker.sync_keys(keys)
	_input_tracker.sync_mouse_buttons([MOUSE_BUTTON_LEFT])
