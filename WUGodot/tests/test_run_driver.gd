extends RefCounted

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.reload_data()
	var transcript_a: RunTranscript = RunDriver.new().run(7, HeuristicPlayer.new(0.8), GreedySynergyPolicy.new())
	var transcript_b: RunTranscript = RunDriver.new().run(7, HeuristicPlayer.new(0.8), GreedySynergyPolicy.new())
	if not transcript_a.outcome.is_empty() and transcript_a.depth_reached >= 1:
		passed += 1
	else:
		failed += 1
		failures.append("RunDriver should produce a terminal transcript that reaches the run path")

	if transcript_a.outcome == transcript_b.outcome and transcript_a.depth_reached == transcript_b.depth_reached:
		passed += 1
	else:
		failed += 1
		failures.append("RunDriver should reproduce outcome/depth for the same seed and policies")

	var snapshots: Array = transcript_a.build_snapshots
	var snapshots_have_after_node: bool = not snapshots.is_empty()
	for snapshot in snapshots:
		var data: Dictionary = snapshot as Dictionary
		if data.get("after_node", null) == null:
			snapshots_have_after_node = false
	if snapshots_have_after_node:
		passed += 1
	else:
		failed += 1
		failures.append("RunDriver build snapshots should populate after_node for capture replay")

	var summary: Dictionary = BatchRunner.new().run([1, 2], HeuristicPlayer.new(0.8), GreedySynergyPolicy.new())
	if int(summary.get("runs", 0)) == 2 and summary.has("win_rate") and summary.has("death_by_node_histogram"):
		passed += 1
	else:
		failed += 1
		failures.append("BatchRunner should aggregate run transcripts")

	return {"passed": passed, "failed": failed, "failures": failures}
