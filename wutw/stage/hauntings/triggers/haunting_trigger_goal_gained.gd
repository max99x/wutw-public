@tool
class_name HauntingTrigger_GoalGained
extends HauntingTrigger

@export var nongoal: bool = false
@export var any_spot: bool = true

func get_description(_mode: HauntingTrigger.Mode) -> String:
	if any_spot:
		if nongoal:
			return tr('a <related_term:stage_goal>non-goal <term_lower:bonus> is gained')
		else:
			return tr('a <related_term:stage_goal>goal <term_lower:bonus> is gained')
	else:
		# Goals don't exist in harmonization, so we don't need to handle that.
		if nongoal:
			return tr('a <related_term:stage_goal>non-goal <term_lower:bonus> is gained in this <term_lower:spot>')
		else:
			return tr('a <related_term:stage_goal>goal <term_lower:bonus> is gained in this <term_lower:spot>')

func get_short_description(_mode: HauntingTrigger.Mode) -> String:
	if any_spot:
		if nongoal:
			return tr('Non-Goal Gained')
		else:
			return tr('Goal Gained')
	else:
		if nongoal:
			return tr('Non-Goal Gained Here')
		else:
			return tr('Goal Gained Here')

func setup(spot: Spot, _settlement: Settlement) -> void:
	var run := Utils.get_active_run()
	run.signals.pre_bonus_gained.connect(_on_pre_bonus_gained.bind(spot))

func cleanup(spot: Spot, _settlement: Settlement) -> void:
	var run := Utils.get_active_run()
	run.signals.pre_bonus_gained.disconnect(_on_pre_bonus_gained.bind(spot))

func _on_pre_bonus_gained(gain: BonusGain, this_spot: Spot) -> void:
	if gain.amount <= 0:
		return

	var run := Utils.get_active_run()
	var stage := run.get_current_stage()
	var goal := stage.get_goal()
	if not goal:  # Convergence.
		return
	var is_goal := gain.bonus_type in goal.bonus_requirements
	if is_goal == nongoal:
		return

	if not nongoal and stage.get_remaining_requirements().get(gain.bonus_type, 0) <= 0:
		return  # Already satisfied.

	if any_spot:
		var card_type: CardType
		if gain.get_reason() == BonusGain.Reason.ABILITY:
			card_type = (gain.source as Card).card_type
		triggered.emit(gain, null, card_type)
	else:
		if gain.get_reason() == BonusGain.Reason.SPOT_RECIPE:
			if Utils.get_typed_ancestor(gain.source as SpotRecipe, Spot) == this_spot:
				triggered.emit(gain, null, null)
