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
	def.range_units = 210.0
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
	def.range_units = 234.0
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
	def.range_units = 140.0
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
	def.range_units = 150.0
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

# --- Bandit Swordsman (Easy) ---

static func bandit_overhead():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bandit_overhead"
	def.duration = 0.95
	def.windup_end = 0.50
	def.active_end = 0.65
	def.damage = 14.0
	def.posture_damage = 30.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 145.0
	def.knockback_units = 380.0
	return def

# --- Bandit Spearman (Easy, reach) ---

static func spear_long_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "spear_long_thrust"
	def.duration = 0.90
	def.windup_end = 0.50
	def.active_end = 0.62
	def.damage = 11.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 180.0
	def.knockback_units = 280.0
	return def

static func spear_wide_swing():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "spear_wide_swing"
	def.duration = 1.05
	def.windup_end = 0.55
	def.active_end = 0.72
	def.damage = 13.0
	def.posture_damage = 28.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 175.0
	def.knockback_units = 400.0
	return def

# --- Wandering Ronin (Medium) ---

static func ronin_slash():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_slash"
	def.duration = 0.65
	def.windup_end = 0.30
	def.active_end = 0.42
	def.damage = 12.0
	def.posture_damage = 26.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 150.0
	def.knockback_units = 300.0
	return def

static func ronin_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_thrust"
	def.duration = 0.70
	def.windup_end = 0.35
	def.active_end = 0.48
	def.damage = 14.0
	def.posture_damage = 22.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 160.0
	def.knockback_units = 320.0
	return def

static func ronin_sweep():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_sweep"
	def.duration = 0.85
	def.windup_end = 0.40
	def.active_end = 0.58
	def.damage = 16.0
	def.posture_damage = 32.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 150.0
	def.knockback_units = 420.0
	return def

static func ronin_perilous_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "ronin_perilous_thrust"
	def.duration = 0.90
	def.windup_end = 0.50
	def.active_end = 0.65
	def.damage = 18.0
	def.posture_damage = 24.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.range_units = 165.0
	def.knockback_units = 360.0
	return def

# --- Sect Disciple (Hard, elite mirror-match) ---

static func disciple_slash():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_slash"
	def.duration = 0.55
	def.windup_end = 0.22
	def.active_end = 0.34
	def.damage = 13.0
	def.posture_damage = 26.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 150.0
	def.knockback_units = 300.0
	return def

static func disciple_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_thrust"
	def.duration = 0.60
	def.windup_end = 0.28
	def.active_end = 0.40
	def.damage = 14.0
	def.posture_damage = 24.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 155.0
	def.knockback_units = 320.0
	return def

static func disciple_sweep():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_sweep"
	def.duration = 0.75
	def.windup_end = 0.35
	def.active_end = 0.50
	def.damage = 16.0
	def.posture_damage = 34.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 150.0
	def.knockback_units = 400.0
	return def

static func disciple_counter():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_counter"
	def.duration = 0.45
	def.windup_end = 0.12
	def.active_end = 0.28
	def.damage = 15.0
	def.posture_damage = 36.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 150.0
	def.knockback_units = 360.0
	return def

static func disciple_jump_attack():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "disciple_jump_attack"
	def.duration = 0.80
	def.windup_end = 0.35
	def.active_end = 0.52
	def.damage = 18.0
	def.posture_damage = 30.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 160.0
	def.knockback_units = 440.0
	def.forward_lunge = 200.0
	return def

# --- Masked Assassin (Hard, elite teleport gimmick) ---

static func smoke_thrust():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "smoke_thrust"
	def.duration = 0.50
	def.windup_end = 0.18
	def.active_end = 0.30
	def.damage = 12.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 68.0
	def.knockback_units = 260.0
	return def

static func flicker_slash():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "flicker_slash"
	def.duration = 0.40
	def.windup_end = 0.12
	def.active_end = 0.24
	def.damage = 10.0
	def.posture_damage = 18.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 72.0
	def.knockback_units = 240.0
	return def

static func assassin_backstab():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "assassin_backstab"
	def.duration = 0.55
	def.windup_end = 0.20
	def.active_end = 0.35
	def.damage = 20.0
	def.posture_damage = 16.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 64.0
	def.knockback_units = 300.0
	return def

static func assassin_perilous_grab():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "assassin_perilous_grab"
	def.duration = 0.85
	def.windup_end = 0.45
	def.active_end = 0.60
	def.damage = 22.0
	def.posture_damage = 10.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.is_grab = true
	def.range_units = 60.0
	def.knockback_units = 200.0
	return def

# --- Xiong Tie / Iron Bear (Boss) ---

static func bear_swipe():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_swipe"
	def.duration = 0.80
	def.windup_end = 0.40
	def.active_end = 0.55
	def.damage = 16.0
	def.posture_damage = 32.0
	def.is_heavy = false
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 165.0
	def.knockback_units = 380.0
	return def

static func bear_overhead():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_overhead"
	def.duration = 1.10
	def.windup_end = 0.55
	def.active_end = 0.72
	def.damage = 22.0
	def.posture_damage = 44.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 160.0
	def.knockback_units = 500.0
	return def

static func bear_stomp():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_stomp"
	def.duration = 0.95
	def.windup_end = 0.50
	def.active_end = 0.65
	def.damage = 14.0
	def.posture_damage = 38.0
	def.is_heavy = true
	def.is_perilous = false
	def.is_parryable = true
	def.range_units = 150.0
	def.knockback_units = 350.0
	return def

static func bear_crush_grab():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_crush_grab"
	def.duration = 1.20
	def.windup_end = 0.60
	def.active_end = 0.80
	def.damage = 0.0
	def.posture_damage = 0.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.is_grab = true
	def.range_units = 170.0
	def.knockback_units = 0.0
	def.forward_lunge = 150.0
	return def

static func mountain_breaker():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "mountain_breaker"
	def.duration = 1.40
	def.windup_end = 0.70
	def.active_end = 0.95
	def.damage = 28.0
	def.posture_damage = 50.0
	def.is_heavy = true
	def.is_perilous = true
	def.is_parryable = false
	def.range_units = 175.0
	def.knockback_units = 600.0
	def.forward_lunge = 600.0
	return def

static func bear_roar_aoe():
	var def: Variant = AttackDefinitionScript.new()
	def.id = "bear_roar_aoe"
	def.duration = 0.90
	def.windup_end = 0.45
	def.active_end = 0.65
	def.damage = 8.0
	def.posture_damage = 20.0
	def.is_heavy = false
	def.is_perilous = true
	def.is_parryable = false
	def.range_units = 140.0
	def.knockback_units = 450.0
	return def
