class_name RunVars
extends RefCounted

signal modified(type: Var, old_value: int, new_value: int)

# WARNING: Enums are stored as ints in resources (e.g. Relics) and savegames,
#          so we can't remove deprecated values without explicit renumbering.
enum Var {
	HAND_SIZE,
	REDRAWS,
	_DEPRECATED_REFUSALS,
	_DEPRECATED_STAGE_CHOICES,
	CARD_REWARD_CHOICES,
	CURRENT_INSPIRATION,  # Modifier-less
	MAX_INSPIRATION,
	_DEPRECATED_SATISFACTION,  # Modifier-less
	CARD_TIER_BONUS_PERCENT,
	CARD_REWARD_REROLLS,
	RELIC_REWARD_REROLLS,
	_DEPRECATED_AUTO_CONNECTED_SETTLEMENTS,  # Modifier-less
	DISCARDS_BLOCKED,  # Modifier-less
	ABILITY_CASTS_BLOCKED,  # Modifier-less
	SHOP_PRICE_PERCENTAGE,
	STAGE_REQUIREMENTS_PERCENTAGE,
	DIVINE_ABILITY_BONUS,
	FILL_ABILITY_BONUS,
	RELIC_REWARD_CHOICES,
	_DEPRECATED_RECYCLE_ABILITY_BONUS,
	DRAW_DECK_ORDERED,  # Boolean
	CARD_REWARDS_PER_STAGE,
	MAX_EVENTS_PER_STAGE,
	MIN_DECK_SIZE,
	EXCESS_BONUS_PER_INSIGHT,

	# These are booleans for doubling different bonuses.
	FOCUS_FOOD,
	FOCUS_SAFETY,
	FOCUS_BEAUTY,
	FOCUS_HARMONY,
	FOCUS_KNOWLEDGE,
	FOCUS_ADVENTURE,
	FOCUS_PRODUCTIVITY,

	HEAL_PER_STAGE,
	GOAL_REROLLS,
	HAUNTING_PACIFIES,
	PLACE_SMALL_BUILDING_COUNT,
	PLACE_LARGE_BUILDING_COUNT,
	PLACE_SQUARE_COUNT,
	PLACE_LAKE_COUNT,
	SHIELD,
	INSPIRATION_LOST_PER_NEGATIVE_BONUS,
	MULLIGANS,
	INSIGHT_EXTRA_PERCENT,
	HAUNTING_CHANCE_PERCENT,
	EVENT_REQS_BONUS_PERCENT,
	INSPIRATION_LOSS_PER_LACK,
	BONUS_LOSS_PERCENT,
	BONUS_GAIN_PERCENT,
	INSPIRATION_GAIN_PERCENT,
	INSPIRATION_LOSS_PERCENT,
	REVEAL_RADIUS_PERCENT,
	NEGATIVE_CARD_PROTECTION,
	HAUNTING_BLOCKS_PER_STAGE,
	SATISFY_ABILITY_BONUS_PERCENT,
	EXTRA_SURVEY_SLOTS,
	EXTRA_EVENT_ASPECT_REQS,
	CARES_ABOUT_UPGRADE_TAGS,
	CAST_ALL_ON_TURN_END,
	EXTRA_HAUNTING_SLOTS,
	SUPPORT_ENABLED,
	EXTRA_SPOTS,
}

const DEFAULTS: Dictionary[Var, int] = {
	Var.HAND_SIZE: 5,
	Var.REDRAWS: 1,
	Var.CARD_REWARD_CHOICES: 3,
	Var.CURRENT_INSPIRATION: 25,
	Var.MAX_INSPIRATION: 25,
	Var.CARD_TIER_BONUS_PERCENT: 0,
	Var.CARD_REWARD_REROLLS: 0,
	Var.RELIC_REWARD_REROLLS: 0,
	Var.DISCARDS_BLOCKED: 0,
	Var.ABILITY_CASTS_BLOCKED: 0,
	Var.SHOP_PRICE_PERCENTAGE: 100,
	Var.STAGE_REQUIREMENTS_PERCENTAGE: 100,
	Var.DIVINE_ABILITY_BONUS: 0,
	Var.FILL_ABILITY_BONUS: 0,
	Var.RELIC_REWARD_CHOICES: 3,
	Var.DRAW_DECK_ORDERED: 0,
	Var.CARD_REWARDS_PER_STAGE: 1,
	Var.MAX_EVENTS_PER_STAGE: 0,
	Var.MIN_DECK_SIZE: 10,
	Var.EXCESS_BONUS_PER_INSIGHT: 10,

	Var.FOCUS_FOOD: 0,
	Var.FOCUS_SAFETY: 0,
	Var.FOCUS_BEAUTY: 0,
	Var.FOCUS_HARMONY: 0,
	Var.FOCUS_KNOWLEDGE: 0,
	Var.FOCUS_ADVENTURE: 0,
	Var.FOCUS_PRODUCTIVITY: 0,

	Var.HEAL_PER_STAGE: 0,
	Var.GOAL_REROLLS: 0,
	Var.HAUNTING_PACIFIES: 0,
	Var.PLACE_SMALL_BUILDING_COUNT: 0,
	Var.PLACE_LARGE_BUILDING_COUNT: 0,
	Var.PLACE_SQUARE_COUNT: 0,
	Var.PLACE_LAKE_COUNT: 0,
	Var.SHIELD: 0,
	Var.INSPIRATION_LOST_PER_NEGATIVE_BONUS: 2,
	Var.MULLIGANS: 0,
	Var.INSIGHT_EXTRA_PERCENT: 0,
	Var.HAUNTING_CHANCE_PERCENT: 100,
	Var.EVENT_REQS_BONUS_PERCENT: 100,

	Var.INSPIRATION_LOSS_PER_LACK: 5,

	Var.BONUS_LOSS_PERCENT: 100,
	Var.BONUS_GAIN_PERCENT: 100,
	Var.INSPIRATION_GAIN_PERCENT: 100,
	Var.INSPIRATION_LOSS_PERCENT: 100,
	Var.REVEAL_RADIUS_PERCENT: 100,
	Var.NEGATIVE_CARD_PROTECTION: 0,
	Var.HAUNTING_BLOCKS_PER_STAGE: 0,
	Var.SATISFY_ABILITY_BONUS_PERCENT: 0,
	Var.EXTRA_SURVEY_SLOTS: 0,
	Var.EXTRA_EVENT_ASPECT_REQS: 0,
	Var.CARES_ABOUT_UPGRADE_TAGS: 0,
	Var.CAST_ALL_ON_TURN_END: 0,
	Var.EXTRA_HAUNTING_SLOTS: 0,
	Var.SUPPORT_ENABLED: 1,
	Var.EXTRA_SPOTS: 0,
}

