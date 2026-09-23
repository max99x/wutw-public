@tool
class_name CardAbility_Satisfy
extends CardAbility

@export var all: bool = false
@export var points: int = 1

func get_ability_name(_markedup: bool = false, _short: bool = false) -> String:
	if points > 0:
		if all:
			return tr('Satisfy All %d', 'ABILITY') % points
		else:
			return tr('Satisfy %d', 'ABILITY') % points
	else:
		if all:
			return tr('Dissatisfy All %d', 'ABILITY') % -points
		else:
			return tr('Dissatisfy %d', 'ABILITY') % -points

func get_ability_tooltip(_card: Card) -> String:
	if points > 0:
		if all:
			return tr('Gain %d <term_lower:bonus> points of each <term:stage_goal>. Cannot exceed goal maximum.') % points
		else:
			return tr('Gain %d <term_lower:bonus> points of a random unsatisfied <term:stage_goal>. Cannot exceed goal maximum.') % points
	else:
		if all:
			return tr('Lose %d <term_lower:bonus> points of each <term:stage_goal>.') % -points
		else:
			return tr('Lose %d <term_lower:bonus> points of a random <term:stage_goal>.') % -points

func get_term() -> Term:
	if points > 0:
		if all:
			return load('res://cards/abilities/terms/term_card_ability_satisfy_all.tres')
		else:
			return load('res://cards/abilities/terms/term_card_ability_satisfy.tres')
	else:
		if all:
			return load('res://cards/abilities/terms/term_card_ability_dissatisfy_all.tres')
		else:
			return load('res://cards/abilities/terms/term_card_ability_dissatisfy.tres')

func cast(card: Card) -> void:
	var run := Utils.get_active_run()
	var stage := run.get_current_stage()
	if not stage.get_goal():
		stage.queue_action(func() -> void:
			if points < 0:
				GlobalUI.show_error(tr('No goals available to dissatisfy.'))
			else:
				GlobalUI.show_error(tr('No goals available to satisfy.'))
		)
		return  # Doesn't work in harmonization/survey.

	stage.queue_action(func() -> void:
		# Pick which bonus(es) to affect.
		var bonus_types: Array[BonusType]
		var remaining_reqs := stage.get_remaining_requirements()
		var effective_points := points
		if effective_points > 0:
			effective_points = maxi(0, roundi(effective_points * (1.0 + run.get_var(RunVars.Var.SATISFY_ABILITY_BONUS_PERCENT) / 100.0)))
			if all:
				bonus_types.assign(remaining_reqs.keys())
			else:
				bonus_types.append(stage.get_card_deck().get_random_state().pick(remaining_reqs.keys()))
		else:
			# If we are losing points, affect all goals regardless of satisfaction.
			var all_goals := stage.get_goal().bonus_requirements.keys()
			if all:
				bonus_types.assign(all_goals)
			else:
				bonus_types.append(stage.get_card_deck().get_random_state().pick(all_goals))

		if not bonus_types:
			stage.queue_action(func() -> void:
				GlobalUI.show_error(tr('Nothing left to satisfy.'))
				await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
			)
			return

		for bonus_type in bonus_types:
			var clamped_points := mini(effective_points, remaining_reqs.get(bonus_type, 0) as int)  # Auto-handles negatives.
			if clamped_points:
				run.gain_bonus(BonusGain.new(bonus_type, clamped_points, card))
			else:
				GlobalUI.show_error(tr('Nothing left to satisfy.'))
			await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
	)

func estimate_power(_card_type: CardType) -> int:
	return roundi(points * (4.0 if all else 2.0))

func scales_when_looped() -> bool:
	return points > 0
