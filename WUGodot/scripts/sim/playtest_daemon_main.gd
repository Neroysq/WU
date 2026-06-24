extends SceneTree

const PlaytestDaemonScript = preload("res://scripts/sim/playtest_daemon.gd")

var _daemon: Variant = null

func _init() -> void:
	DataManager.initialize()
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var session_id: String = _value(args, "--session", "session_%d" % Time.get_unix_time_from_system())
	var root: String = _value(args, "--root", "/tmp/wu-playtest")
	_daemon = PlaytestDaemonScript.new()
	_daemon.open(session_id, root)
	while not _daemon.should_quit:
		await _daemon.process_next(self)
		await create_timer(0.05).timeout
	quit(0)

func _value(args: PackedStringArray, name: String, default_value: String) -> String:
	var prefix: String = "%s=" % name
	for i in range(args.size()):
		var text: String = str(args[i])
		if text.begins_with(prefix):
			return text.substr(prefix.length())
		if text == name and i + 1 < args.size():
			return str(args[i + 1])
	return default_value
