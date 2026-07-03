class_name BoonText
extends RefCounted

const BoonFactoryScript = preload("res://scripts/boons/boon_factory.gd")

static func name(boon: Dictionary) -> String:
	var explicit: String = str(boon.get("name", ""))
	if not explicit.is_empty():
		return explicit
	return _humanize_id(str(boon.get("id", "")))

static func label(boon: Dictionary, tier: String) -> String:
	var kind: String = str(boon.get("kind", ""))
	if kind == "duo":
		return "Duo · %s" % name(boon)
	if kind == "mastery":
		return "Mastery · %s" % name(boon)
	return "%s · %s" % [_normalize_tier(tier).capitalize(), name(boon)]

static func describe(boon: Dictionary, tier: String) -> String:
	var clauses: Array[String] = []
	for effect_data in _effects_for_tier(boon, tier):
		clauses.append(describe_effect(effect_data as Dictionary))
	return " · ".join(clauses) if not clauses.is_empty() else "No effect"

static func summary(boon: Dictionary, tier: String) -> String:
	var kind: String = str(boon.get("kind", ""))
	var effects: Array[Dictionary] = _effects_for_tier(boon, tier)
	if effects.is_empty():
		return "No effect"
	if kind == "duo" or kind == "mastery":
		return _short_effect(effects[0] as Dictionary)
	var rider_count: int = maxi(effects.size() - 1, 0)
	var base: String = _short_effect(effects[0] as Dictionary)
	if rider_count <= 0:
		return base
	return "%s +%d rider%s" % [base, rider_count, "" if rider_count == 1 else "s"]

