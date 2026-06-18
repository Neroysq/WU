extends Node2D

const DEV_SHOT_COMBAT_FLAG: String = "--shot-combat"
const DEV_SHOT_ACTION_FLAG: String = "--shot-action"
const DEV_SHOT_DIR_PREFIX: String = "--shot-dir="
const DEV_SHOT_ARCHETYPE_PREFIX: String = "--shot-archetype="
const DEV_SHOT_STATE_PREFIX: String = "--shot-state="
const DEV_SHOT_DEFAULT_DIR: String = "user://shot-combat"

const _ACTION_CAPTURE := {
	"ATTACKING_LIGHT": {"prep": "attack_light_full", "frames": 32, "loop": false},
	"ATTACKING_HEAVY": {"prep": "attack_heavy_full", "frames": 50, "loop": false},
	"COMBAT_ENTRY": {"prep": "entry_draw", "frames": 112, "loop": false},
	"IDLE": {"prep": "01_idle", "frames": 192, "loop": true},
	"WALKING": {"prep": "02_walk", "frames": 36, "loop": true, "physics": true},
	"BLOCKING": {"prep": "08_block", "frames": 36, "loop": false},
	"HIT_REACTION": {"prep": "09_hit_react", "frames": 24, "loop": false},
	"STUNNED": {"prep": "10_stunned", "frames": 90, "loop": true},
	"DASHING": {"prep": "11_dash", "frames": 20, "loop": false, "physics": true},
	"JUMPING": {"prep": "12_jump", "frames": 40, "loop": false, "physics": true},
}

@onready var _combat_scene: CombatScene = $CombatScene

var _current_scene: int = SceneContext.SCENE_MAIN_MENU
var _ctx: SceneContext = SceneContext.new()
var _controllers: Dictionary = {}
var _input_tracker: InputTracker = InputTracker.new()
var _dev_shot_combat_dir: String = ""
var _dev_shot_archetype: String = ""
var _dev_shot_action_state: String = ""

func _ready() -> void:
	Engine.max_fps = GameConstants.TARGET_FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DataManager.initialize()
	_controllers = _build_controllers()
	_combat_scene.combat_end.connect(_on_combat_end)
	_combat_scene.deactivate()
	_set_scene(SceneContext.SCENE_MAIN_MENU)
	queue_redraw()
	_sync_input_tracker()
	if _has_user_arg(DEV_SHOT_COMBAT_FLAG):
		_dev_shot_combat_dir = _user_arg_value(DEV_SHOT_DIR_PREFIX, DEV_SHOT_DEFAULT_DIR)
		_dev_shot_archetype = _user_arg_value(DEV_SHOT_ARCHETYPE_PREFIX, "")
		call_deferred("_run_dev_combat_shots")
	elif _has_user_arg(DEV_SHOT_ACTION_FLAG):
		_dev_shot_combat_dir = _user_arg_value(DEV_SHOT_DIR_PREFIX, DEV_SHOT_DEFAULT_DIR)
		_dev_shot_action_state = _user_arg_value(DEV_SHOT_STATE_PREFIX, "ATTACKING_LIGHT")
		call_deferred("_run_dev_action_shots")

func start_new_run() -> void:
	_controllers = _build_controllers()
	_ctx = SceneContext.new()
	_ctx.player = EnemyFactory.create_player()
	_ctx.run_state = RunState.create_procedural_run()
	_ctx.run_state.bind_boon_loadout(_ctx.player.technique_engine, _ctx.player)
	_ctx.run_start_time = Time.get_ticks_msec() / 1000.0
	_ctx.run_end_time = 0.0
	_ctx.run_gold_earned = 0
	_ctx.run_techniques_acquired.clear()
	_ctx.combat_gold_multiplier = 1
	_input_tracker.clear()
	_combat_scene.on_exit()
	_combat_scene.deactivate()
	_set_scene(SceneContext.SCENE_MAP)

