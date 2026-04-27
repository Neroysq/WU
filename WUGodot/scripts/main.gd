extends Node2D

const EventRunnerScript = preload("res://scripts/event_runner.gd")
const ShopGeneratorScript = preload("res://scripts/shop_generator.gd")
const TextWrappingScript = preload("res://scripts/util/text_wrapping.gd")

enum SceneType {
	MAIN_MENU,
	MAP,
	COMBAT,
	REWARD,
	EVENT,
	SHOP,
	REST,
	FORGET_TECHNIQUE,
	VICTORY,
	GAME_OVER,
}

@onready var _combat_scene: CombatScene = $CombatScene

var _current_scene: int = SceneType.MAIN_MENU
var _run_state: RunState
var _player: Fighter
var _map_selection_idx: int = 0
var _rewards: Array = []
var _reward_selection_idx: int = 0
var _end_message: String = ""
var _game_over_hover_restart: bool = false
var _event_runner: Variant = null
var _event_data: Dictionary = {}
var _event_choices: Array[Dictionary] = []
var _event_choice_idx: int = 0
var _event_result: Dictionary = {}
var _event_showing_result: bool = false
var _shop_items: Array[Dictionary] = []
var _shop_selection_idx: int = 0
var _shop_message: String = ""
var _shop_message_timer: float = 0.0
var _forget_selection_idx: int = 0
var _rest_choice_idx: int = 0
var _combat_gold_multiplier: int = 1
var _run_start_time: float = 0.0
var _run_end_time: float = 0.0
var _run_gold_earned: int = 0
var _run_techniques_acquired: Array[String] = []

var _input_tracker: InputTracker = InputTracker.new()
var _cursor_flash: float = 0.0

func _ready() -> void:
	Engine.max_fps = GameConstants.TARGET_FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DataManager.initialize()
	_current_scene = SceneType.MAIN_MENU
	_combat_scene.combat_end.connect(_on_combat_end)
	_combat_scene.deactivate()
	queue_redraw()
	_sync_input_tracker()

func start_new_run() -> void:
	_player = EnemyFactory.create_player()
	_run_state = RunState.create_procedural_run()
	_current_scene = SceneType.MAP
	_map_selection_idx = 0
	_reward_selection_idx = 0
	_rewards.clear()
	_end_message = ""
	_game_over_hover_restart = false
	_event_runner = null
	_event_data.clear()
	_event_choices.clear()
	_event_choice_idx = 0
	_event_result.clear()
	_event_showing_result = false
	_shop_items.clear()
	_shop_selection_idx = 0
	_shop_message = ""
	_shop_message_timer = 0.0
	_forget_selection_idx = 0
	_rest_choice_idx = 0
	_combat_gold_multiplier = 1
	_run_start_time = Time.get_ticks_msec() / 1000.0
	_run_end_time = 0.0
	_run_gold_earned = 0
	_run_techniques_acquired.clear()
	_input_tracker.clear()
	_combat_scene.on_exit()
	_combat_scene.deactivate()

func _process(delta: float) -> void:
	_cursor_flash += delta

	if Input.is_key_pressed(KEY_ESCAPE):
		if _current_scene == SceneType.MAIN_MENU or _current_scene == SceneType.MAP or _current_scene == SceneType.GAME_OVER:
			get_tree().quit()
			return

	if _input_tracker.pressed_key(KEY_F5):
		DataManager.reload_data()

	if _input_tracker.pressed_key(KEY_R) and (_current_scene == SceneType.MAP or _current_scene == SceneType.COMBAT):
		start_new_run()
		_sync_input_tracker()
		queue_redraw()
		return

	match _current_scene:
		SceneType.MAIN_MENU:
			_update_main_menu()
		SceneType.MAP:
			_update_map()
		SceneType.COMBAT:
			pass
		SceneType.REWARD:
			_update_reward()
		SceneType.EVENT:
			_update_event(delta)
		SceneType.SHOP:
			_update_shop(delta)
		SceneType.REST:
			_update_rest()
		SceneType.FORGET_TECHNIQUE:
			_update_forget_technique()
		SceneType.VICTORY:
			_update_victory()
		SceneType.GAME_OVER:
			_update_game_over()

	_sync_input_tracker()
	queue_redraw()

func _update_main_menu() -> void:
	if _accept_pressed() or _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		start_new_run()
		_current_scene = SceneType.MAP

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
	if _rewards.is_empty():
		var current_node: MapNode = _run_state.get_current_node()
		if current_node != null and current_node.node_type == MapNode.NodeType.MASTER:
			_run_state.mark_current_node_cleared()
			_current_scene = SceneType.MAP
			return
		_rewards = _generate_technique_rewards(3)

	var max_idx: int = _rewards.size() - 1
	if _input_tracker.pressed_key(KEY_A) or _input_tracker.pressed_key(KEY_LEFT):
		_reward_selection_idx = maxi(0, _reward_selection_idx - 1)
	if _input_tracker.pressed_key(KEY_D) or _input_tracker.pressed_key(KEY_RIGHT):
		_reward_selection_idx = mini(max_idx, _reward_selection_idx + 1)

	if _input_tracker.pressed_key(KEY_1) or _input_tracker.pressed_key(KEY_KP_1):
		_apply_reward_by_index(0)
		return
	if _input_tracker.pressed_key(KEY_2) or _input_tracker.pressed_key(KEY_KP_2):
		_apply_reward_by_index(1)
		return
	if _input_tracker.pressed_key(KEY_3) or _input_tracker.pressed_key(KEY_KP_3):
		if _rewards.size() > 2:
			_apply_reward_by_index(2)
			return

	var hovered_idx: int = _get_hovered_reward_index()
	if hovered_idx >= 0:
		_reward_selection_idx = hovered_idx

	if _accept_pressed():
		_apply_reward_by_index(_reward_selection_idx)
	elif hovered_idx >= 0 and _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		_apply_reward_by_index(hovered_idx)

