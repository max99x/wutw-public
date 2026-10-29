@tool
class_name CardAbility_Continue
extends CardAbility

@export var count: int = 1

func get_ability_name(_markedup: bool = false, _short: bool = false) -> String:
	return tr('Continue', 'ABILITY') + ' ' + str(count)

func get_ability_tooltip(_card: Card) -> String:
	var result: String
	if count == 1:
		result = tr('<term:fill> a random <term_lower:aspect_slot>')
	else:
		result = tr('<term:fill> %d random <term_lower:aspect_slot>s') % count
	result += tr(' in <term:spot_upgrade>s')
	if Skill.get_skill_var(Skill.Var.SURVEYS):
		result += tr(' or <term:task>s')
	return result + tr(' with any filled <term_lower:aspect_slot>s.')

func get_term() -> Term:
	return load('res://cards/abilities/terms/term_card_ability_continue.tres')

func cast(_card: Card) -> void:
	var run := Utils.get_active_run()
	var stage := run.get_current_stage()

	var slots_filled := [0]  # Array, so we can capture it.
	var error_shown := [false]  # Array, so we can capture it.
	for _i in range(count + run.get_var(RunVars.Var.FILL_ABILITY_BONUS)):
		stage.queue_action(func() -> void:
			var recipe_pool := stage.get_all_recipes()  # Need to do this in each iteration as hauntings may disappear.
			var aspect_slots_availability := stage.get_aspect_slots_availability()
			var slot_pool: Array[AspectSlot] = []
			for recipe in recipe_pool:
				if recipe.is_available():
					var any_filled := false
					for slot in recipe.get_aspect_slots():
						if slot.is_filled:
							any_filled = true
							break
					if any_filled:
						for slot in recipe.get_aspect_slots():
							if aspect_slots_availability.get(slot):
								slot_pool.append(slot)
			if slot_pool:
				var slot := stage.get_card_deck().get_random_state().pick(slot_pool) as AspectSlot
				await stage.ensure_slot_visible(slot)
				await slot.animate_fill()
				slots_filled[0] += 1
			else:
				if not error_shown[0]:
					if slots_filled[0]:
						GlobalUI.show_error('Ran out of <term_lower:aspect_slot>s to fill after %d.' % slots_filled[0])
					else:
						GlobalUI.show_error('No valid <term_lower:aspect_slot>s to fill.')
					error_shown[0] = true
					await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
		)

func estimate_power(_card_type: CardType) -> int:
	return 13 + 9 * (count - 1)