func _process(delta: float) -> void:
	_ctx.cursor_flash += delta
	if _ctx.notice_timer > 0.0:
		_ctx.notice_timer -= delta

	if Input.is_key_pressed(KEY_ESCAPE) and (_current_scene == SceneContext.SCENE_MAIN_MENU or _current_scene == SceneContext.SCENE_MAP or _current_scene == SceneContext.SCENE_GAME_OVER):
		get_tree().quit()
		return

	var input: MenuInput = MenuInput.from_tracker(_input_tracker, get_viewport())
	if input.reload_data:
		DataManager.reload_data()

	if input.restart and (_current_scene == SceneContext.SCENE_MAP or _current_scene == SceneContext.SCENE_COMBAT):
		start_new_run()
		_sync_input_tracker()
		queue_redraw()
		return

	if _current_scene != SceneContext.SCENE_COMBAT:
		var controller: Variant = _controllers.get(_current_scene, null)
		if controller != null:
			controller.update(_ctx, input, delta)
			_apply_ctx_transitions()

	_sync_input_tracker()
	queue_redraw()

func _draw() -> void:
	if _current_scene == SceneContext.SCENE_COMBAT:
		return
	var controller: Variant = _controllers.get(_current_scene, null)
	if controller != null:
		controller.draw(_ctx, self)

func _build_controllers() -> Dictionary:
	return {
		SceneContext.SCENE_MAIN_MENU: MenuScene.new(),
		SceneContext.SCENE_MAP: MapScene.new(),
		SceneContext.SCENE_REWARD: RewardScene.new(),
		SceneContext.SCENE_BOON_OFFER: BoonOfferScene.new(),
		SceneContext.SCENE_EVENT: EventScene.new(),
		SceneContext.SCENE_SHOP: ShopScene.new(),
		SceneContext.SCENE_REST: RestScene.new(),
		SceneContext.SCENE_FORGET_TECHNIQUE: ForgetScene.new(),
		SceneContext.SCENE_VICTORY: EndingScene.new(),
		SceneContext.SCENE_GAME_OVER: EndingScene.new(),
	}

func _apply_ctx_transitions() -> void:
	if _ctx.new_run_requested:
		_ctx.clear_transition()
		start_new_run()
		return
	if _ctx.combat_node != null:
		var node: MapNode = _ctx.combat_node
		_ctx.clear_transition()
		_setup_combat_for_node(node)
		return
	if _ctx.next_scene >= 0:
		var scene: int = _ctx.next_scene
		var payload: Dictionary = _ctx.transition_payload.duplicate(true)
		_ctx.clear_transition()
		_set_scene(scene, payload)

func _set_scene(scene: int, payload: Dictionary = {}) -> void:
	_current_scene = scene
	_ctx.current_scene = scene
	var controller: Variant = _controllers.get(scene, null)
	if controller != null:
		controller.enter(_ctx, payload)

func _on_combat_end(victory: bool) -> void:
	_combat_scene.on_exit()
	_combat_scene.deactivate()

	if victory:
		var node: MapNode = _ctx.run_state.get_current_node()
		var outcome: Dictionary = RunFlow.combat_victory_outcome(node, _ctx.combat_gold_multiplier)
		var gold_gained: int = int(outcome.get("gold", 0))
		_ctx.player.gold += gold_gained
		_ctx.run_gold_earned += gold_gained
		_ctx.run_state.insight += int(outcome.get("insight", 0))

		if str(outcome.get("next", "")) == "combat_again":
			_setup_combat_for_node(node)
			return

		_ctx.run_state.mark_current_node_cleared()
		if str(outcome.get("next", "")) == "victory":
			_ctx.run_end_time = Time.get_ticks_msec() / 1000.0
			_set_scene(SceneContext.SCENE_VICTORY)
		elif str(outcome.get("next", "")) == "boon_offer":
			var offer_payload: Dictionary = RunFlow.generate_school_choice_payload(_ctx.run_state, node) if node.node_type == MapNode.NodeType.ELITE else RunFlow.generate_boon_offer_payload(_ctx.run_state, node)
			if (offer_payload.get("offers", []) as Array).is_empty():
				if (offer_payload.get("school_choices", []) as Array).is_empty():
					_set_scene(SceneContext.SCENE_MAP)
				else:
					_set_scene(SceneContext.SCENE_BOON_OFFER, offer_payload)
			else:
				_set_scene(SceneContext.SCENE_BOON_OFFER, offer_payload)
		else:
			_set_scene(SceneContext.SCENE_REWARD)
	else:
		_ctx.run_end_time = Time.get_ticks_msec() / 1000.0
		_ctx.end_message = "Defeated"
		_set_scene(SceneContext.SCENE_GAME_OVER)