func _update_event(delta: float) -> void:
	if _shop_message_timer > 0.0:
		_shop_message_timer -= delta

	if _event_runner == null:
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _event_showing_result:
		if _accept_pressed():
			var result: Dictionary = _event_result
			if bool(result.get("open_shop", false)):
				var owned_ids: Array[String] = []
				if _player.technique_engine != null:
					owned_ids = _player.technique_engine.technique_ids()
				_shop_items = ShopGeneratorScript.generate_shop(owned_ids, bool(result.get("shop_rarity_boost", false)))
				_shop_selection_idx = 0
				_shop_message = ""
				_shop_message_timer = 0.0
				_run_state.mark_current_node_cleared()
				_current_scene = SceneType.SHOP
			elif bool(result.get("trigger_combat", false)):
				_combat_gold_multiplier = int(result.get("combat_gold_multiplier", 1))
				var node: MapNode = _run_state.get_current_node()
				if node != null:
					_setup_combat_for_node(node)
				else:
					_run_state.mark_current_node_cleared()
					_current_scene = SceneType.MAP
			else:
				_run_state.mark_current_node_cleared()
				_current_scene = SceneType.MAP
		return

	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_event_choice_idx = maxi(0, _event_choice_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_event_choice_idx = mini(_event_choices.size() - 1, _event_choice_idx + 1)

	for i in range(mini(3, _event_choices.size())):
		if _input_tracker.pressed_key(KEY_1 + i):
			_event_choice_idx = i
			_resolve_event_choice(i)
			return

	if _accept_pressed():
		_resolve_event_choice(_event_choice_idx)

func _update_shop(delta: float) -> void:
	if _shop_message_timer > 0.0:
		_shop_message_timer -= delta

	var max_idx: int = maxi(_shop_items.size() - 1, 0)
	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_shop_selection_idx = maxi(0, _shop_selection_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_shop_selection_idx = mini(max_idx, _shop_selection_idx + 1)

	if _input_tracker.pressed_key(KEY_Q) or _input_tracker.pressed_key(KEY_ESCAPE):
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _accept_pressed() and _shop_selection_idx >= 0 and _shop_selection_idx < _shop_items.size():
		var item: Dictionary = _shop_items[_shop_selection_idx]
		var result: Dictionary = ShopGeneratorScript.buy_item(item, _player)
		_shop_message = str(result.get("message", ""))
		_shop_message_timer = 2.0
		if bool(result.get("success", false)):
			if str(item.get("type", "")) == "technique":
				var bought_id: String = str(item.get("technique_id", ""))
				if not bought_id.is_empty() and not _run_techniques_acquired.has(bought_id):
					_run_techniques_acquired.append(bought_id)
			if bool(result.get("open_forget", false)):
				_shop_items.remove_at(_shop_selection_idx)
				_shop_selection_idx = mini(_shop_selection_idx, maxi(_shop_items.size() - 1, 0))
				_forget_selection_idx = 0
				_current_scene = SceneType.FORGET_TECHNIQUE
				return
			_shop_items.remove_at(_shop_selection_idx)
			_shop_selection_idx = mini(_shop_selection_idx, maxi(_shop_items.size() - 1, 0))

func _update_rest() -> void:
	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_rest_choice_idx = maxi(0, _rest_choice_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_rest_choice_idx = mini(1, _rest_choice_idx + 1)

	if _accept_pressed():
		if _rest_choice_idx == 0:
			_player.health_current = minf(_player.health_current + _player.health_max * 0.4, _player.health_max)
			_run_state.mark_current_node_cleared()
			_current_scene = SceneType.MAP
		else:
			if _player.technique_engine != null and not _player.technique_engine.technique_ids().is_empty():
				_forget_selection_idx = 0
				_current_scene = SceneType.FORGET_TECHNIQUE
			else:
				_run_state.mark_current_node_cleared()
				_current_scene = SceneType.MAP

func _update_forget_technique() -> void:
	if _player.technique_engine == null:
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	var technique_ids: Array[String] = _player.technique_engine.technique_ids()
	if technique_ids.is_empty():
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _input_tracker.pressed_key(KEY_W) or _input_tracker.pressed_key(KEY_UP):
		_forget_selection_idx = maxi(0, _forget_selection_idx - 1)
	if _input_tracker.pressed_key(KEY_S) or _input_tracker.pressed_key(KEY_DOWN):
		_forget_selection_idx = mini(technique_ids.size() - 1, _forget_selection_idx + 1)

	if _input_tracker.pressed_key(KEY_Q) or _input_tracker.pressed_key(KEY_ESCAPE):
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP
		return

	if _accept_pressed() and _forget_selection_idx >= 0 and _forget_selection_idx < technique_ids.size():
		var remove_id: String = technique_ids[_forget_selection_idx]
		_player.technique_engine.remove(remove_id, _player)
		_run_state.mark_current_node_cleared()
		_current_scene = SceneType.MAP

func _update_victory() -> void:
	if _accept_pressed() or _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		_current_scene = SceneType.MAIN_MENU

func _update_game_over() -> void:
	if _accept_pressed() or _input_tracker.pressed_mouse(MOUSE_BUTTON_LEFT):
		_current_scene = SceneType.MAIN_MENU

func _travel_to_node(chosen: MapNode) -> void:
	_run_state.advance_to(chosen.id)
	_map_selection_idx = 0

	match chosen.node_type:
		MapNode.NodeType.BATTLE, MapNode.NodeType.ELITE:
			_combat_gold_multiplier = 1
			_setup_combat_for_node(chosen)
		MapNode.NodeType.AMBUSH:
			if chosen.ambush_remaining <= 0:
				chosen.ambush_remaining = 3
			_combat_gold_multiplier = 1
			_setup_combat_for_node(chosen)
		MapNode.NodeType.BOSS:
			_combat_gold_multiplier = 1
			_setup_combat_for_node(chosen)
		MapNode.NodeType.EVENT:
			var event_data: Dictionary = {}
			if not chosen.event_id.is_empty():
				event_data = DataManager.get_event_by_id(chosen.event_id)
			if event_data.is_empty():
				event_data = DataManager.get_random_event()
				chosen.event_id = str(event_data.get("id", ""))
			if event_data.is_empty():
				_run_state.mark_current_node_cleared()
				return
			_event_data = event_data.duplicate(true)
			_event_runner = EventRunnerScript.new()
			_event_runner.load_event(_event_data)
			_event_choices = _event_runner.get_choices()
			_event_choice_idx = 0
			_event_result.clear()
			_event_showing_result = false
			_shop_message = ""
			_shop_message_timer = 0.0
			_current_scene = SceneType.EVENT
		MapNode.NodeType.SHOP:
			var owned_ids: Array[String] = []
			if _player.technique_engine != null:
				owned_ids = _player.technique_engine.technique_ids()
			_shop_items = ShopGeneratorScript.generate_shop(owned_ids)
			_shop_selection_idx = 0
			_shop_message = ""
			_shop_message_timer = 0.0
			_current_scene = SceneType.SHOP
		MapNode.NodeType.REST:
			_rest_choice_idx = 0
			_current_scene = SceneType.REST
		MapNode.NodeType.MASTER:
			_rewards = _generate_master_rewards()
			_reward_selection_idx = 0
			if _rewards.is_empty():
				_run_state.mark_current_node_cleared()
				_current_scene = SceneType.MAP
			else:
				_current_scene = SceneType.REWARD

func _generate_technique_rewards(count: int) -> Array:
	var owned_ids: Array[String] = []
	if _player.technique_engine != null:
		owned_ids = _player.technique_engine.technique_ids()
	var rewards: Array = []
	var used_ids: Array[String] = owned_ids.duplicate()
	for i in range(count):
		var reward: RewardOption = RewardOption.random_technique(used_ids)
		rewards.append(reward)
		if reward.technique_id != "":
			used_ids.append(reward.technique_id)
	return rewards

func _generate_master_rewards() -> Array:
	var owned_ids: Array[String] = []
	if _player.technique_engine != null:
		owned_ids = _player.technique_engine.technique_ids()
	var rewards: Array = []
	var all_techniques: Dictionary = DataManager.get_all_techniques()
	var rare_pool: Array[Dictionary] = []
	for tech_id in all_techniques.keys():
		var tech_id_str: String = str(tech_id)
		if owned_ids.has(tech_id_str):
			continue
		var technique: Dictionary = all_techniques[tech_id] as Dictionary
		if int(technique.get("rarity", 1)) >= 2:
			rare_pool.append(technique)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(3):
		if rare_pool.is_empty():
			break
		var idx: int = rng.randi_range(0, rare_pool.size() - 1)
		var pick: Dictionary = rare_pool[idx]
		rare_pool.remove_at(idx)
		var option: RewardOption = RewardOption.new()
		option.id = str(pick.get("id", ""))
		option.label = "%s (%s)" % [str(pick.get("name_en", "")), str(pick.get("name_cn", ""))]
		option.effect = "technique"
		option.technique_id = option.id
		rewards.append(option)
	return rewards

func _resolve_event_choice(index: int) -> void:
	_event_result = _event_runner.choose(index, _player)
	if bool(_event_result.get("blocked", false)):
		_shop_message = str(_event_result.get("message", "Cannot do that."))
		_shop_message_timer = 1.5
		_event_result.clear()
		_event_showing_result = false
		if not _event_data.is_empty():
			_event_runner.load_event(_event_data)
			_event_choices = _event_runner.get_choices()
		return
	if bool(_event_result.get("timing_test", false)):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		var passed_test: bool = rng.randf() < 0.5
		_event_result = _event_runner.apply_timing_result(passed_test, _player)
	_event_showing_result = true
	var granted: String = str(_event_result.get("granted_technique", ""))
	if not granted.is_empty() and not _run_techniques_acquired.has(granted):
		_run_techniques_acquired.append(granted)

func _apply_reward_by_index(index: int) -> void:
	if index < 0 or index >= _rewards.size():
		return
	var selected: RewardOption = _rewards[index]
	selected.apply(_player)
	if selected.technique_id != "" and not _run_techniques_acquired.has(selected.technique_id):
		_run_techniques_acquired.append(selected.technique_id)
	_run_state.mark_current_node_cleared()
	_rewards.clear()
	_reward_selection_idx = 0
	_current_scene = SceneType.MAP

func _on_combat_end(victory: bool) -> void:
	_combat_scene.on_exit()
	_combat_scene.deactivate()

	if victory:
		var base_gold: int = 15
		var node: MapNode = _run_state.get_current_node()
		if node != null:
			match node.node_type:
				MapNode.NodeType.ELITE:
					base_gold = 30
				MapNode.NodeType.AMBUSH:
					base_gold = 10
				MapNode.NodeType.BOSS:
					base_gold = 0
		var gold_gained: int = base_gold * _combat_gold_multiplier
		_player.gold += gold_gained
		_run_gold_earned += gold_gained

		if node != null and node.node_type == MapNode.NodeType.AMBUSH:
			node.ambush_remaining -= 1
			if node.ambush_remaining > 0:
				_setup_combat_for_node(node)
				return

		_run_state.mark_current_node_cleared()
		if node != null and node.node_type == MapNode.NodeType.BOSS:
			_run_end_time = Time.get_ticks_msec() / 1000.0
			_current_scene = SceneType.VICTORY
		else:
			_current_scene = SceneType.REWARD
	else:
		_run_end_time = Time.get_ticks_msec() / 1000.0
		_current_scene = SceneType.GAME_OVER
		_end_message = "Defeated"

func _setup_combat_for_node(node: MapNode) -> void:
	var show_controls_legend: bool = false
	if _run_state != null and not _run_state.legend_seen_this_run:
		show_controls_legend = true
		_run_state.legend_seen_this_run = true
	_combat_scene.setup_combat(_player, node, show_controls_legend)
	_combat_scene.on_enter()
	_current_scene = SceneType.COMBAT

func _draw() -> void:
	match _current_scene:
		SceneType.MAIN_MENU:
			_draw_main_menu()
		SceneType.MAP:
			_draw_map()
		SceneType.COMBAT:
			pass
		SceneType.REWARD:
			_draw_reward()
		SceneType.EVENT:
			_draw_event()
		SceneType.SHOP:
			_draw_shop()
		SceneType.REST:
			_draw_rest()
		SceneType.FORGET_TECHNIQUE:
			_draw_forget_technique()
		SceneType.VICTORY:
			_draw_victory()
		SceneType.GAME_OVER:
			_draw_game_over()

func _draw_main_menu() -> void:
	_draw_background()
	_draw_bamboo_silhouettes(float(GameConstants.VIEW_HEIGHT) - 32.0, 0.55)
	_draw_scene_frame(48.0)

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var title_y: float = float(GameConstants.VIEW_HEIGHT) * 0.36
	var title_panel: Rect2 = Rect2(center_x - 360.0, title_y - 150.0, 720.0, 340.0)
	_draw_panel(title_panel)

	_draw_centered_text("武", center_x, title_y, GameConstants.COLOR_TEXT_HEADING, 200, true)
	_draw_centered_text("WU", center_x, title_y + 94.0, GameConstants.COLOR_TEXT_SUBHEADING, 42, true)
	_draw_centered_text("The Wanderer Emerges", center_x, title_y + 150.0, GameConstants.COLOR_TEXT_BODY, 22)
	_draw_centered_text("A Sekiro-paced wuxia duel roguelike", center_x, title_y + 184.0, GameConstants.COLOR_TEXT_HINT, 17)

	var prompt_pulse: float = 0.55 + 0.45 * sin(_cursor_flash * 4.0)
	_draw_centered_text(
		"Press Enter to begin",
		center_x,
		float(GameConstants.VIEW_HEIGHT) * 0.89,
		Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, prompt_pulse),
		24
	)
	_draw_centered_text("第一章 江湖", center_x, float(GameConstants.VIEW_HEIGHT) - 78.0, GameConstants.COLOR_TEXT_BODY, 18, true)
	_draw_centered_text("Bamboo roads, wandering blades, and a debt still unpaid", center_x, float(GameConstants.VIEW_HEIGHT) - 48.0, GameConstants.COLOR_TEXT_HINT, 15)

func _draw_map() -> void:
	_draw_background()
	_draw_map_wash()
	_draw_bamboo_silhouettes(float(GameConstants.VIEW_HEIGHT) - 6.0, 0.38)

	var next_nodes: Array[MapNode] = _run_state.get_available_next()
	var tiers: int = _run_state.max_tier + 1
	var top: int = 180
	var bottom: int = GameConstants.VIEW_HEIGHT - 200
	var tier_height: int = int((bottom - top) / maxi(1, tiers - 1))

	for node in _run_state.nodes:
		for to_id in node.next_ids:
			var target: MapNode = _run_state.get_node(to_id)
			if target == null:
				continue
			var from_pos: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
			var to_pos: Vector2 = _get_map_node_position(target, tiers, top, tier_height)
			var base_color: Color = Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.28)
			var brush_color: Color = Color(GameConstants.COLOR_TEXT_HINT.r, GameConstants.COLOR_TEXT_HINT.g, GameConstants.COLOR_TEXT_HINT.b, 0.12)
			var normal: Vector2 = (to_pos - from_pos).normalized().orthogonal() * 2.0
			draw_line(from_pos, to_pos, base_color, 4.0)
			draw_line(from_pos + normal, to_pos + normal, brush_color, 2.0)
			draw_line(from_pos - normal * 0.5, to_pos - normal * 0.5, brush_color, 1.0)

	for node in _run_state.nodes:
		var pos: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
		var node_color: Color = _get_node_color(node.node_type)
		if node.cleared:
			node_color = node_color.darkened(0.55)
		draw_circle(pos, 22.0, Color(node_color.r, node_color.g, node_color.b, 0.14))
		draw_circle(pos, 12.0, node_color)
		draw_circle(pos, 5.0, Color(GameConstants.COLOR_SCROLL_WHITE.r, GameConstants.COLOR_SCROLL_WHITE.g, GameConstants.COLOR_SCROLL_WHITE.b, 0.5))

		if next_nodes.has(node):
			var idx: int = next_nodes.find(node)
			if idx == _map_selection_idx:
				var ring_pulse: float = 2.0 + sin(_cursor_flash * 6.0) * 1.5
				draw_arc(pos, 22.0 + ring_pulse, 0.0, TAU, 48, GameConstants.COLOR_PANEL_ACCENT, 3.0, true)
				draw_arc(pos, 30.0 + ring_pulse, 0.0, TAU, 48, Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.22), 2.0, true)
				_draw_menu_cursor(pos + Vector2(-34.0, 6.0))

	var header: Rect2 = Rect2(42.0, 34.0, float(GameConstants.VIEW_WIDTH) - 84.0, 92.0)
	_draw_panel(header)
	_draw_text("江湖", 74.0, 78.0, GameConstants.COLOR_TEXT_HEADING, 32, true)
	_draw_text("Path Select", 144.0, 78.0, GameConstants.COLOR_TEXT_SUBHEADING, 20)
	_draw_text("Gold: %d" % _player.gold, GameConstants.VIEW_WIDTH - 220.0, 78.0, GameConstants.COLOR_TEXT_ACCENT, 22)
	_draw_text("Arrows / A-D to move · Enter / J or click to travel", 74.0, 106.0, GameConstants.COLOR_TEXT_BODY, 16)

	if not next_nodes.is_empty():
		var selected_node: MapNode = next_nodes[_map_selection_idx]
		var selected_label: String = _get_node_type_label(selected_node.node_type)
		var footer: Rect2 = Rect2(42.0, float(GameConstants.VIEW_HEIGHT) - 116.0, float(GameConstants.VIEW_WIDTH) - 84.0, 64.0)
		_draw_panel(footer)
		_draw_text("Selected Route", footer.position.x + 26.0, footer.position.y + 34.0, GameConstants.COLOR_TEXT_HINT, 15)
		_draw_text(selected_label, footer.position.x + 26.0, footer.position.y + 56.0, GameConstants.COLOR_TEXT_HEADING, 22)
		_draw_text("Branches narrow after the master's gate and rest shrine.", footer.end.x - 420.0, footer.position.y + 46.0, GameConstants.COLOR_TEXT_BODY, 15)

