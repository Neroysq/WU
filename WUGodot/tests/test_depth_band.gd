extends RefCounted

const DepthBandScript = preload("res://scripts/ui/depth_band.gd")
const MapNodeScript = preload("res://scripts/map_node.gd")
const RunStateScript = preload("res://scripts/run_state.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var expectations: Dictionary = {
		1: "foothill",
		2: "mid",
		3: "mid",
		4: "high",
		5: "high",
	}
	for tier in expectations.keys():
		var node: Variant = MapNodeScript.new(100 + int(tier), int(tier), MapNodeScript.NodeType.BATTLE, [])
		var band: String = DepthBandScript.band_for_node(node)
		if band == str(expectations[tier]):
			passed += 1
		else:
			failed += 1
			failures.append("tier %d should map to %s (got %s)" % [int(tier), str(expectations[tier]), band])

	var boss_node: Variant = MapNodeScript.new(200, 6, MapNodeScript.NodeType.BOSS, [])
	if DepthBandScript.band_for_node(boss_node) == "gate":
		passed += 1
	else:
		failed += 1
		failures.append("BOSS node should map to gate")

	var run: Variant = RunStateScript.new()
	var current: Variant = MapNodeScript.new(1, 4, MapNodeScript.NodeType.EVENT, [])
	run.nodes.append(current)
	run.current_node_id = current.id
	if DepthBandScript.band_for_run(run) == "high":
		passed += 1
	else:
		failed += 1
		failures.append("band_for_run should use the current node")

	for key in ["foothill", "mid", "high", "gate"]:
		if GameConstants.BAND_TINTS.has(key):
			passed += 1
		else:
			failed += 1
			failures.append("GameConstants.BAND_TINTS missing %s" % key)

	return {"passed": passed, "failed": failed, "failures": failures}
