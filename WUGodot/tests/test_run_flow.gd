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
	if int(outcome.get("gold", -1)) == 15 and str(outcome.get("next", "")) == "boon_offer":
		passed += 1
	else:
		failed += 1
		failures.append("duel victory should award 15 gold and route to boon offer")

	var elite: Variant = MapNodeScript.new(2, 1, MapNodeScript.NodeType.ELITE, [])
	outcome = RunFlowScript.combat_victory_outcome(elite, 2)
	if int(outcome.get("gold", -1)) == 60 and str(outcome.get("next", "")) == "boon_offer":
		passed += 1
	else:
		failed += 1
		failures.append("elite victory should award 30 gold times multiplier and route to boon offer")

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
	if int(outcome.get("gold", -1)) == 10 and str(outcome.get("next", "")) == "boon_offer" and ambush.ambush_remaining == 0:
		passed += 1
	else:
		failed += 1
		failures.append("final ambush win should route to boon offer")

	var boss: Variant = MapNodeScript.new(4, 6, MapNodeScript.NodeType.BOSS, [])
	outcome = RunFlowScript.combat_victory_outcome(boss, 1)
	if int(outcome.get("gold", -1)) == 0 and str(outcome.get("next", "")) == "victory":
		passed += 1
	else:
		failed += 1
		failures.append("boss victory should route to victory with no gold")

	if int(RunFlowScript.combat_victory_outcome(elite, 1).get("insight", 0)) == 1:
		passed += 1
	else:
		failed += 1
		failures.append("elite victory should award Insight")

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

	var run: Variant = RunState.create_procedural_run(123)
	run.bind_boon_loadout(player.technique_engine, player)
	var offer_payload: Dictionary = RunFlowScript.generate_boon_offer_payload(run, duel)
	if str(offer_payload.get("scene", "")) == "boon_offer" and (offer_payload.get("offers", []) as Array).size() == 3:
		passed += 1
	else:
		failed += 1
		failures.append("boon offer payload generation should produce 3 offers")

	var offers: Array = offer_payload.get("offers", []) as Array
	var added: bool = not offers.is_empty() and RunFlowScript.apply_boon_offer_selection(run, offers[0] as Dictionary)
	if added and not run.boon_loadout.serialize().is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("selecting a boon offer should add it to the run loadout")

	var master: Variant = MapNodeScript.new(7, 3, MapNodeScript.NodeType.MASTER, [])
	decision = RunFlowScript.travel_decision(master, player, run)
	if str(decision.get("scene", "")) == "boon_offer" and (decision.get("school_choices", []) as Array).size() >= 2:
		passed += 1
	else:
		failed += 1
		failures.append("master travel should produce a school-choice boon offer")

	run.favored_school = "iron"
	offer_payload = RunFlowScript.generate_boon_offer_payload(run, duel)
	if str(offer_payload.get("school", "")) == "iron" and str(run.favored_school).is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("favored_school should bias the next battle offer and then clear")

	return {"passed": passed, "failed": failed, "failures": failures}