func _draw_reward() -> void:
	_draw_background()
	_draw_modal_backdrop()

	var panel: Rect2 = _get_reward_panel_rect()
	_draw_panel(panel)
	var header_bar: Rect2 = Rect2(panel.position.x + 18.0, panel.position.y + 18.0, panel.size.x - 36.0, 54.0)
	draw_rect(header_bar, Color(GameConstants.COLOR_GOLD_DARK.r, GameConstants.COLOR_GOLD_DARK.g, GameConstants.COLOR_GOLD_DARK.b, 0.28), true)
	draw_rect(header_bar, Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.8), false, 1.0)
	_draw_text("得技", header_bar.position.x + 18.0, header_bar.position.y + 28.0, GameConstants.COLOR_TEXT_HEADING, 24, true)
	_draw_text("Technique Acquired", header_bar.position.x + 18.0, header_bar.position.y + 48.0, GameConstants.COLOR_TEXT_BODY, 17)
	_draw_text("Arrows, 1/2/3, Enter or click", panel.position.x + 26.0, panel.position.y + 92.0, GameConstants.COLOR_TEXT_HINT, 15)

	for i in range(_rewards.size()):
		var box: Rect2 = _get_reward_box_rect(i)
		var reward_label: String = "..."
		var reward_desc: String = ""
		if i < _rewards.size():
			reward_label = _rewards[i].label
			if _rewards[i].technique_id != "":
				var tech_data: Dictionary = DataManager.get_technique(_rewards[i].technique_id)
				reward_desc = str(tech_data.get("description", ""))
		_draw_reward_option_with_desc(box, reward_label, reward_desc, _reward_selection_idx == i)

