class_name BatchRunner
extends RefCounted

func run(seeds: Array[int], player_policy: PlayerPolicy = null, decision_policy: DecisionPolicy = null, build: Dictionary = {}) -> Dictionary:
	var transcripts: Array[Dictionary] = []
	for seed in seeds:
		var driver: RunDriver = RunDriver.new()
		var transcript: RunTranscript = driver.run(seed, _clone_player_policy(player_policy, build), _clone_decision_policy(decision_policy), build)
		transcripts.append(transcript.to_dict())
	return summarize(transcripts)

func run_skill_sweep(seeds: Array[int], decision_policy: DecisionPolicy = null) -> Dictionary:
	var out: Dictionary = {}
	for skill in [0.5, 0.65, 0.8, 0.95]:
		out[str(skill)] = run(seeds, HeuristicPlayer.new(float(skill)), _clone_decision_policy(decision_policy), {"skill": skill})
	return out

static func summarize(transcripts: Array[Dictionary]) -> Dictionary:
	var wins: int = 0
	var depth_total: int = 0
	var death_by_node: Dictionary = {}
	var school_runs: Dictionary = {}
	var school_wins: Dictionary = {}
	var mastery_reached: int = 0
	for transcript in transcripts:
		var won: bool = str(transcript.get("outcome", "")) == "victory"
		if won:
			wins += 1
		depth_total += int(transcript.get("depth_reached", 0))
		var death: Dictionary = transcript.get("death", {}) as Dictionary
		if not death.is_empty():
			var key: String = "%s:%s" % [str(death.get("tier", "")), str(death.get("type", ""))]
			death_by_node[key] = int(death_by_node.get(key, 0)) + 1
		var snapshots: Array = transcript.get("build_snapshots", []) as Array
		var final_snapshot: Dictionary = snapshots.back() if not snapshots.is_empty() else {}
		for school in final_snapshot.get("active_schools", []) as Array:
			var school_id: String = str(school)
			school_runs[school_id] = int(school_runs.get(school_id, 0)) + 1
			if won:
				school_wins[school_id] = int(school_wins.get(school_id, 0)) + 1
		var loadout: Dictionary = final_snapshot.get("loadout", {}) as Dictionary
		if not (loadout.get("masteries", []) as Array).is_empty():
			mastery_reached += 1
	var win_rate_by_school: Dictionary = {}
	for school_id in school_runs.keys():
		win_rate_by_school[school_id] = float(school_wins.get(school_id, 0)) / maxf(1.0, float(school_runs[school_id]))
	var count: int = transcripts.size()
	return {
		"runs": count,
		"win_rate": float(wins) / maxf(1.0, float(count)),
		"avg_depth": float(depth_total) / maxf(1.0, float(count)),
		"death_by_node_histogram": death_by_node,
		"win_rate_by_school": win_rate_by_school,
		"mastery_reached_rate": float(mastery_reached) / maxf(1.0, float(count)),
		"transcripts": transcripts,
	}

func _clone_player_policy(policy: PlayerPolicy, build: Dictionary) -> PlayerPolicy:
	if policy is HeuristicPlayer:
		return HeuristicPlayer.new(policy.skill)
	if policy is ScriptedPlayer:
		return ScriptedPlayer.new(policy.actions)
	return HeuristicPlayer.new(float(build.get("skill", 0.8)))

func _clone_decision_policy(policy: DecisionPolicy) -> DecisionPolicy:
	if policy is RandomPolicy:
		return RandomPolicy.new()
	if policy is SchoolFocusedPolicy:
		return SchoolFocusedPolicy.new(policy.focus_school)
	if policy is ScriptedDecisionPolicy:
		return ScriptedDecisionPolicy.new(policy.picks)
	return GreedySynergyPolicy.new()

