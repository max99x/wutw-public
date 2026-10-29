@tool
class_name HauntingTrigger_BonusGained
extends HauntingTrigger

@export var bonus_type: BonusType
@export var any_spot: bool = true

func get_description(mode: HauntingTrigger.Mode) -> String:
	var text: String
	if bonus_type:
		text = tr('%s is gained') % bonus_type.get_term_tag()
	else:
		text = tr('any <term_lower:bonus> is gained')
	if not any_spot:
		match mode:
			HauntingTrigger.Mode.SPOT: text += tr(' in this <term_lower:spot>')
			HauntingTrigger.Mode.HARMONIZATION: text += tr(' in this <term_lower:settlement>')
			HauntingTrigger.Mode.UNIVERSAL: text += tr(' in the associated <term_lower:spot> (during <term_lower:foray>s) or <term_lower:settlement> (during <term_lower:harmonization>)')
	return text

func get_short_description(_mode: HauntingTrigger.Mode) -> String:
	var text: String
	if bonus_type:
		text = '[img width=1.5em height=1.5em]%s[/img]' % bonus_type.icon.resource_path
	else:
		text = '<term:bonus>'
	if any_spot:
		return tr('%s Gained') % text
	else:
		return tr('%s Gained Here') % text

func setup(spot: Spot, _settlement: Settlement) -> void:
	var run := Utils.get_active_run()
	run.signals.pre_bonus_gained.connect(_on_pre_bonus_gained.bind(spot))

func cleanup(spot: Spot, _settlement: Settlement) -> void:
	var run := Utils.get_active_run()
	run.signals.pre_bonus_gained.disconnect(_on_pre_bonus_gained.bind(spot))

func _on_pre_bonus_gained(gain: BonusGain, this_spot: Spot) -> void:
	if gain.amount <= 0:
		return

	if bonus_type and gain.bonus_type != bonus_type:
		return

	if any_spot:
		var card_type: CardType
		if gain.get_reason() == BonusGain.Reason.ABILITY:
			card_type = (gain.source as Card).card_type
		triggered.emit(gain, null, card_type)
	else:
		if gain.get_reason() == BonusGain.Reason.SPOT_RECIPE:
			if Utils.get_typed_ancestor(gain.source as SpotRecipe, Spot) == this_spot:
				triggered.emit(gain, null, null)
