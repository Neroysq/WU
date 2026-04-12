class_name Technique
extends RefCounted

var id: String = ""
var name_en: String = ""
var name_cn: String = ""
var type: String = "A"
var category: String = ""
var description: String = ""
var rarity: int = 1

static func from_dictionary(data: Dictionary) -> Variant:
	var tech: Variant = load("res://scripts/technique.gd").new()
	tech.id = str(data.get("id", ""))
	tech.name_en = str(data.get("name_en", ""))
	tech.name_cn = str(data.get("name_cn", ""))
	tech.type = str(data.get("type", "A"))
	tech.category = str(data.get("category", ""))
	tech.description = str(data.get("description", ""))
	tech.rarity = int(data.get("rarity", 1))
	return tech