func _draw_event() -> void:
	_draw_background()
	_draw_modal_backdrop()
	var panel: Rect2 = Rect2(360.0, 186.0, float(GameConstants.VIEW_WIDTH) - 720.0, 420.0 if _event_showing_result else 500.0)
	_draw_panel(panel)

	if _event_runner == null:
		return

	var title: String = _event_runner.get_title()
	var title_cn: String = _event_runner.get_title_cn()
	if not title_cn.is_empty():
		title = "%s %s" % [title_cn, title]
	_draw_text(title, panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)
	draw_rect(Rect2(panel.position.x + 32.0, panel.position.y + 64.0, panel.size.x - 64.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.55))
	var body_bottom: float = _draw_text_block(_event_runner.get_text(), panel.position.x + 32.0, panel.position.y + 106.0, panel.size.x - 64.0, 28.0, GameConstants.COLOR_TEXT_BODY, 18)

	if _event_showing_result:
		_draw_text_block(str(_event_result.get("message", "")), panel.position.x + 32.0, body_bottom + 34.0, panel.size.x - 64.0, 30.0, GameConstants.COLOR_TEXT_ACCENT, 19)
		_draw_text("Press Enter to continue", panel.position.x + 32.0, panel.end.y - 34.0, GameConstants.COLOR_TEXT_HINT, 15)
	else:
		var y: float = body_bottom + 36.0
		for i in range(_event_choices.size()):
			var choice: Dictionary = _event_choices[i]
			var label: String = "%d. %s" % [i + 1, str(choice.get("label", "..."))]
			var row: Rect2 = Rect2(panel.position.x + 20.0, y - 24.0, panel.size.x - 40.0, 44.0)
			var selected: bool = i == _event_choice_idx
			draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.72), true)
			draw_rect(row, GameConstants.COLOR_PANEL_ACCENT if selected else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.5), false, 1.0)
			var color: Color = GameConstants.COLOR_TEXT_HEADING if selected else GameConstants.COLOR_TEXT_BODY
			if i == _event_choice_idx:
				_draw_menu_cursor(Vector2(panel.position.x + 12.0, y - 2.0))
			_draw_text(label, panel.position.x + 48.0, y + 4.0, color, 18)
			y += 56.0
		if _shop_message_timer > 0.0:
			_draw_text(_shop_message, panel.position.x + 32.0, panel.end.y - 62.0, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.95), 16)
		_draw_text("W/S or 1-3 to choose, Enter to confirm", panel.position.x + 32.0, panel.end.y - 34.0, GameConstants.COLOR_TEXT_HINT, 15)

