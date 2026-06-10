class_name AttackCatalog
extends RefCounted

# Attack data lives in res://data/Attacks/Attacks.json.
# These wrappers preserve the legacy named API; new AI attacks only need a JSON entry.

static func by_id(attack_id: String) -> Variant:
	return DataManager.get_attack_def(attack_id)

static func hu_light() -> Variant: return by_id("hu_light")
static func hu_heavy() -> Variant: return by_id("hu_heavy")
static func bandit_slash() -> Variant: return by_id("bandit_slash")
static func bandit_thrust_perilous() -> Variant: return by_id("bandit_thrust_perilous")
static func bandit_overhead() -> Variant: return by_id("bandit_overhead")
static func drunken_light() -> Variant: return by_id("drunken_light")
static func drunken_heavy() -> Variant: return by_id("drunken_heavy")
static func tiger_light() -> Variant: return by_id("tiger_light")
static func tiger_heavy() -> Variant: return by_id("tiger_heavy")
static func spear_long_thrust() -> Variant: return by_id("spear_long_thrust")
static func spear_wide_swing() -> Variant: return by_id("spear_wide_swing")
static func ronin_slash() -> Variant: return by_id("ronin_slash")
static func ronin_thrust() -> Variant: return by_id("ronin_thrust")
static func ronin_sweep() -> Variant: return by_id("ronin_sweep")
static func ronin_perilous_thrust() -> Variant: return by_id("ronin_perilous_thrust")
static func disciple_slash() -> Variant: return by_id("disciple_slash")
static func disciple_thrust() -> Variant: return by_id("disciple_thrust")
static func disciple_sweep() -> Variant: return by_id("disciple_sweep")
static func disciple_counter() -> Variant: return by_id("disciple_counter")
static func disciple_jump_attack() -> Variant: return by_id("disciple_jump_attack")
static func smoke_thrust() -> Variant: return by_id("smoke_thrust")
static func flicker_slash() -> Variant: return by_id("flicker_slash")
static func assassin_backstab() -> Variant: return by_id("assassin_backstab")
static func assassin_perilous_grab() -> Variant: return by_id("assassin_perilous_grab")
static func bear_swipe() -> Variant: return by_id("bear_swipe")
static func bear_overhead() -> Variant: return by_id("bear_overhead")
static func bear_stomp() -> Variant: return by_id("bear_stomp")
static func bear_crush_grab() -> Variant: return by_id("bear_crush_grab")
static func mountain_breaker() -> Variant: return by_id("mountain_breaker")
static func bear_roar_aoe() -> Variant: return by_id("bear_roar_aoe")
