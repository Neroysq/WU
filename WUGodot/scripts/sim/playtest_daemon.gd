class_name PlaytestDaemon
extends RefCounted

const RunConductorScript = preload("res://scripts/sim/run_conductor.gd")
const ScreenshotServiceScript = preload("res://scripts/sim/screenshot_service.gd")

var session_id: String = ""
var root_dir: String = "/tmp/wu-playtest"
var session_dir: String = ""
var conductor: Variant = null
var last_seq: int = 0
var should_quit: bool = false

func open(id: String, root: String = "/tmp/wu-playtest") -> void:
	session_id = id
	root_dir = root
	session_dir = "%s/%s" % [root_dir.trim_suffix("/"), session_id]
	DirAccess.make_dir_recursive_absolute(session_dir)
	DirAccess.make_dir_recursive_absolute("%s/shots" % session_dir)
	_write_json_atomic("%s/ready.json" % session_dir, {"session_id": session_id, "pid": OS.get_process_id(), "status": "ready"})
	_write_heartbeat()

func handle_command(command: Dictionary, tree: SceneTree = null) -> Dictionary:
	var seq: int = int(command.get("seq", last_seq + 1))
	var response: Dictionary = {"seq": seq, "session_id": session_id, "status": "ok"}
	var kind: String = str(command.get("cmd", command.get("type", "")))
	if kind.is_empty():
		kind = str(command.get("command", ""))
	match kind:
		"start":
			conductor = RunConductorScript.new()
			var build: Dictionary = {
				"build": command.get("build", []),
				"forced_archetype": str(command.get("forced_archetype", "")),
			}
			response["result"] = conductor.start(int(command.get("seed", 1)), build)
		"status", "observe":
			response["result"] = _require_conductor().observe() if conductor != null else {"pause": {"kind": "none"}}
		"choose":
			if conductor == null:
				response = _error_response(seq, "session not started")
			else:
				response["result"] = conductor.choose(int(command.get("index", 0)))
				_set_error_if_needed(response)
		"input":
			if conductor == null:
				response = _error_response(seq, "session not started")
			else:
				var advance: Dictionary = command.get("advance", {}) as Dictionary
				var frames: int = int(advance.get("frames", command.get("frames", 1)))
				if advance.has("until"):
					conductor.add_trigger({"event": str(advance.get("until", ""))})
					frames = int(advance.get("max_frames", 3600))
				response["result"] = conductor.advance_combat(command.get("actions", []) as Array, frames)
				_set_error_if_needed(response)
		"step":
			if conductor == null:
				response = _error_response(seq, "session not started")
			else:
				response["result"] = conductor.step(int(command.get("frames", 1)))
				_set_error_if_needed(response)
		"trigger_add":
			response["result"] = conductor.add_trigger(command) if conductor != null else {"status": "error", "error": "session not started"}
			_set_error_if_needed(response)
		"trigger_clear":
			response["result"] = conductor.clear_trigger(command.get("id", "all")) if conductor != null else {"status": "error", "error": "session not started"}
			_set_error_if_needed(response)
		"trigger_list":
			response["result"] = conductor.trigger_list() if conductor != null else {"status": "error", "error": "session not started"}
			_set_error_if_needed(response)
		"screenshot":
			if conductor == null:
				response = _error_response(seq, "session not started")
			else:
				response["result"] = await ScreenshotServiceScript.capture(conductor, str(command.get("label", "shot")), seq, session_dir, tree)
				if not bool((response["result"] as Dictionary).get("success", false)):
					_set_error(response, str((response["result"] as Dictionary).get("error", "screenshot failed")))
		"quit":
			should_quit = true
			response["result"] = {"quit": true}
		_:
			response = _error_response(seq, "unknown command %s" % kind)
	last_seq = maxi(last_seq, seq)
	_append_log(command)
	_write_heartbeat()
	return response

func process_next(tree: SceneTree = null) -> bool:
	var next_seq: int = last_seq + 1
	var path: String = "%s/cmd_%d.json" % [session_dir, next_seq]
	if not FileAccess.file_exists(path):
		return false
	var command: Dictionary = _read_json(path)
	if int(command.get("seq", next_seq)) != next_seq:
		var bad: Dictionary = _error_response(next_seq, "command seq mismatch")
		_write_json_atomic("%s/resp_%d.json" % [session_dir, next_seq], bad)
		last_seq = next_seq
		_write_heartbeat()
		return true
	var response: Dictionary = await handle_command(command, tree)
	_write_json_atomic("%s/resp_%d.json" % [session_dir, next_seq], response)
	return true

func _require_conductor() -> Variant:
	return conductor

func _set_error_if_needed(response: Dictionary) -> void:
	if typeof(response.get("result", null)) == TYPE_DICTIONARY and str((response["result"] as Dictionary).get("status", "")) == "error":
		_set_error(response, str((response["result"] as Dictionary).get("error", "command failed")))

func _set_error(response: Dictionary, message: String) -> void:
	response["status"] = "error"
	response["error"] = message

func _error_response(seq: int, message: String) -> Dictionary:
	return {"seq": seq, "session_id": session_id, "status": "error", "error": message}

func _write_heartbeat() -> void:
	_write_json_atomic("%s/heartbeat.json" % session_dir, {"last_seq": last_seq, "ts": Time.get_unix_time_from_system()})

func _append_log(command: Dictionary) -> void:
	var file: FileAccess = FileAccess.open("%s/command_log.jsonl" % session_dir, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("%s/command_log.jsonl" % session_dir, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(command))
	file.close()

func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_json_atomic(path: String, data: Dictionary) -> void:
	var tmp: String = "%s.tmp" % path
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
