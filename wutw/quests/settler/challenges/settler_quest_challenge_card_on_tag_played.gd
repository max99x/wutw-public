class_name SettlerQuestChallenge_CardOnTagPlayed
extends SettlerQuestChallenge

@export var trigger_tag: CardType.Tag
@export var added_card: CardType

func start_listening(run: Run) -> void:
	run.signals.card_slotted.connect(_on_card_played.unbind(1))
	run.signals.card_cast_finished.connect(_on_card_played)

func stop_listening(run: Run) -> void:
	run.signals.card_slotted.disconnect(_on_card_played.unbind(1))
	run.signals.card_cast_finished.disconnect(_on_card_played)

func _on_card_played(card: Card) -> void:
	if trigger_tag not in card.card_type.tags:
		return
	var run := Utils.get_active_run()
	run.run_or_queue_action(func() -> void:
		var deck := run.get_current_stage().get_card_deck()
		await deck.add_card_to_hand(added_card, CardDeck.CardDrawReason.SETTLER_QUEST)
	)

func describe() -> String:
	return tr('Add a %s <term_lower:glyph> to <term_lower:hand> whenever any %s <term_lower:glyph> is <term_lower:play_card>ed.') % [
		added_card.get_term_tag(), CardType._get_tag_label(trigger_tag)]
