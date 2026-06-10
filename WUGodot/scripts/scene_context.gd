class_name SceneContext
extends RefCounted

const SCENE_MAIN_MENU: int = 0
const SCENE_MAP: int = 1
const SCENE_COMBAT: int = 2
const SCENE_REWARD: int = 3
const SCENE_EVENT: int = 4
const SCENE_SHOP: int = 5
const SCENE_REST: int = 6
const SCENE_FORGET_TECHNIQUE: int = 7
const SCENE_VICTORY: int = 8
const SCENE_GAME_OVER: int = 9

var current_scene: int = SCENE_MAIN_MENU
var run_state: RunState
var player: Fighter
var combat_gold_multiplier: int = 1
var run_gold_earned: int = 0
var run_techniques_acquired: Array[String] = []
var run_start_time: float = 0.0
var run_end_time: float = 0.0
var end_message: String = ""
var cursor_flash: float = 0.0
var notice_message: String = ""
var notice_timer: float = 0.0

var next_scene: int = -1
var transition_payload: Dictionary = {}
var combat_node: MapNode = null
var new_run_requested: bool = false

func goto(scene: int, payload: Dictionary = {}) -> void:
	next_scene = scene
	transition_payload = payload.duplicate(true)

func request_combat(node: MapNode) -> void:
	combat_node = node

func request_new_run() -> void:
	new_run_requested = true

func clear_transition() -> void:
	next_scene = -1
	transition_payload.clear()
	combat_node = null
	new_run_requested = false