func _setup_combat_for_node(node: MapNode) -> void:
	var show_controls_legend: bool = false
	if _ctx.run_state != null and not _ctx.run_state.legend_seen_this_run:
		show_controls_legend = true
		_ctx.run_state.legend_seen_this_run = true
	_combat_scene.setup_combat(_ctx.player, node, show_controls_legend)
	_combat_scene.on_enter()
	_current_scene = SceneContext.SCENE_COMBAT
	_ctx.current_scene = SceneContext.SCENE_COMBAT

func _run_dev_combat_shots() -> void:
	var dir_path: String = _dev_shot_combat_dir if not _dev_shot_combat_dir.is_empty() else DEV_SHOT_DEFAULT_DIR
	var abs_dir: String = ProjectSettings.globalize_path(dir_path) if dir_path.begins_with("user://") or dir_path.begins_with("res://") else dir_path
	var err: int = DirAccess.make_dir_recursive_absolute(abs_dir)
	if err != OK:
		push_error("shot-combat: failed to create %s (err %d)" % [abs_dir, err])
		get_tree().quit(1)
		return

	_ctx = SceneContext.new()
	_ctx.player = EnemyFactory.create_player()
	_ctx.run_state = RunState.create_procedural_run()
	_ctx.run_state.bind_boon_loadout(_ctx.player.technique_engine, _ctx.player)
	_ctx.run_state.legend_seen_this_run = true
	var node_type: int = MapNode.NodeType.BOSS if _dev_shot_archetype == "iron_bear" else MapNode.NodeType.BATTLE
	var node: MapNode = MapNode.new(9001, 1, node_type, [])
	_combat_scene.setup_combat(_ctx.player, node, false, _dev_shot_archetype)
	_combat_scene.on_enter()
	_combat_scene.dev_set_capture_mode(true)
	_current_scene = SceneContext.SCENE_COMBAT
	_ctx.current_scene = SceneContext.SCENE_COMBAT
	queue_redraw()

	await _capture_dev_combat_state("01_idle", abs_dir)
	await _capture_dev_combat_state("02_walk", abs_dir)
	await _capture_dev_combat_state("03_light_windup", abs_dir)
	await _capture_dev_combat_state("04_light_active", abs_dir)
	await _capture_dev_combat_state("05_light_recover", abs_dir)
	await _capture_dev_combat_state("06_heavy_windup", abs_dir)
	await _capture_dev_combat_state("07_heavy_active", abs_dir)
	await _capture_dev_combat_state("08_block", abs_dir)
	await _capture_dev_combat_state("09_hit_react", abs_dir)
	await _capture_dev_combat_state("10_stunned", abs_dir)
	await _capture_dev_combat_state("11_dash", abs_dir)
	await _capture_dev_combat_state("12_jump", abs_dir)
	await _capture_dev_combat_state("13_fall", abs_dir)
	await _capture_dev_combat_state("14_land", abs_dir)
	await _capture_dev_combat_state("15_heavy_recover", abs_dir)
	if not _dev_shot_archetype.is_empty():
		await _capture_dev_combat_state("16_enemy_windup", abs_dir)
		await _capture_dev_combat_state("17_enemy_active", abs_dir)
		await _capture_dev_combat_state("18_neutral_spacing", abs_dir)
	print("SHOT COMBAT: wrote %s" % abs_dir)
	get_tree().quit(0)

