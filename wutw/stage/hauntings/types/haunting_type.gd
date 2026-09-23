@tool
class_name HauntingType
extends Resource

static var _group_loader := AsyncLoadedGroup.new('res://stage/hauntings/types/resourcegroup_haunting_types.tres')

enum SpotAttachMode { NONE, GLOBAL, SPOT }
enum SettlementAttachMode { NONE, GLOBAL, SETTLEMENT }

@export var haunting_id: String
@export_category('Flavor')
@export var name: String
@export var name_japanese: String
@export var name_realistic: String
@export var name_translation: String
@export_multiline var description: String
@export_multiline var description_realistic: String
@export_multiline var description_long: String
@export var image_small: Texture2D
@export var image_credit: ArtPiece
@export var image_small_realistic: Texture2D
@export var image_realistic_credit: ArtPiece
@export_category('Gameplay')
@export var spot_type: SpotType
@export var base_aspect_types: Array[AspectType]
@export var extra_aspect_type: AspectType
@export var scaling_bonus_type: BonusType
@export var trigger: HauntingTrigger
@export var effect: HauntingEffect
@export var mechanics_description_override: String
@export var spot_attach_mode: SpotAttachMode
@export var settlement_attach_mode: SettlementAttachMode

static var _all_haunting_types: Array[HauntingType] = []

static func get_all_haunting_types() -> Array[HauntingType]:
	if not _all_haunting_types:
		_group_loader.fetch_loaded(_all_haunting_types)
	return _all_haunting_types

static func get_haunting_type_by_id(target_haunting_type_id: String) -> HauntingType:
	for haunting_type in get_all_haunting_types():
		if haunting_type.haunting_id == target_haunting_type_id:
			return haunting_type
	return null

static func get_haunting_types_by_spot_type(target_spot_type: SpotType) -> Array[HauntingType]:
	var result: Array[HauntingType] = []
	for haunting_type in get_all_haunting_types():
		if haunting_type.spot_attach_mode == SpotAttachMode.NONE:
			continue
		if haunting_type.spot_type == target_spot_type:
			result.append(haunting_type)
	return result

static func get_base_haunt_probability(run: Run) -> float:
	var total_bonuses := 0
	var amounts := run.get_bonus_amounts()
	for bonus_type in amounts.get_bonus_types():
		total_bonuses += absi(amounts.get_amount(bonus_type))
	var base_probability := run.scaling.haunting_base_probability
	base_probability += (float(total_bonuses) / run.scaling.haunting_bonus_per_extra_chance) / 100.0
	return base_probability

static func choose_spot_hauntings(spot_types: Array[SpotType], rng: RandomState, leftover_roll: float) -> HauntingsRollResult:
	var result := HauntingsRollResult.new()
	if not Utils.are_hauntings_unlocked():
		for _i in spot_types:
			result.hauntings.append(null)
		return result

	var run := Utils.get_active_run()
	var cumulative_roll := leftover_roll
	for target_spot_type in spot_types:
		# Calculate roll.
		var base_probability := get_base_haunt_probability(run)
		var haunting_roll := rng.rand_float(
			base_probability * (1.0 - run.scaling.haunting_variance),
			base_probability * (1.0 + run.scaling.haunting_variance))
		haunting_roll *= run.get_var(RunVars.Var.HAUNTING_CHANCE_PERCENT) / 100.0

		# Accumulate and choose haunting if at cutoff.
		cumulative_roll += haunting_roll
		if cumulative_roll >= 1.0:
			var options: Dictionary[HauntingType, float]
			var universal_hauntings := HauntingType.get_haunting_types_by_spot_type(null)
			for haunting_type in universal_hauntings:
				options[haunting_type] = (run.scaling.haunting_standalone_probability) / universal_hauntings.size()
			var specific_hauntings := HauntingType.get_haunting_types_by_spot_type(target_spot_type)
			for haunting_type in specific_hauntings:
				options[haunting_type] = (1.0 - run.scaling.haunting_standalone_probability) / specific_hauntings.size()
			for banned in GlobalSaveGame.get_banned_hauntings():
				options.erase(banned)
			var cur_stage := run.get_current_stage_index()
			for haunting_type in options:
				var stages_since := cur_stage - run.get_run_data().recent_hauntings.get(haunting_type, cur_stage) as int
				if stages_since > 0:
					options[haunting_type] /= max(1, 10 - stages_since)
			if options:
				for picked in result.hauntings:
					if options.size() <= 1:
						break
					else:
						options.erase(picked)
				result.hauntings.append(rng.pick_weighted_dict(options)[0] as HauntingType)
			else:
				push_warning('No valid hauntings to spawn. Skipping.')
			cumulative_roll -= 1.0
		else:
			result.hauntings.append(null)
	result.leftover_roll = cumulative_roll
	return result