func _draw_shop() -> void:
	_draw_background()
	_draw_modal_backdrop()
	var panel: Rect2 = Rect2(300.0, 110.0, float(GameConstants.VIEW_WIDTH) - 600.0, 740.0)
	_draw_panel(panel)
	_draw_text("商鋪 Shop", panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)
	_draw_text("Gold: %d" % _player.gold, panel.end.x - 180.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_ACCENT, 24)
	draw_rect(Rect2(panel.position.x + 32.0, panel.position.y + 64.0, panel.size.x - 64.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.55))

	var y: float = panel.position.y + 114.0
	for i in range(_shop_items.size()):
		var item: Dictionary = _shop_items[i]
		var label: String = str(item.get("label", "???"))
		var price: int = int(item.get("price", 0))
		var desc: String = str(item.get("description", ""))
		var can_afford: bool = _player.gold >= price
		var selected: bool = i == _shop_selection_idx
		var row: Rect2 = Rect2(panel.position.x + 24.0, y - 28.0, panel.size.x - 48.0, 70.0)
		var text_color: Color = GameConstants.COLOR_TEXT_HEADING if selected else GameConstants.COLOR_TEXT_BODY
		var price_color: Color = GameConstants.COLOR_TEXT_ACCENT if can_afford else Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.8)
		draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.76), true)
		draw_rect(row, GameConstants.COLOR_PANEL_ACCENT if selected else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.42), false, 1.0)
		if not can_afford:
			text_color = GameConstants.COLOR_TEXT_DISABLED
		if selected:
			_draw_menu_cursor(Vector2(panel.position.x + 16.0, y - 2.0))
		_draw_text(label, panel.position.x + 52.0, y + 2.0, text_color, 19)
		if not can_afford:
			var chip_rect: Rect2 = Rect2(row.end.x - 214.0, y - 18.0, 92.0, 24.0)
			draw_rect(chip_rect, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.16), true)
			draw_rect(chip_rect, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.75), false, 1.0)
			_draw_text("Need Gold", chip_rect.position.x + 10.0, chip_rect.position.y + 17.0, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.95), 13)
		_draw_text("%dg" % price, row.end.x - 88.0, y + 2.0, price_color, 20)
		_draw_text(desc, panel.position.x + 52.0, y + 28.0, GameConstants.COLOR_TEXT_HINT if can_afford else GameConstants.COLOR_TEXT_DISABLED, 14)
		y += 82.0

	if _shop_message_timer > 0.0:
		_draw_text(_shop_message, panel.position.x + 32.0, panel.end.y - 58.0, GameConstants.COLOR_TEXT_ACCENT, 17)
	_draw_text("W/S to browse, Enter to buy, Q or Esc to leave", panel.position.x + 32.0, panel.end.y - 28.0, GameConstants.COLOR_TEXT_HINT, 15)

