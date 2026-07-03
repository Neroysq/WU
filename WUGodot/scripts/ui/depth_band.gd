class_name DepthBand
extends RefCounted

const BAND_FOOTHILL: String = "foothill"
const BAND_MID: String = "mid"
const BAND_HIGH: String = "high"
const BAND_GATE: String = "gate"

static func normalize(band: String) -> String:
	match str(band).to_lower():
		BAND_FOOTHILL:
			return BAND_FOOTHILL
		BAND_MID:
			return BAND_MID
		BAND_HIGH:
			return BAND_HIGH
		BAND_GATE:
			return BAND_GATE
		_:
			return BAND_FOOTHILL

static func band_for_tier(tier: int) -> String:
	if tier <= 1:
		return BAND_FOOTHILL
	if tier <= 3:
		return BAND_MID
	return BAND_HIGH

static func band_for_node(node: Variant) -> String:
	if node == null:
		return BAND_FOOTHILL
	if int(node.node_type) == MapNode.NodeType.BOSS:
		return BAND_GATE
	return band_for_tier(int(node.tier))

static func band_for_run(run_state: Variant) -> String:
	if run_state == null or not run_state.has_method("get_current_node"):
		return BAND_FOOTHILL
	return band_for_node(run_state.get_current_node())

static func band_for_context(ctx: Variant) -> String:
	if ctx != null:
		var override: String = str(ctx.depth_band_override)
		if not override.is_empty():
			return normalize(override)
	return band_for_run(ctx.run_state if ctx != null else null)
