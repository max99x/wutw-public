class_name SettlerQuestChallenge_CardOnCompanion
extends SettlerQuestChallenge

@export var added_card: CardType

func start_listening(run: Run) -> void:
	run.signals.companion_ability_finished.connect(_on_companion_ability.unbind(1))

func stop_listening(run: Run) -> void:
	run.signals.companion_ability_finished.disconnect(_on_companion_ability.unbind(1))

func _on_companion_ability() -> void:
	var run := Utils.get_active_run()
	run.run_or_queue_action(func() -> void:
		var deck := run.get_current_stage().get_card_deck()
		await deck.add_card_to_hand(added_card, CardDeck.CardDrawReason.SETTLER_QUEST)
	)

func describe() -> String:
	return tr('Add a %s <term_lower:glyph> to <term_lower:hand> whenever a <term_lower:companion> ability is activated.') % added_card.get_term_tag()
