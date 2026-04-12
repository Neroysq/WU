extends RefCounted

const DataManagerScript = preload("res://scripts/data_manager.gd")
const TechniqueScript = preload("res://scripts/technique.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var data: Dictionary = {
		"id": "A1",
		"name_en": "Descending Leaf",
		"name_cn": "落葉",
		"type": "A",
		"category": "movement_attack",
		"description": "Dash ends in a sword stab dealing 8 damage.",
		"rarity": 1,
	}
	var tech: Variant = TechniqueScript.from_dictionary(data)
	var checks: Array[Array] = [
		[tech.id, "A1", "id"],
		[tech.name_en, "Descending Leaf", "name_en"],
		[tech.name_cn, "落葉", "name_cn"],
		[tech.type, "A", "type"],
		[tech.category, "movement_attack", "category"],
		[tech.rarity, 1, "rarity"],
	]
	for check in checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("from_dict %s: expected %s got %s" % [str(check[2]), str(check[1]), str(check[0])])

	var empty_tech: Variant = TechniqueScript.from_dictionary({})
	var default_checks: Array[Array] = [
		[empty_tech.id, "", "default id"],
		[empty_tech.name_en, "", "default name_en"],
		[empty_tech.type, "A", "default type"],
		[empty_tech.rarity, 1, "default rarity"],
	]
	for check in default_checks:
		if check[0] == check[1]:
			passed += 1
		else:
			failed += 1
			failures.append("default %s: expected %s got %s" % [str(check[2]), str(check[1]), str(check[0])])

	DataManagerScript.reload_data()
	var a1_data: Dictionary = DataManagerScript.get_technique("A1")
	if str(a1_data.get("id", "")) == "A1":
		passed += 1
	else:
		failed += 1
		failures.append("DataManager.get_technique('A1') should return A1 data")

	var all_techniques: Dictionary = DataManagerScript.get_all_techniques()
	if all_techniques.size() == 20:
		passed += 1
	else:
		failed += 1
		failures.append("get_all_techniques should return 20 (got %d)" % all_techniques.size())

	var missing: Dictionary = DataManagerScript.get_technique("NONEXISTENT")
	if missing.is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("get_technique for missing id should return empty dict")

	return {"passed": passed, "failed": failed, "failures": failures}
