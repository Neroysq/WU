class_name RngService
extends RefCounted

static var _seed: int = -1
static var _streams: Dictionary = {}

static func set_run_seed(seed_value: int) -> void:
	_seed = seed_value
	_streams.clear()

static func clear_run_seed() -> void:
	_seed = -1
	_streams.clear()

static func stream(domain: String) -> RandomNumberGenerator:
	if _streams.has(domain):
		return _streams[domain]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if _seed >= 0:
		rng.seed = int(hash("%d:%s" % [_seed, domain]))
	else:
		rng.randomize()
	_streams[domain] = rng
	return rng