static func describe_effect(effect_data: Dictionary) -> String:
	var override: String = str(effect_data.get("desc", ""))
	if not override.is_empty():
		return override
	match str(effect_data.get("type", "")):
		"bleed_on_heavy":
			return "heavy applies bleed (%.1f dps/%.0fs)" % [float(effect_data.get("dps", 0.0)), float(effect_data.get("timer", 0.0))]
		"block_chip":
			return "reduces block chip to %d%%" % int(round(float(effect_data.get("multiplier", 1.0)) * 100.0))
		"break_heal":
			return "heal %.0f on posture break" % float(effect_data.get("heal", 0.0))
		"dash_stab":
			return "dash strike reaches +%.0f for %.0f damage" % [float(effect_data.get("range", 0.0)), float(effect_data.get("damage", 0.0))]
		"deflect":
			return "deflect deals %.0f damage" % float(effect_data.get("damage", 0.0))
		"deflect_redirect":
			return "deflect redirects %d%% damage" % _bonus_percent(effect_data, "reflect")
		"deflect_reduce":
			return "incoming damage reduced to %d%%" % int(round(float(effect_data.get("multiplier", 1.0)) * 100.0))
		"deflect_riposte_dmg":
			return "riposte adds %.0f damage" % float(effect_data.get("damage", 0.0))
		"echo":
			return "posture break echoes a follow-up strike"
		"flowing_water":
			return "heal %.0f after a clean dodge" % float(effect_data.get("heal", 0.0))
		"gaze":
			return "kills grant +%d%% speed for %.0fs" % [_bonus_percent(effect_data, "speed_multiplier"), float(effect_data.get("duration", 0.0))]
		"intent_crit_vs_marked":
			return "marked foes take %d%% crit damage" % int(round(float(effect_data.get("multiplier", 1.0)) * 100.0))
		"intent_dash_flash":
			return "dash flash marks %d target within %.0f" % [int(effect_data.get("marks", 0)), float(effect_data.get("range", 0.0))]
		"intent_mark":
			return "applies %d intent mark (%.0f burst/mark)" % [int(effect_data.get("marks", 0)), float(effect_data.get("burst_per_mark", 0.0))]
		"intent_reach":
			return "extends sword reach by %.0f" % float(effect_data.get("range", 0.0))
		"jolt":
			return "applies jolt for %.1fs" % float(effect_data.get("timer", 0.0))
		"jolt_amp":
			return "jolt damage becomes %d%%" % int(round(float(effect_data.get("multiplier", 1.0)) * 100.0))
		"jolt_dash_discharge":
			return "dash discharges jolt for %.0f damage" % float(effect_data.get("damage", 0.0))
		"jolt_nova":
			return "jolt erupts in a %.1fs nova" % float(effect_data.get("timer", 0.0))
		"low_hp_boost":
			return "below %d%% HP, deal %d%% damage" % [int(round(float(effect_data.get("hp_threshold", 0.0)) * 100.0)), int(round(float(effect_data.get("multiplier", 1.0)) * 100.0))]
		"momentum":
			return _momentum_text(effect_data)
		"momentum_aerial":
			return "aerial hits deal %d%% (+%d%% posture) and landing gives %.0f momentum" % [int(round(float(effect_data.get("multiplier", 1.0)) * 100.0)), int(round((float(effect_data.get("posture_multiplier", 1.5)) - 1.0) * 100.0)), float(effect_data.get("landing_gain", 0.0))]
		"momentum_deflect":
			return "dash-through deflect deals %.0f posture (+%.0f momentum)" % [float(effect_data.get("posture", 0.0)), float(effect_data.get("momentum", 0.0))]
		"momentum_flurry":
			return "at %.0f momentum, spend %.0f for %.0f flurry damage (+%.0f posture)" % [float(effect_data.get("threshold", 0.0)), float(effect_data.get("cost", 0.0)), float(effect_data.get("damage", 0.0)), float(effect_data.get("posture_damage", 8.0))]
		"momentum_speed":
			return "adds %.0f speed from momentum" % float(effect_data.get("move_speed", 0.0))
		"phoenix":
			return "phoenix revive heals %d%% and grants %.1fs invuln" % [int(round(float(effect_data.get("heal_ratio", 0.0)) * 100.0)), float(effect_data.get("invuln", 0.0))]
		"sparrow":
			return "after dash, next hit deals %d%% for %.1fs" % [int(round(float(effect_data.get("multiplier", 1.0)) * 100.0)), float(effect_data.get("window", 0.0))]
		"stagger":
			return "%d%% chance to stagger on hit" % int(round(float(effect_data.get("chance", 0.0)) * 100.0))
		"stance_drunken":
			return "yielding stance: longer dash and %.0f break damage" % float(effect_data.get("break_damage", 0.0))
		"stance_tiger":
			return "bear stance reflects %d%% for %.0fs" % [int(round(float(effect_data.get("reflect", 0.0)) * 100.0)), float(effect_data.get("duration", 0.0))]
		"stat_delta":
			return _stat_delta_text(effect_data)
		"twin_strike":
			return "heavy can strike twice at %d%% power" % int(round(float(effect_data.get("multiplier", 1.0)) * 100.0))
		"venom":
			return "applies %d venom (%.1f dps/%.0fs)" % [int(effect_data.get("stacks", 0)), float(effect_data.get("dps", 0.0)), float(effect_data.get("timer", 0.0))]
		"venom_heavy_detonate":
			return "heavy detonates venom (%.0f/stack)" % float(effect_data.get("damage_per_stack", 0.0))
		"venom_slow":
			return "venom slows movement by %d%%" % int(round((1.0 - float(effect_data.get("multiplier", 1.0))) * 100.0))
		"venom_spread":
			return "venom spreads on kill"
		_:
			return "[%s]?" % str(effect_data.get("type", "missing"))

static func has_template(effect_type: String) -> bool:
	return not describe_effect({"type": effect_type}).ends_with("?")

static func _effects_for_tier(boon: Dictionary, tier: String) -> Array[Dictionary]:
	var kind: String = str(boon.get("kind", ""))
	if kind == "duo" or kind == "mastery":
		var single: Dictionary = boon.get("effect", {}) as Dictionary
		var single_out: Array[Dictionary] = []
		if not single.is_empty():
			single_out.append(single)
		return single_out

	var target: String = _normalize_tier(tier)
	var out: Array[Dictionary] = []
	var tiers: Dictionary = boon.get("tiers", {}) as Dictionary
	for current_tier in BoonFactoryScript.TIER_ORDER:
		if not tiers.has(current_tier):
			continue
		var tier_data: Dictionary = tiers[current_tier] as Dictionary
		if tier_data.has("effect"):
			out.append(tier_data.get("effect", {}) as Dictionary)
		for rider in tier_data.get("riders", []) as Array:
			if typeof(rider) == TYPE_DICTIONARY:
				out.append(rider as Dictionary)
		if current_tier == target:
			break
	return out