func _draw_rest() -> void:
	_draw_background()
	_draw_modal_backdrop()
	var panel: Rect2 = Rect2(520.0, 260.0, float(GameConstants.VIEW_WIDTH) - 1040.0, 280.0)
	_draw_panel(panel)
	_draw_text("歇息 Rest Site", panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)
	_draw_text("HP: %d/%d" % [int(round(_player.health_current)), int(round(_player.health_max))], panel.position.x + 32.0, panel.position.y + 78.0, GameConstants.COLOR_TEXT_BODY, 18)

	var can_remove: bool = _player.technique_engine != null and not _player.technique_engine.technique_ids().is_empty()
	var choices: Array[String] = ["Heal (40% max HP)", "Remove a technique"]
	var choice_hints: Array[String] = [
		"Recover and steady yourself before the next road.",
		"Forget one technique and lighten the loadout."
	]
	var y: float = panel.position.y + 126.0
	for i in range(choices.size()):
		var row: Rect2 = Rect2(panel.position.x + 20.0, y - 28.0, panel.size.x - 40.0, 64.0)
		var selected: bool = i == _rest_choice_idx
		var enabled: bool = i == 0 or can_remove
		var border_color: Color = GameConstants.COLOR_PANEL_ACCENT if selected and enabled else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.5)
		var label_color: Color = GameConstants.COLOR_TEXT_HEADING if enabled else GameConstants.COLOR_TEXT_DISABLED
		var hint_color: Color = GameConstants.COLOR_TEXT_HINT if enabled else GameConstants.COLOR_TEXT_DISABLED
		draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.76), true)
		draw_rect(row, border_color, false, 1.0)
		if selected:
			_draw_menu_cursor(Vector2(panel.position.x + 12.0, y))
		_draw_text(choices[i], panel.position.x + 48.0, y + 2.0, label_color, 19)
		_draw_text(choice_hints[i], panel.position.x + 48.0, y + 26.0, hint_color, 14)
		if not enabled:
			var chip_rect: Rect2 = Rect2(row.end.x - 84.0, y - 18.0, 64.0, 24.0)
			draw_rect(chip_rect, Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.18), true)
			draw_rect(chip_rect, Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.65), false, 1.0)
			_draw_text("Locked", chip_rect.position.x + 10.0, chip_rect.position.y + 17.0, GameConstants.COLOR_TEXT_HINT, 13)
			draw_line(Vector2(panel.position.x + 48.0, y - 6.0), Vector2(panel.position.x + 232.0, y - 6.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.75), 1.0)
		y += 74.0
	_draw_text("W/S to choose, Enter to confirm", panel.position.x + 32.0, panel.end.y - 28.0, GameConstants.COLOR_TEXT_HINT, 15)

func _draw_forget_technique() -> void:
	_draw_background()
	_draw_modal_backdrop()
	var technique_count: int = 0
	if _player.technique_engine != null:
		technique_count = _player.technique_engine.technique_ids().size()
	var panel_height: float = clampf(210.0 + float(technique_count) * 72.0, 320.0, 560.0)
	var panel: Rect2 = Rect2(420.0, (float(GameConstants.VIEW_HEIGHT) - panel_height) * 0.5, float(GameConstants.VIEW_WIDTH) - 840.0, panel_height)
	_draw_panel(panel)
	_draw_text("忘招 Forget Technique", panel.position.x + 32.0, panel.position.y + 48.0, GameConstants.COLOR_TEXT_HEADING, 28, true)

	if _player.technique_engine == null:
		return
	var technique_ids: Array[String] = _player.technique_engine.technique_ids()
	var y: float = panel.position.y + 100.0
	for i in range(technique_ids.size()):
		var tech_data: Dictionary = DataManager.get_technique(technique_ids[i])
		var display: String = "%s %s" % [str(tech_data.get("name_cn", technique_ids[i])), str(tech_data.get("name_en", ""))]
		var desc: String = str(tech_data.get("description", ""))
		var selected: bool = i == _forget_selection_idx
		var row: Rect2 = Rect2(panel.position.x + 20.0, y - 28.0, panel.size.x - 40.0, 62.0)
		var color: Color = GameConstants.COLOR_VERMILLION_RED if selected else GameConstants.COLOR_TEXT_BODY
		draw_rect(row, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.76), true)
		draw_rect(row, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.9) if selected else Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.42), false, 1.0)
		if selected:
			_draw_menu_cursor(Vector2(panel.position.x + 12.0, y))
		_draw_text(display, panel.position.x + 48.0, y + 2.0, color, 18)
		_draw_text(desc, panel.position.x + 48.0, y + 26.0, GameConstants.COLOR_TEXT_HINT, 14)
		y += 72.0
	_draw_text("W/S to browse, Enter to forget, Q or Esc to cancel", panel.position.x + 32.0, panel.end.y - 28.0, GameConstants.COLOR_TEXT_HINT, 15)

func _draw_victory() -> void:
	_draw_background()
	_draw_modal_backdrop()

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var scroll: Rect2 = Rect2(center_x - 340.0, 80.0, 680.0, float(GameConstants.VIEW_HEIGHT) - 160.0)
	draw_rect(scroll, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 240.0 / 255.0), true)
	var gold: Color = GameConstants.COLOR_IMPERIAL_GOLD
	draw_rect(Rect2(scroll.position.x, scroll.position.y, scroll.size.x, 3.0), gold)
	draw_rect(Rect2(scroll.position.x, scroll.end.y - 3.0, scroll.size.x, 3.0), gold)
	draw_rect(Rect2(scroll.position.x, scroll.position.y, 3.0, scroll.size.y), gold)
	draw_rect(Rect2(scroll.end.x - 3.0, scroll.position.y, 3.0, scroll.size.y), gold)

	var y: float = scroll.position.y + 50.0
	var left: float = scroll.position.x + 40.0

	_draw_centered_text("江湖初顯", center_x, y, GameConstants.COLOR_TEXT_HEADING, 40, true)
	y += 40.0
	_draw_centered_text("The Wanderer Emerges", center_x, y, GameConstants.COLOR_TEXT_SUBHEADING, 19)
	y += 60.0

	draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.4))
	y += 30.0

	var run_duration: float = _run_end_time - _run_start_time
	var minutes: int = int(run_duration) / 60
	var seconds: int = int(run_duration) % 60
	_draw_text("Run Duration", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	_draw_text("%d:%02d" % [minutes, seconds], left + 200.0, y, GameConstants.COLOR_TEXT_HEADING, 16)
	y += 30.0

	var hp_pct: int = int(round(_player.health_current / maxf(_player.health_max, 1.0) * 100.0))
	_draw_text("Final HP", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	_draw_text("%d%%" % hp_pct, left + 200.0, y, GameConstants.COLOR_TEXT_HEADING, 16)
	y += 30.0

	_draw_text("Gold Earned", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	_draw_text("%d" % _run_gold_earned, left + 200.0, y, GameConstants.COLOR_TEXT_ACCENT, 16)
	y += 40.0

	draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.4))
	y += 20.0
	_draw_text("Techniques Acquired", left, y, GameConstants.COLOR_TEXT_CAPTION, 14)
	y += 24.0

	if _run_techniques_acquired.is_empty():
		_draw_text("(none)", left + 20.0, y, GameConstants.COLOR_TEXT_CAPTION, 14)
		y += 20.0
	else:
		for tech_id in _run_techniques_acquired:
			var tech_data: Dictionary = DataManager.get_technique(tech_id)
			var cn: String = str(tech_data.get("name_cn", ""))
			var en: String = str(tech_data.get("name_en", tech_id))
			_draw_text("%s %s" % [cn, en], left + 20.0, y, GameConstants.COLOR_TEXT_BODY, 15)
			y += 22.0

	y = scroll.end.y - 80.0
	draw_rect(Rect2(left, y, scroll.size.x - 80.0, 1.0), Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.4))
	y += 20.0
	_draw_text("The road beyond the bamboo leads deeper into the jianghu...", left, y, GameConstants.COLOR_TEXT_BODY, 15, true)

	var pulse: float = 0.775 + 0.225 * sin(_cursor_flash * 4.0)
	_draw_centered_text("Press Enter to return", center_x, scroll.end.y - 28.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, pulse), 18)

