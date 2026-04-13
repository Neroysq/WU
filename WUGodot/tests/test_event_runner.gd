extends RefCounted

const EventRunnerScript = preload("res://scripts/event_runner.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const TechniqueEngineScript = preload("res://scripts/technique_engine.gd")
const DataManagerScript = preload("res://scripts/data_manager.gd")

func _make_fighter() -> Variant:
	var fighter: Variant = FighterScript.new()
	fighter.health_max = 100.0
	fighter.health_current = 100.0
	fighter.gold = 50
	fighter.technique_engine = TechniqueEngineScript.new()
	return fighter

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManagerScript.reload_data()

	var event_data: Dictionary = {
		"id": "test_event",
		"title": "Test Event",
		"text": "A test event.",
		"choices": [
			{"label": "Choice A", "outcome": "a"},
			{"label": "Choice B", "outcome": "b"},
		],
		"outcomes": {
			"a": {"gold": 10, "hp": -5, "message": "You chose A."},
			"b": {"message": "You chose B."},
		},
	}
	var runner: Variant = EventRunnerScript.new()
	runner.load_event(event_data)
	if runner.get_title() == "Test Event":
		passed += 1
	else:
		failed += 1
		failures.append("title should be 'Test Event' (got '%s')" % runner.get_title())

	if runner.get_choices().size() == 2:
		passed += 1
	else:
		failed += 1
		failures.append("should have 2 choices (got %d)" % runner.get_choices().size())

	var fighter: Variant = _make_fighter()
	var result: Dictionary = runner.choose(0, fighter)
	if fighter.gold == 60 and absf(fighter.health_current - 95.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("choice A: gold=%d (expect 60) hp=%.1f (expect 95)" % [fighter.gold, fighter.health_current])

	if str(result.get("message", "")) == "You chose A.":
		passed += 1
	else:
		failed += 1
		failures.append("result message should be 'You chose A.'")

	fighter = _make_fighter()
	runner.load_event(event_data)
	result = runner.choose(1, fighter)
	if fighter.gold == 50 and absf(fighter.health_current - 100.0) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("choice B should have no gold/hp effect")

	var tech_event: Dictionary = {
		"id": "tech_test",
		"title": "Tech Test",
		"text": "Test.",
		"choices": [{"label": "Go", "outcome": "go"}],
		"outcomes": {"go": {"grant_technique": "random_A", "message": "Got tech."}},
	}
	fighter = _make_fighter()
	runner.load_event(tech_event)
	result = runner.choose(0, fighter)
	if fighter.technique_engine.technique_ids().size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("technique grant should add 1 technique (got %d)" % fighter.technique_engine.technique_ids().size())

	var expensive_event: Dictionary = {
		"id": "expensive",
		"title": "Expensive",
		"text": "Test.",
		"choices": [{"label": "Pay", "outcome": "pay"}],
		"outcomes": {"pay": {"gold": -100, "grant_technique": "random", "message": "Paid."}},
	}
	fighter = _make_fighter()
	fighter.gold = 20
	runner.load_event(expensive_event)
	result = runner.choose(0, fighter)
	if fighter.gold == 20 and bool(result.get("blocked", false)):
		passed += 1
	else:
		failed += 1
		failures.append("should block insufficient-gold outcome (gold=%d blocked=%s)" % [fighter.gold, str(result.get("blocked", false))])

	var events: Array[Dictionary] = DataManagerScript.get_events()
	if events.size() == 6:
		passed += 1
	else:
		failed += 1
		failures.append("DataManager should load 6 events (got %d)" % events.size())

	var loaded_event: Dictionary = DataManagerScript.get_event_by_id("abandoned_scroll")
	if str(loaded_event.get("id", "")) == "abandoned_scroll":
		passed += 1
	else:
		failed += 1
		failures.append("get_event_by_id should return abandoned_scroll")

	return {"passed": passed, "failed": failed, "failures": failures}