static func _normalize_tier(tier: String) -> String:
	var lowered: String = str(tier).to_lower()
	return lowered if BoonFactoryScript.TIER_ORDER.has(lowered) else "common"

static func _short_effect(effect_data: Dictionary) -> String:
	match str(effect_data.get("type", "")):
		"venom", "venom_slow", "venom_spread", "venom_heavy_detonate":
			return "Venom"
		"jolt", "jolt_amp", "jolt_nova", "jolt_dash_discharge":
			return "Jolt"
		"deflect", "deflect_reduce", "deflect_redirect", "deflect_riposte_dmg", "stagger", "echo":
			return "Deflect"
		"block_chip", "low_hp_boost", "phoenix":
			return "Guard"
		"dash_stab", "flowing_water", "gaze", "momentum", "momentum_aerial", "momentum_deflect", "momentum_flurry", "momentum_speed", "sparrow":
			return "Momentum"
		"bleed_on_heavy", "intent_mark", "intent_crit_vs_marked", "intent_dash_flash", "intent_reach", "twin_strike":
			return "Intent"
		"stance_drunken", "stance_tiger":
			return "Stance"
		"stat_delta":
			return _short_stat_delta(effect_data)
		"break_heal":
			return "Heal"
		_:
			return str(effect_data.get("type", "Effect")).capitalize()

static func _stat_delta_text(effect_data: Dictionary) -> String:
	var parts: Array[String] = []
	for key in (effect_data.get("flat", {}) as Dictionary).keys():
		parts.append("%+.0f %s" % [float((effect_data.get("flat", {}) as Dictionary)[key]), _stat_label(str(key))])
	for key in (effect_data.get("scaled", {}) as Dictionary).keys():
		parts.append("+%d%% %s" % [int(round(float((effect_data.get("scaled", {}) as Dictionary)[key]) * 100.0)), _stat_label(str(key))])
	return ", ".join(parts) if not parts.is_empty() else "improves stats"

static func _short_stat_delta(effect_data: Dictionary) -> String:
	var flat: Dictionary = effect_data.get("flat", {}) as Dictionary
	var scaled: Dictionary = effect_data.get("scaled", {}) as Dictionary
	if flat.has("health_max") or flat.has("health_current"):
		return "Health"
	if flat.has("posture_max") or flat.has("posture_current"):
		return "Posture"
	if flat.has("rage_max"):
		return "Rage"
	if scaled.has("move_speed") or scaled.has("dash_speed") or scaled.has("air_dash_speed"):
		return "Speed"
	if scaled.has("posture_recovery_rate"):
		return "Recovery"
	return "Stats"

static func _momentum_text(effect_data: Dictionary) -> String:
	if effect_data.has("dash_gain"):
		return "dash grants %.0f momentum (decays %.0f/s)" % [float(effect_data.get("dash_gain", 0.0)), float(effect_data.get("decay", 0.0))]
	if effect_data.has("move_gain_per_second"):
		return "movement builds %.0f momentum/s" % float(effect_data.get("move_gain_per_second", 0.0))
	return "builds momentum"

static func _stat_label(key: String) -> String:
	match key:
		"health_max", "health_current":
			return "health"
		"posture_max", "posture_current":
			return "posture"
		"rage_max", "rage_current":
			return "rage"
		"parry_window":
			return "parry window"
		"posture_recovery_rate":
			return "posture recovery"
		"move_speed":
			return "move speed"
		"dash_speed":
			return "dash speed"
		"air_dash_speed":
			return "air dash speed"
		_:
			return key.replace("_", " ")

static func _bonus_percent(effect_data: Dictionary, key: String) -> int:
	return int(round(float(effect_data.get(key, 0.0)) * 100.0))

static func _humanize_id(id: String) -> String:
	var words: PackedStringArray = id.replace("_", " ").split(" ", false)
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)
