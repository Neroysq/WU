class_name AttackCatalog
extends RefCounted

const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")

static func hu_light():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "hu_light"
	def.duration = 0.50
	def.windup_end = 0.18
	def.active_end = 0.30
	def.damage = 12.0
	def.posture_damage = 22.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 72.0
	def.knockback_units = 300.0
	return def

static func hu_heavy():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "hu_heavy"
	def.duration = 0.85
	def.windup_end = 0.40
	def.active_end = 0.55
	def.damage = 22.0
	def.posture_damage = 42.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 84.0
	def.knockback_units = 420.0
	return def

static func bandit_slash():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bandit_slash"
	def.duration = 0.80
	def.windup_end = 0.45
	def.active_end = 0.60
	def.damage = 10.0
	def.posture_damage = 24.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 68.0
	def.knockback_units = 260.0
	return def

static func bandit_thrust_perilous():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bandit_thrust_perilous"
	def.duration = 0.90
	def.windup_end = 0.55
	def.active_end = 0.68
	def.damage = 14.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.range_units = 88.0
	def.knockback_units = 320.0
	return def

static func drunken_light():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "drunken_light"
	def.duration = 0.55
	def.windup_end = 0.20
	def.active_end = 0.32
	def.damage = 12.0
	def.posture_damage = 18.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.ignores_block = true
	def.range_units = 68.0
	def.knockback_units = 280.0
	return def

static func drunken_heavy():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "drunken_heavy"
	def.duration = 1.10
	def.windup_end = 0.45
	def.active_end = 0.60
	def.damage = 30.8
	def.posture_damage = 58.8
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 84.0
	def.knockback_units = 480.0
	return def

static func tiger_light():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "tiger_light"
	def.duration = 0.40
	def.windup_end = 0.14
	def.active_end = 0.24
	def.damage = 12.0
	def.posture_damage = 22.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 72.0
	def.knockback_units = 280.0
	return def

static func tiger_heavy():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "tiger_heavy"
	def.duration = 0.85
	def.windup_end = 0.40
	def.active_end = 0.55
	def.damage = 22.0
	def.posture_damage = 42.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 126.0
	def.knockback_units = 500.0
	return def