func _draw_game_over() -> void:
	_draw_background()
	_draw_modal_backdrop()

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var center_y: float = float(GameConstants.VIEW_HEIGHT) * 0.5
	var panel: Rect2 = Rect2(center_x - 260.0, center_y - 150.0, 520.0, 260.0)
	_draw_panel(panel)

	_draw_centered_text("敗", center_x, center_y - 48.0, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.88), 78, true)
	_draw_centered_text("Defeated", center_x, center_y + 20.0, Color(GameConstants.COLOR_TEXT_SUBHEADING.r, GameConstants.COLOR_TEXT_SUBHEADING.g, GameConstants.COLOR_TEXT_SUBHEADING.b, 0.92), 24)

	var run_duration: float = _run_end_time - _run_start_time
	var minutes: int = int(run_duration) / 60
	var seconds: int = int(run_duration) % 60
	_draw_centered_text("Time: %d:%02d" % [minutes, seconds], center_x, center_y + 64.0, GameConstants.COLOR_TEXT_BODY, 16)

	var pulse: float = 0.775 + 0.225 * sin(_cursor_flash * 4.0)
	_draw_centered_text("Press Enter to return", center_x, center_y + 96.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, pulse), 18)

func _draw_background() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)
	draw_rect(
		Rect2(0.0, float(GameConstants.VIEW_HEIGHT) * 0.58, GameConstants.VIEW_WIDTH, float(GameConstants.VIEW_HEIGHT) * 0.42),
		Color(GameConstants.COLOR_EARTH_DARK.r, GameConstants.COLOR_EARTH_DARK.g, GameConstants.COLOR_EARTH_DARK.b, 0.32),
		true
	)
	draw_rect(
		Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT),
		GameConstants.COLOR_SCREEN_VIGNETTE,
		true
	)

func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(GameConstants.COLOR_PANEL_BG.r, GameConstants.COLOR_PANEL_BG.g, GameConstants.COLOR_PANEL_BG.b, 0.92), true)
	draw_rect(rect, GameConstants.COLOR_PANEL_BORDER, false, 2.0)
	draw_rect(Rect2(rect.position.x + 2.0, rect.position.y, rect.size.x - 4.0, 1.0), GameConstants.COLOR_PANEL_ACCENT)
	var cm: float = 6.0
	var cc: Color = GameConstants.COLOR_PANEL_BORDER
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.position.y - 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y - cm + 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.end.y - cm + 1.0, 1.0, cm), cc)

func _draw_reward_option_with_desc(rect: Rect2, label: String, description: String, selected: bool) -> void:
	if selected:
		rect.position.y -= 10.0
	var border: Color = Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.3)
	if selected:
		border = GameConstants.COLOR_PANEL_ACCENT
	if selected:
		draw_rect(rect.grow(8.0), Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.10), true)
	draw_rect(rect, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.88), true)
	draw_rect(rect, border, false, 2.0)
	_draw_text(label, rect.position.x + 18.0, rect.position.y + 36.0, GameConstants.COLOR_TEXT_HEADING, 20)
	if description != "":
		_draw_text_block(description, rect.position.x + 18.0, rect.position.y + 66.0, rect.size.x - 36.0, 18.0, GameConstants.COLOR_TEXT_BODY, 14)
	if selected:
		_draw_menu_cursor(Vector2(rect.position.x - 16.0, rect.position.y + 36.0))

func _draw_menu_cursor(position: Vector2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_cursor_flash * 8.0)
	var cursor_color: Color = Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, 0.55 + 0.35 * pulse)
	draw_circle(position, 2.5 + pulse, cursor_color)
	draw_line(position + Vector2(-10.0, -4.0), position + Vector2(-2.0, 0.0), cursor_color, 2.0)
	draw_line(position + Vector2(-10.0, 4.0), position + Vector2(-2.0, 0.0), cursor_color, 2.0)

func _draw_text(text: String, x: float, y: float, color: Color, size: int = 16, display: bool = false) -> void:
	var font: Font = _font_for_size(size, display)
	if font == null:
		return
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _draw_centered_text(text: String, center_x: float, y: float, color: Color, size: int = 16, display: bool = false) -> void:
	var width: float = _measure_text(text, size, display)
	_draw_text(text, center_x - width * 0.5, y, color, size, display)

func _draw_text_block(text: String, x: float, y: float, max_width: float, line_height: float, color: Color, size: int = 16, display: bool = false) -> float:
	var lines: Array[String] = _wrap_text(text, max_width, size, display)
	var cursor_y: float = y
	for line in lines:
		_draw_text(line, x, cursor_y, color, size, display)
		cursor_y += line_height
	return cursor_y

func _font_for_size(size: int, display: bool = false) -> Font:
	if display or size >= 32:
		var display_font: Font = Fonts.display_font()
		if display_font != null:
			return display_font
	var body_font: Font = Fonts.body_font()
	if body_font != null:
		return body_font
	return ThemeDB.fallback_font

func _measure_text(text: String, size: int = 16, display: bool = false) -> int:
	var font: Font = _font_for_size(size, display)
	if font == null:
		return text.length() * size / 2
	return int(round(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x))

func _wrap_text(text: String, max_width: float, size: int = 16, display: bool = false) -> Array[String]:
	var font: Font = _font_for_size(size, display)
	return TextWrappingScript.wrap_lines(font, text, max_width, size)

func _draw_modal_backdrop() -> void:
	draw_rect(
		Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT),
		Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.44),
		true
	)