static func choose_harmonization_hauntings(settlements: Array[Settlement], rng: RandomState, leftover_roll: float) -> HauntingsRollResult:
	var result := HauntingsRollResult.new()
	if not Utils.are_hauntings_unlocked():
		for _i in settlements:
			result.hauntings.append(null)
		return result

	var run := Utils.get_active_run()
	if run.get_current_season_index() < run.scaling.first_season_with_settlement_hauntings:
		for _i in settlements:
			result.hauntings.append(null)
		return result

	var max_hauntings_left := 2 * (1 + run.get_current_season_index())

	var cumulative_roll := leftover_roll
	for settlement in settlements:
		if max_hauntings_left == 0:
			result.hauntings.append(null)
			continue
		# Calculate roll.
		var base_probability := get_base_haunt_probability(run)
		var haunting_roll := rng.rand_float(
			base_probability * (1.0 - run.scaling.haunting_variance),
			base_probability * (1.0 + run.scaling.haunting_variance))
		haunting_roll *= run.get_var(RunVars.Var.HAUNTING_CHANCE_PERCENT) / 100.0

		# Accumulate and choose haunting if at cutoff.
		cumulative_roll += haunting_roll

		var settelment_yields := 0
		for bonus_type in settlement.state.bonus_amounts.get_bonus_types():
			settelment_yields += settlement.state.bonus_amounts.get_amount(bonus_type)

		var is_complete := settlement.get_unsatisfied_lacks().is_empty() and settlement.is_settlement_connected()
		if cumulative_roll >= 1.0:
			var options: Dictionary[HauntingType, float]
			for haunting_type in HauntingType.get_all_haunting_types():
				if haunting_type.settlement_attach_mode == SettlementAttachMode.NONE:
					continue
				if is_complete and haunting_type.settlement_attach_mode == SettlementAttachMode.SETTLEMENT:
					continue
				if haunting_type.spot_type and haunting_type.spot_type not in settlement.state.spot_types:
					continue
				options[haunting_type] = 0.0 if haunting_type in result.hauntings else 1.0
				if Utils.ensure(haunting_type.scaling_bonus_type != null):
					var associated_bonus_amount := settlement.state.bonus_amounts.get_amount(
						haunting_type.scaling_bonus_type)
					options[haunting_type] *= pow((1.0 + associated_bonus_amount) / float(settelment_yields), 2)
			for banned in GlobalSaveGame.get_banned_hauntings():
				options.erase(banned)
			if options:
				result.hauntings.append(rng.pick_weighted_dict(options)[0] as HauntingType)
				max_hauntings_left -= 1
			else:
				push_warning('No valid hauntings to spawn. Skipping.')
			cumulative_roll -= 1.0
		else:
			result.hauntings.append(null)
	result.leftover_roll = cumulative_roll
	return result

func get_effective_name() -> String:
	return tr(name_realistic) if Utils.is_realistic_era() else tr(name)

func get_toal_aspect_slots(run: Run, mode: HauntingTrigger.Mode) -> Array[AspectType]:
	var result: Array[AspectType]
	for aspect_type in base_aspect_types:
		result.append(aspect_type)

	var bonus_amount := run.get_bonus_amounts().get_amount(scaling_bonus_type)
	@warning_ignore('integer_division')
	var extra_slots := bonus_amount / run.scaling.haunting_bonus_per_slot
	extra_slots += run.get_var(RunVars.Var.EXTRA_HAUNTING_SLOTS)
	var max_slots := (run.scaling.haunting_max_slots_spot if mode == HauntingTrigger.Mode.SPOT
					  else run.scaling.haunting_max_slots_harmonization)
	for _i in extra_slots:
		result.append(extra_aspect_type)
		if result.size() >= max_slots:
			break

	return result

func get_mechanics_description(mode: HauntingTrigger.Mode) -> String:
	if mechanics_description_override:
		return mechanics_description_override
	else:
		return tr('When %s, %s.') % [trigger.get_description(mode), effect.get_description(mode)]

func get_localized_name() -> String:
	match GameSettings.Japanese.haunting_names.value():
		GameSettings.HauntingNameDisplayType.ROMAJI:
			return tr(name)
		GameSettings.HauntingNameDisplayType.KANJI:
			return name_japanese
		GameSettings.HauntingNameDisplayType.HIRAGANA:
			var hiragana := JapaneseUtils.romaji_to_hiragana(name)
			if hiragana.begins_with('おう'):  # HACK
				hiragana = 'おお' + hiragana.substr(2)
			return hiragana
		GameSettings.HauntingNameDisplayType.MEANING:
			return tr(name_translation)
	Utils.ensure(false)
	return name

class HauntingsRollResult extends RefCounted:
	var hauntings: Array[HauntingType]
	var leftover_roll: float = 0.0
