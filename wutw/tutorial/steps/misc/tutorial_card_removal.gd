class_name Tutorial_CardRemoval
extends TutorialBase

func get_tutorial_type() -> Type:
	return Type.RUN

func start_listening() -> void:
	Utils.get_active_run().state_changed.connect(_on_state_changed)

func stop_listening() -> void:
	Utils.get_active_run().state_changed.disconnect(_on_state_changed)

func _on_state_changed() -> void:
	if GlobalSaveGame.get_total_playtime() < 1 * 60 * 60 and not Utils.is_dev():
		return  # Don't bother the player until we know they're invested.

	var run := Utils.get_active_run()
	if run.get_state() == RunData.State.STAGE_CARD_REWARD:
		if run.get_deck_cards().size() >= 20:
			ready_to_trigger.emit()

func trigger() -> void:
	var run := Utils.get_active_run()
	await run.get_tree().create_timer(Utils.anim_duration(2.0)).timeout  # Wait for animation.

	var text := tr('''
Your <term_lower:card_deck> has %d <term_lower:glyph>s.

Having too many <term_lower:glyph>s can make it harder to draw the really good ones.

Consider removing <term_lower:glyph>s that have only one <term_lower:aspect>.
''').strip_edges() % run.get_deck_cards().size()
	var card_reward_choice := run.get_current_scene() as CardRewardChoice
	assert(card_reward_choice)  # HACK: Error out and avoid marking as skipped if we managed to close the UI.
	var scroll_panel := card_reward_choice.get_node('%ScrollPanel') as ScrollPanel
	var remove_button := card_reward_choice.get_node('%RemoveButton') as Control
	_outline_controls([remove_button], true, [scroll_panel])
	_show_tooltip(remove_button, text, [Tooltip.RelativeDirection.RIGHT])

func get_skip_id() -> String:
	return 'card_removal'
