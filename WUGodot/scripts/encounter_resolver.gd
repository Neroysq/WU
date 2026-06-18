class_name EncounterResolver
extends RefCounted

const RngServiceScript = preload("res://scripts/sim/rng_service.gd")

static func begin_encounter(run_state: Variant, node: MapNode, wave: int = 0) -> Dictionary:
	var curve: Dictionary = _curve_for_run(run_state)
	var selected: Dictionary = _select(curve, run_state, node, wave)
	var pool_class: String = str(selected.get("pool_class", "weak"))
	var archetype: String = str(selected.get("archetype", "bandit_swordsman"))
	var ordinal: int = int(run_state.normal_combats_started) if run_state != null else 0
	if pool_class == "weak" or pool_class == "strong":
		run_state.normal_combats_started = ordinal + 1
	if run_state != null:
		if typeof(run_state.last_archetype_by_pool) != TYPE_DICTIONARY:
			run_state.last_archetype_by_pool = {}
		run_state.last_archetype_by_pool[pool_class] = archetype
		if node != null and node.node_type == MapNode.NodeType.AMBUSH:
			if typeof(run_state.last_ambush_rank_by_node) != TYPE_DICTIONARY:
				run_state.last_ambush_rank_by_node = {}
			run_state.last_ambush_rank_by_node[node.id] = _rank(curve, archetype)
	return {
		"archetype": archetype,
		"pool_class": pool_class,
		"normal_combat_ordinal": ordinal,
		"ambush_wave": wave,
		"node_id": node.id if node != null else -1,
	}

static func ambush_length(curve: Dictionary, tier: int) -> int:
	var ambush: Dictionary = curve.get("ambush", {}) as Dictionary
	var lengths: Dictionary = ambush.get("length_by_tier", {}) as Dictionary
	var exact_key: String = str(tier)
	if lengths.has(exact_key):
		return maxi(1, int(lengths[exact_key]))
	var best_tier: int = -1
	var best_value: int = 3
	for key in lengths.keys():
		var candidate_tier: int = int(str(key))
		if candidate_tier <= tier and candidate_tier > best_tier:
			best_tier = candidate_tier
			best_value = int(lengths[key])
	return maxi(1, best_value)

static func wave_index_for_node(run_state: Variant, node: MapNode) -> int:
	if node == null or node.node_type != MapNode.NodeType.AMBUSH:
		return 0
	var length: int = ambush_length(_curve_for_run(run_state), node.tier)
	return clampi(length - node.ambush_remaining, 0, maxi(0, length - 1))

static func _select(curve: Dictionary, run_state: Variant, node: MapNode, wave: int) -> Dictionary:
	if node != null:
		match node.node_type:
			MapNode.NodeType.BOSS:
				return {"archetype": str(curve.get("boss", "iron_bear")), "pool_class": "boss"}
			MapNode.NodeType.ELITE:
				return {"archetype": _pick_from_pool(curve, curve.get("elite_pool", []) as Array, "elite", run_state, node, wave), "pool_class": "elite"}

	var weak: bool = run_state == null or int(run_state.normal_combats_started) < int(curve.get("weak_count", 1))
	var pool_class: String = "weak" if weak else "strong"
	var pool: Array = []
	if weak:
		pool = curve.get("weak_pool", []) as Array
	else:
		pool = curve.get("strong_pool", []) as Array
	return {
		"archetype": _pick_from_pool(curve, pool, pool_class, run_state, node, wave),
		"pool_class": pool_class,
	}

static func _pick_from_pool(curve: Dictionary, source_pool: Array, pool_class: String, run_state: Variant, node: MapNode, wave: int) -> String:
	var pool: Array[String] = []
	for item in source_pool:
		var archetype: String = str(item)
		if not archetype.is_empty():
			pool.append(archetype)
	if pool.is_empty():
		return _fallback_archetype(pool_class)

	var candidates: Array[String] = pool.duplicate()
	if bool(curve.get("no_immediate_repeat", true)) and candidates.size() > 1 and run_state != null:
		var previous_by_pool: Dictionary = run_state.last_archetype_by_pool if typeof(run_state.last_archetype_by_pool) == TYPE_DICTIONARY else {}
		var previous: String = str(previous_by_pool.get(pool_class, ""))
		candidates.erase(previous)
		if candidates.is_empty():
			candidates = pool.duplicate()

	if node != null and node.node_type == MapNode.NodeType.AMBUSH and bool((curve.get("ambush", {}) as Dictionary).get("escalate", false)):
		candidates = _escalated_ambush_candidates(curve, candidates, pool, run_state, node, wave)

	var rng: RandomNumberGenerator = RngServiceScript.stream("enemy_pick")
	return candidates[rng.randi_range(0, candidates.size() - 1)]

static func _escalated_ambush_candidates(curve: Dictionary, candidates: Array[String], full_pool: Array[String], run_state: Variant, node: MapNode, wave: int) -> Array[String]:
	var min_rank: int = 0
	if run_state != null and typeof(run_state.last_ambush_rank_by_node) == TYPE_DICTIONARY:
		min_rank = int(run_state.last_ambush_rank_by_node.get(node.id, 0))
	if wave > 0 and min_rank <= 0:
		for archetype in candidates:
			min_rank = maxi(min_rank, _rank(curve, archetype))
	if min_rank <= 0:
		return candidates

	var filtered: Array[String] = []
	for archetype in candidates:
		if _rank(curve, archetype) >= min_rank:
			filtered.append(archetype)
	if not filtered.is_empty():
		return filtered
	for archetype in full_pool:
		if _rank(curve, archetype) >= min_rank:
			filtered.append(archetype)
	return filtered if not filtered.is_empty() else candidates

static func _curve_for_run(run_state: Variant) -> Dictionary:
	var chapter: int = 1
	if run_state != null:
		chapter = int(run_state.chapter)
	return DataManager.get_difficulty_curve(chapter)

static func _rank(curve: Dictionary, archetype: String) -> int:
	var ranks: Dictionary = curve.get("archetype_rank", {}) as Dictionary
	return int(ranks.get(archetype, 0))

static func _fallback_archetype(pool_class: String) -> String:
	match pool_class:
		"strong":
			return "wandering_ronin"
		"elite":
			return "sect_disciple"
		"boss":
			return "iron_bear"
		_:
			return "bandit_swordsman"
