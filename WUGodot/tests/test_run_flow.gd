extends RefCounted

const RunFlowScript = preload("res://scripts/run_flow.gd")
const MapNodeScript = preload("res://scripts/map_node.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.initialize()

	var duel: Variant = MapNodeScript.new(1, 1, MapNodeScript.NodeType.BATTLE, [])
	var outcome: Dictionary = RunFlowScript.combat_victory_outcome(duel, 1)
	if int(outcome.get("gold", -1)) == 15 and str(outcome.get("next", "")) == "reward":
		passed += 1
	else:
		failed += 1
		failures.append("duel victory should award 15 gold and route to reward")

	var elite: Variant = MapNodeScript.new(2, 1, MapNodeScript.NodeType.ELITE, [])
	outcome = RunFlowScript.combat_victory_outcome(elite, 2)
	if int(outcome.get("gold", -1)) == 60 and str(outcome.get("next", "")) == "reward":
		passed += 1
	else:
		failed += 1
		failures.append("elite victory should award 30 gold times multiplier")

	var ambush: Variant = MapNodeScript.new(3, 1, MapNodeScript.NodeType.AMBUSH, [])
	ambush.ambush_remaining = 2
	outcome = RunFlowScript.combat_victory_outcome(ambush, 1)
	if int(outcome.get("gold", -1)) == 10 and str(outcome.get("next", "")) == "combat_again" and ambush.ambush_remaining == 1:
		passed += 1
	else:
		failed += 1
		failures.append("ambush should chain while ambush_remaining stays above zero")

	ambush.ambush_remaining = 1
	outcome = RunFlowScript.combat_victory_outcome(ambush, 1)
	if int(outcome.get("gold", -1)) == 10 and str(outcome.get("next", "")) == "reward" and ambush.ambush_remaining == 0:
		passed += 1
	else:
		failed += 1
		failures.append("final ambush win should route to reward")

	var boss: Variant = MapNodeScript.new(4, 6, MapNodeScript.NodeType.BOSS, [])
	outcome = RunFlowScript.combat_victory_outcome(boss, 1)
	if int(outcome.get("gold", -1)) == 0 and str(outcome.get("next", "")) == "victory":
		passed += 1
	else:
		failed += 1
		failures.append("boss victory should route to victory with no gold")

	var player: Variant = EnemyFactoryScript.create_player()
	var shop: Variant = MapNodeScript.new(5, 2, MapNodeScript.NodeType.SHOP, [])
	var decision: Dictionary = RunFlowScript.travel_decision(shop, player)
	if str(decision.get("scene", "")) == "shop" and (decision.get("items", []) as Array).size() > 0:
		passed += 1
	else:
		failed += 1
		failures.append("shop travel should produce shop inventory")

	var event: Variant = MapNodeScript.new(6, 2, MapNodeScript.NodeType.EVENT, [])
	decision = RunFlowScript.travel_decision(event, player)
	if str(decision.get("scene", "")) == "event" and not str(event.event_id).is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("event travel should assign a persistent event_id")

	var rewards: Array = RunFlowScript.generate_technique_rewards(3, [])
	if rewards.size() == 3:
		passed += 1
	else:
		failed += 1
		failures.append("technique reward generation should return requested count")

	return {"passed": passed, "failed": failed, "failures": failures}