var _base_values: Dictionary[Var, int] = DEFAULTS.duplicate()
var _modifiers: Array[VarModifier] = []

func get_base_value(type: Var) -> int:
	return _base_values[type]

func get_current_value(type: Var) -> int:
	var value := get_base_value(type)
	for modifier in _modifiers:
		if modifier.type == type:
			value += modifier.delta
	if type == Var.MAX_INSPIRATION:
		value = max(value, 1)
	elif type == Var.RELIC_REWARD_CHOICES:
		value = max(value, 1)
	return value

func set_base_value(type: Var, new_base_value: int) -> void:
	var old_value := get_current_value(type)

	# Special case: clamp inspiration to max.
	if type == Var.CURRENT_INSPIRATION:
		new_base_value = clampi(new_base_value, 0, get_current_value(Var.MAX_INSPIRATION))
	elif type == Var.MAX_INSPIRATION:
		new_base_value = max(new_base_value, 1)

	_base_values[type] = new_base_value

	var new_value := get_current_value(type)
	if old_value != new_value:
		_emit_modified(type, old_value, new_value)

func modify_base_value(type: Var, delta: int) -> void:
	set_base_value(type, get_base_value(type) + delta)

func add_modifier(type: Var, delta: int, tag: String) -> void:
	var old_value := get_current_value(type)

	# Modifiers with the same tag are overwritten.
	# Not going through remove_modifier() to avoid side effects from replacing midifiers (e.g. max inspiration).
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].tag == tag:
			_modifiers.remove_at(i)
	var modifier := VarModifier.new()
	modifier.type = type
	modifier.delta = delta
	modifier.tag = tag
	_modifiers.append(modifier)

	var new_value := get_current_value(type)
	if old_value != new_value:
		_emit_modified(type, old_value, new_value)

func remove_modifier(tag: String) -> void:
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].tag == tag:
			var type := _modifiers[i].type
			var old_value := get_current_value(type)
			_modifiers.remove_at(i)
			var new_value := get_current_value(type)
			if old_value != new_value:
				_emit_modified(type, old_value, new_value)

func encode() -> Dictionary:
	var encoded: Dictionary = {}
	for key in _base_values:
		encoded[key] = _base_values[key]
	var encoded_modifiers: Array = []
	for modifier in _modifiers:
		encoded_modifiers.append([modifier.type, modifier.delta, modifier.tag])
	encoded['modifiers'] = encoded_modifiers
	return encoded

func decode(encoded_data: Dictionary) -> void:
	_base_values = DEFAULTS.duplicate()
	_modifiers = []
	for key: String in encoded_data:
		if key == 'modifiers':
			for encoded_modifier: Array in encoded_data[key]:
				var modifier := VarModifier.new()
				modifier.type = encoded_modifier[0] as Var
				modifier.delta = encoded_modifier[1] as int
				modifier.tag = encoded_modifier[2] as String
				_modifiers.append(modifier)
		else:
			_base_values[key.to_int() as Var] = encoded_data[key] as int

func _emit_modified(type: Var, old_value: int, new_value: int) -> void:
	modified.emit(type, old_value, new_value)
	if type == Var.MAX_INSPIRATION:
		if get_current_value(Var.CURRENT_INSPIRATION) > get_current_value(Var.MAX_INSPIRATION):
			set_base_value(Var.CURRENT_INSPIRATION, get_current_value(Var.MAX_INSPIRATION))

class VarModifier:
	var type: Var
	var delta: int
	var tag: String
