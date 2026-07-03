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

	var identity_expectations: Dictionary = {
		"roadside_villager": {"title": "Villager at the First Step", "title_cn": "初路村民", "message": "teeth"},
		"travelling_merchant": {"title": "Pilgrim-Road Merchant", "title_cn": "朝山行商", "message": "look uphill"},
		"shrine_offering": {"title": "The Hungry Shrine", "title_cn": "飢祠", "message": "borrowed weight"},
		"drunken_master": {"title": "The Drunk Below the Gate", "title_cn": "門下醉客", "message": "denies he taught it"},
		"bandit_camp": {"title": "Dropout Camp", "title_cn": "棄徒營", "message": "borrowed forms"},
		"abandoned_scroll": {"title": "A Founder-Era Scroll", "title_cn": "祖師遺卷", "message": "founder-era strokes"},
	}
	for event_id in identity_expectations.keys():
		var expected: Dictionary = identity_expectations[event_id] as Dictionary
		var event: Dictionary = DataManagerScript.get_event_by_id(str(event_id))
		if str(event.get("title", "")) == str(expected.get("title", "")):
			passed += 1
		else:
			failed += 1
			failures.append("%s title should be '%s'" % [str(event_id), str(expected.get("title", ""))])

		if str(event.get("title_cn", "")) == str(expected.get("title_cn", "")):
			passed += 1
		else:
			failed += 1
			failures.append("%s title_cn should be '%s'" % [str(event_id), str(expected.get("title_cn", ""))])

		if _outcome_messages_contain(event, str(expected.get("message", ""))):
			passed += 1
		else:
			failed += 1
			failures.append("%s should have an outcome message containing '%s'" % [str(event_id), str(expected.get("message", ""))])

	var favor_event: Dictionary = {
		"id": "favor",
		"title": "Favor",
		"text": "Test.",
		"choices": [{"label": "Choose", "outcome": "choose"}],
		"outcomes": {"choose": {"favor_school": "iron", "message": "Iron favors you."}},
	}
	fighter = _make_fighter()
	runner.load_event(favor_event)
	result = runner.choose(0, fighter)
	if str(result.get("favor_school", "")) == "iron":
		passed += 1
	else:
		failed += 1
		failures.append("event favor outcome should surface favor_school")

	return {"passed": passed, "failed": failed, "failures": failures}

func _outcome_messages_contain(event: Dictionary, needle: String) -> bool:
	var messages: Array[String] = []
	_collect_messages(event.get("outcomes", {}), messages)
	for message in messages:
		if message.find(needle) >= 0:
			return true
	return false

func _collect_messages(value: Variant, out: Array[String]) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict: Dictionary = value as Dictionary
			if dict.has("message"):
				out.append(str(dict.get("message", "")))
			for child in dict.values():
				_collect_messages(child, out)
		TYPE_ARRAY:
			for child in value as Array:
				_collect_messages(child, out)