func _draw_scene_frame(margin: float) -> void:
	var cm: float = 12.0
	var cc: Color = Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.7)
	var w: float = float(GameConstants.VIEW_WIDTH)
	var h: float = float(GameConstants.VIEW_HEIGHT)
	draw_rect(Rect2(margin, margin, cm, 1.0), cc)
	draw_rect(Rect2(margin, margin, 1.0, cm), cc)
	draw_rect(Rect2(w - margin - cm, margin, cm, 1.0), cc)
	draw_rect(Rect2(w - margin - 1.0, margin, 1.0, cm), cc)
	draw_rect(Rect2(margin, h - margin - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(margin, h - margin - cm, 1.0, cm), cc)
	draw_rect(Rect2(w - margin - cm, h - margin - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(w - margin - 1.0, h - margin - cm, 1.0, cm), cc)

func _draw_bamboo_silhouettes(base_y: float, opacity: float) -> void:
	var pan_offset: float = fmod(_cursor_flash * 8.0, 82.0)
	for i in range(26):
		var x: float = -54.0 - pan_offset + float(i) * 82.0 + float((i * 37) % 19)
		var height: float = 170.0 + float((i * 29) % 150)
		var width: float = 8.0 + float(i % 3) * 2.0
		var stalk_color: Color = Color(GameConstants.COLOR_MOUNTAIN_BLUE.r, GameConstants.COLOR_MOUNTAIN_BLUE.g, GameConstants.COLOR_MOUNTAIN_BLUE.b, opacity)
		draw_rect(Rect2(x, base_y - height, width, height), stalk_color, true)
		for node in range(1, 6):
			var node_y: float = base_y - height + float(node) * (height / 6.0)
			draw_rect(Rect2(x - 1.0, node_y, width + 2.0, 2.0), Color(GameConstants.COLOR_LIGHT_BLUE.r, GameConstants.COLOR_LIGHT_BLUE.g, GameConstants.COLOR_LIGHT_BLUE.b, opacity * 0.18), true)
		for leaf in range(3):
			var leaf_y: float = base_y - height * (0.34 + float(leaf) * 0.18)
			var dir: float = -1.0 if ((i + leaf) % 2 == 0) else 1.0
			var leaf_color: Color = Color(GameConstants.COLOR_JADE_DARK.r, GameConstants.COLOR_JADE_DARK.g, GameConstants.COLOR_JADE_DARK.b, opacity * 0.78)
			draw_line(Vector2(x + width * 0.5, leaf_y), Vector2(x + width * 0.5 + dir * 34.0, leaf_y - 16.0), leaf_color, 2.0)
			draw_line(Vector2(x + width * 0.5, leaf_y + 6.0), Vector2(x + width * 0.5 + dir * 24.0, leaf_y + 18.0), leaf_color, 2.0)

func _draw_map_wash() -> void:
	var wash_color: Color = Color(GameConstants.COLOR_MOUNTAIN_BLUE.r, GameConstants.COLOR_MOUNTAIN_BLUE.g, GameConstants.COLOR_MOUNTAIN_BLUE.b, 0.16)
	draw_circle(Vector2(420.0, 360.0), 220.0, wash_color)
	draw_circle(Vector2(960.0, 430.0), 300.0, Color(GameConstants.COLOR_EARTH_DARK.r, GameConstants.COLOR_EARTH_DARK.g, GameConstants.COLOR_EARTH_DARK.b, 0.18))
	draw_circle(Vector2(1500.0, 320.0), 260.0, wash_color)
	draw_rect(Rect2(0.0, float(GameConstants.VIEW_HEIGHT) - 240.0, GameConstants.VIEW_WIDTH, 240.0), Color(GameConstants.COLOR_EARTH_DARK.r, GameConstants.COLOR_EARTH_DARK.g, GameConstants.COLOR_EARTH_DARK.b, 0.28), true)

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
	var top: int = 180
	var bottom: int = GameConstants.VIEW_HEIGHT - 200
	var tier_height: int = int((bottom - top) / maxi(1, tiers - 1))

	for i in range(next_nodes.size()):
		var node: MapNode = next_nodes[i]
		var pos: Vector2 = _get_map_node_position(node, tiers, top, tier_height)
		if mouse_pos.distance_to(pos) <= 22.0:
			return i
	return -1

func _get_reward_panel_rect() -> Rect2:
	var width: float = minf(1200.0, float(GameConstants.VIEW_WIDTH) - 200.0)
	var height: float = 300.0
	return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - height) * 0.5 - 20.0, width, height)

func _get_reward_box_rect(index: int) -> Rect2:
	var panel: Rect2 = _get_reward_panel_rect()
	var count: int = maxi(_rewards.size(), 1)
	var gap: float = 20.0
	var box_width: float = (panel.size.x - gap * float(count + 1)) / float(count)
	var box_height: float = 150.0
	var x: float = panel.position.x + gap + float(index) * (box_width + gap)
	var y: float = panel.position.y + 118.0
	return Rect2(x, y, box_width, box_height)

func _get_hovered_reward_index() -> int:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	for i in range(_rewards.size()):
		var box: Rect2 = _get_reward_box_rect(i)
		if box.has_point(mouse_pos):
			return i
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
			return GameConstants.COLOR_MISTY_BLUE
		MapNode.NodeType.ELITE:
			return GameConstants.COLOR_EARTH_LIGHT
		MapNode.NodeType.AMBUSH:
			return GameConstants.COLOR_VERMILLION_RED
		MapNode.NodeType.MASTER:
			return GameConstants.COLOR_PURPLE_MID
		MapNode.NodeType.EVENT:
			return GameConstants.COLOR_LIGHT_BLUE
		MapNode.NodeType.SHOP:
			return GameConstants.COLOR_GOLD_BRIGHT
		MapNode.NodeType.REST:
			return GameConstants.COLOR_JADE_GREEN
		MapNode.NodeType.BOSS:
			return GameConstants.COLOR_CRIMSON
		_:
			return GameConstants.COLOR_PAPER

func _get_node_type_label(node_type: int) -> String:
	match node_type:
		MapNode.NodeType.BATTLE:
			return "Duel"
		MapNode.NodeType.ELITE:
			return "Elite Duel"
		MapNode.NodeType.AMBUSH:
			return "Ambush"
		MapNode.NodeType.MASTER:
			return "Master"
		MapNode.NodeType.EVENT:
			return "Event"
		MapNode.NodeType.SHOP:
			return "Shop"
		MapNode.NodeType.REST:
			return "Rest"
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
		KEY_W,
		KEY_S,
		KEY_Q,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_UP,
		KEY_DOWN,
		KEY_ENTER,
		KEY_KP_ENTER,
		KEY_SPACE,
		KEY_J,
		KEY_1,
		KEY_2,
		KEY_3,
		KEY_KP_1,
		KEY_KP_2,
		KEY_KP_3,
	]
	_input_tracker.sync_keys(keys)
	_input_tracker.sync_mouse_buttons([MOUSE_BUTTON_LEFT])
