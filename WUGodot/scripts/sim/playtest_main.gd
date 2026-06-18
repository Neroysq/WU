extends SceneTree

func _init() -> void:
	DataManager.initialize()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var exit_code: int = _run(args)
	quit(exit_code)

func _run(args: PackedStringArray) -> int:
	if _has(args, "--playtest-batch"):
		return _run_batch(args)
	return _run_one(args)

func _run_one(args: PackedStringArray) -> int:
	var seed: int = int(_value(args, "--seed", "1"))
	var player_policy: PlayerPolicy = _make_player(args)
	var decision_policy: DecisionPolicy = _make_decision(args)
	var transcript: RunTranscript = RunDriver.new().run(seed, player_policy, decision_policy, {"skill": _skill(args)})
	var text: String = JSON.stringify(transcript.to_dict(), "  ")
	_write_text(_value(args, "--out", ""), text)
	print("PLAYTEST seed=%d outcome=%s depth=%d combats=%d" % [seed, transcript.outcome, transcript.depth_reached, transcript.combats.size()])
	return 0

func _run_batch(args: PackedStringArray) -> int:
	var seeds: Array[int] = _parse_seeds(_value(args, "--seeds", "1..20"))
	var decision_policy: DecisionPolicy = _make_decision(args)
	var summary: Dictionary
	if _has(args, "--skill-sweep"):
		summary = BatchRunner.new().run_skill_sweep(seeds, decision_policy)
	else:
		summary = BatchRunner.new().run(seeds, _make_player(args), decision_policy, {"skill": _skill(args)})
	var text: String = JSON.stringify(summary, "  ")
	_write_text(_value(args, "--out", ""), text)
	print("PLAYTEST BATCH runs=%d" % seeds.size())
	return 0

func _make_player(args: PackedStringArray) -> PlayerPolicy:
	var id: String = _value(args, "--player", "heuristic")
	match id:
		"scripted":
			return ScriptedPlayer.new()
		_:
			return HeuristicPlayer.new(_skill(args))

func _make_decision(args: PackedStringArray) -> DecisionPolicy:
	var id: String = _value(args, "--decision", "greedy")
	match id:
		"random":
			return RandomPolicy.new()
		"school":
			return SchoolFocusedPolicy.new(_value(args, "--school", ""))
		"scripted":
			return ScriptedDecisionPolicy.new()
		_:
			return GreedySynergyPolicy.new()

func _skill(args: PackedStringArray) -> float:
	return float(_value(args, "--skill", "0.8"))

func _parse_seeds(spec: String) -> Array[int]:
	var seeds: Array[int] = []
	if spec.find("..") >= 0:
		var parts: PackedStringArray = spec.split("..")
		var start: int = int(parts[0])
		var end: int = int(parts[1])
		for seed in range(start, end + 1):
			seeds.append(seed)
		return seeds
	for raw in spec.split(",", false):
		seeds.append(int(raw))
	return seeds

func _has(args: PackedStringArray, flag: String) -> bool:
	for arg in args:
		if str(arg) == flag:
			return true
	return false

func _value(args: PackedStringArray, name: String, default_value: String) -> String:
	var prefix: String = "%s=" % name
	for i in range(args.size()):
		var text: String = str(args[i])
		if text.begins_with(prefix):
			return text.substr(prefix.length())
		if text == name and i + 1 < args.size():
			return str(args[i + 1])
	return default_value

func _write_text(path: String, text: String) -> void:
	if path.is_empty():
		print(text)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("failed to write %s" % path)
		return
	file.store_string(text)
	file.close()