func _capture_dev_combat_state(state_name: String, abs_dir: String) -> void:
	_combat_scene.dev_prepare_capture_state(state_name)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [abs_dir.trim_suffix("/"), state_name]
	var err: int = image.save_png(path)
	if err != OK:
		push_error("shot-combat: failed to save %s (err %d)" % [path, err])
	else:
		print("SHOT COMBAT: %s" % path)

func _run_dev_action_shots() -> void:
	var state: String = _dev_shot_action_state
	if not _ACTION_CAPTURE.has(state):
		push_error("shot-action: unknown state %s (known: %s)" % [state, str(_ACTION_CAPTURE.keys())])
		get_tree().quit(1)
		return

	var cfg: Dictionary = _ACTION_CAPTURE[state] as Dictionary
	var dir_path: String = _dev_shot_combat_dir if not _dev_shot_combat_dir.is_empty() else DEV_SHOT_DEFAULT_DIR
	var abs_dir: String = ProjectSettings.globalize_path(dir_path) if dir_path.begins_with("user://") or dir_path.begins_with("res://") else dir_path
	var err: int = DirAccess.make_dir_recursive_absolute(abs_dir)
	if err != OK:
		push_error("shot-action: failed to create %s (err %d)" % [abs_dir, err])
		get_tree().quit(1)
		return

	_ctx = SceneContext.new()
	_ctx.player = EnemyFactory.create_player()
	_ctx.run_state = RunState.create_procedural_run()
	_ctx.run_state.bind_boon_loadout(_ctx.player.technique_engine, _ctx.player)
	_ctx.run_state.legend_seen_this_run = true
	var node: MapNode = MapNode.new(9001, 1, MapNode.NodeType.BATTLE, [])
	_combat_scene.setup_combat(_ctx.player, node, false, "")
	_combat_scene.on_enter()
	_combat_scene.dev_set_capture_mode(true)
	_combat_scene.dev_set_capture_playback(true, bool(cfg.get("physics", false)))
	_current_scene = SceneContext.SCENE_COMBAT
	_ctx.current_scene = SceneContext.SCENE_COMBAT
	queue_redraw()

	_combat_scene.dev_prepare_capture_state(str(cfg["prep"]))
	await get_tree().process_frame

	var total: int = int(cfg["frames"]) * (2 if bool(cfg["loop"]) else 1)
	for i in range(total):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/frame_%03d.png" % [abs_dir.trim_suffix("/"), i]
		var save_err: int = image.save_png(path)
		if save_err != OK:
			push_error("shot-action: failed to save %s (err %d)" % [path, save_err])
			get_tree().quit(1)
			return

	var phases: Dictionary = {"state": state, "fps": 60, "loop": bool(cfg["loop"]), "frames": total}
	var def: Variant = _ctx.player._attack_state.def if _ctx.player._attack_state != null else null
	if def != null and (state == "ATTACKING_LIGHT" or state == "ATTACKING_HEAVY"):
		phases["windup_end_frame"] = int(round(def.windup_end * 60.0))
		phases["active_end_frame"] = int(round(def.active_end * 60.0))

	var phase_file: FileAccess = FileAccess.open("%s/phases.json" % abs_dir.trim_suffix("/"), FileAccess.WRITE)
	if phase_file == null:
		push_error("shot-action: failed to write phases.json")
		get_tree().quit(1)
		return
	phase_file.store_string(JSON.stringify(phases, "  "))
	phase_file.close()
	print("SHOT ACTION: wrote %d frames to %s" % [total, abs_dir])
	get_tree().quit(0)

func _sync_input_tracker() -> void:
	var keys: Array[int] = [
		KEY_ESCAPE, KEY_F5, KEY_R, KEY_A, KEY_D, KEY_W, KEY_S, KEY_Q,
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER,
		KEY_SPACE, KEY_J, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6,
		KEY_7, KEY_8, KEY_9, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4,
		KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
	]
	_input_tracker.sync_keys(keys)
	_input_tracker.sync_mouse_buttons([MOUSE_BUTTON_LEFT])

func _has_user_arg(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == flag:
			return true
	return false

func _user_arg_value(prefix: String, default_value: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = str(arg)
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return default_value
