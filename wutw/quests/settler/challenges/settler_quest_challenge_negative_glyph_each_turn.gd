class_name SettlerQuestChallenge_NegativeGlyphEachTurn
extends SettlerQuestChallenge

func start_listening(run: Run) -> void:
	run.signals.redraw_finished.connect(_on_redraw_finished.unbind(1))

func stop_listening(run: Run) -> void:
	run.signals.redraw_finished.disconnect(_on_redraw_finished.unbind(1))

func _on_redraw_finished() -> void:
	var run := Utils.get_active_run()
	run.run_or_queue_action(func() -> void:
		var card_type: CardType
		const WEIGHTS_BY_ASPECT_COUNT: Array[float] = [1, 0.3, 0.15, 0.05, 0.05, 0.05, 0.05, 0.05]
		var options: Dictionary[CardType, float]
		for option in CardType.get_all_card_types_by_tier(CardType.Rarity.NEGATIVE):
			options[option] = WEIGHTS_BY_ASPECT_COUNT[option.aspects.size()]
		card_type = run.get_card_reward_random().pick_weighted_dict(options)[0]
		if Utils.ensure(card_type != null):
			var deck := run.get_current_stage().get_card_deck()
			await deck.add_card_to_hand(card_type, CardDeck.CardDrawReason.SETTLER_QUEST)
	)

func describe() -> String:
	return tr('Add a random <term_lower:negative_glyph> at the start of each <term_lower:turn>.')
