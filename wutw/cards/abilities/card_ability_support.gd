@tool
class_name CardAbility_Support
extends CardAbility

@export var bonus_type: BonusType
@export var reversed: bool

func get_ability_name(markedup: bool = false, short: bool = false) -> String:
	var name: String
	if Utils.is_realistic_era():
		name = tr('Neglect', 'ABILITY') if reversed else tr('Support', 'ABILITY')
	else:
		name = tr('Curse', 'ABILITY') if reversed else tr('Bless', 'ABILITY')
	if not bonus_type:
		return tr('%s Goal') % name
	else:
		if markedup:
			if short:
				return '%s [img width=1.25em height=1.25em]%s[/img]' % [name, bonus_type.icon.resource_path]
			else:
				return '%s %s' % [name, bonus_type.get_term_tag()]
		else:
			return '%s %s' % [name, tr(bonus_type.name)]

func get_ability_tooltip(_card: Card) -> String:
	if reversed:
		return (tr('Halve all gains of %s for the rest of the <term:stage>. Does not stack.')
		 		% (bonus_type.get_term_tag() if bonus_type else tr('a random <term_lower:stage_goal>')))
	else:
		return (tr('Double all gains of %s for the rest of the <term:stage>. Does not stack.')
		 		% (bonus_type.get_term_tag() if bonus_type else tr('a random <term_lower:stage_goal>')))

func get_term() -> Term:
	if reversed:
		return load('res://cards/abilities/terms/term_card_ability_neglect.tres')
	else:
		return load('res://cards/abilities/terms/term_card_ability_support.tres')

func cast(_card: Card) -> void:
	var run := Utils.get_active_run()

	if not reversed and run.get_var(RunVars.Var.SUPPORT_ENABLED) == 0:
		GlobalUI.show_error(tr('Support invocations are disabled.'))
		await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
		return

	var stage := run.get_current_stage()
	var effective_bonus_type := bonus_type
	if not effective_bonus_type:
		var goal := stage.get_goal()
		if goal:
			effective_bonus_type = run.get_card_deck_random().pick(goal.bonus_requirements.keys())
		else:
			GlobalUI.show_error(tr('No goals available.'))
			stage.queue_action(func() -> void:
				await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
			)
			return
	if reversed:
		stage.queue_action(func() -> void:
			if run.get_var(effective_bonus_type.focus_var) < 0:
				if Utils.is_realistic_era():
					GlobalUI.show_error(tr('%s is already neglected.') % effective_bonus_type.get_term_tag())
				else:
					GlobalUI.show_error(tr('%s is already cursed.') % effective_bonus_type.get_term_tag())
			else:
				stage.add_modifier(effective_bonus_type.focus_var, -1)
				GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_GLITTER)
			await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
		)
	else:
		stage.queue_action(func() -> void:
			if run.get_var(effective_bonus_type.focus_var) > 0:
				if Utils.is_realistic_era():
					GlobalUI.show_error(tr('%s is already supported.') % effective_bonus_type.get_term_tag())
				else:
					GlobalUI.show_error(tr('%s is already blessed.') % effective_bonus_type.get_term_tag())
			else:
				stage.add_modifier(effective_bonus_type.focus_var, 1)
				GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_GLITTER)
			await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
		)

	if reversed:
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_NONGOALYIELD_LOST)
	else:
		GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_GLITTER)

func estimate_power(_card_type: CardType) -> int:
	if reversed:
		return -8
	else:
		return 18

func scales_when_looped() -> bool:
	return false

func get_search_text() -> String:
	if reversed:
		return ' '.join([tr('Curse', 'ABILITY'), tr('Neglect', 'ABILITY'), tr(bonus_type.name) if bonus_type else tr('goal')])
	else:
		return ' '.join([tr('Bless', 'ABILITY'), tr('Support', 'ABILITY'), tr(bonus_type.name) if bonus_type else tr('goal')])
