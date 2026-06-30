extends Node

const MANIFEST_PATH: String = "res://data/Audio/Sfx.json"
const DEFAULT_POOL_SIZE: int = 12
const SFX_BUS: String = "SFX"

var _streams: Dictionary = {}
var _pitch_vars: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if _is_headless():
		return
	load_manifest()
	_ensure_sfx_bus()
	_ensure_pool()

func load_manifest(path: String = MANIFEST_PATH) -> bool:
	_streams.clear()
	_pitch_vars.clear()
	if not FileAccess.file_exists(path):
		push_warning("AudioManager: missing manifest %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("AudioManager: manifest did not parse: %s" % path)
		return false
	var root: Dictionary = parsed as Dictionary
	var entries: Dictionary = root.get("sfx", root) as Dictionary
	for id in entries.keys():
		var sfx_id: String = str(id)
		var entry: Variant = entries[id]
		var stream_path: String = ""
		var pitch_var: float = 0.0
		if typeof(entry) == TYPE_STRING:
			stream_path = str(entry)
		elif typeof(entry) == TYPE_DICTIONARY:
			var data: Dictionary = entry as Dictionary
			stream_path = str(data.get("path", ""))
			pitch_var = maxf(0.0, float(data.get("pitch_var", data.get("pitchVar", 0.0))))
		if stream_path.is_empty():
			continue
		var stream: AudioStream = load(stream_path) as AudioStream
		if stream == null:
			push_warning("AudioManager: missing stream for %s: %s" % [sfx_id, stream_path])
			continue
		_streams[sfx_id] = stream
		_pitch_vars[sfx_id] = pitch_var
	return not _streams.is_empty()

func play(id: String, pitch_var: float = -1.0) -> void:
	if _is_headless() or id.is_empty():
		return
	if not _streams.has(id):
		return
	_ensure_sfx_bus()
	_ensure_pool()
	if _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stop()
	player.stream = _streams[id] as AudioStream
	player.bus = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else "Master"
	var amount: float = pitch_var if pitch_var >= 0.0 else float(_pitch_vars.get(id, 0.0))
	player.pitch_scale = 1.0 + _rng.randf_range(-amount, amount) if amount > 0.0 else 1.0
	player.play()

func has_sfx(id: String) -> bool:
	return _streams.has(id)

func ids() -> Array[String]:
	var result: Array[String] = []
	for id in _streams.keys():
		result.append(str(id))
	result.sort()
	return result

func _ensure_pool() -> void:
	if not _players.is_empty():
		return
	for i in range(DEFAULT_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else "Master"
		add_child(player)
		_players.append(player)

func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		return
	var index: int = AudioServer.get_bus_count()
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, SFX_BUS)
	AudioServer.set_bus_send(index, "Master")

func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"
