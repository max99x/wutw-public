class_name SettlerQuestGoal_LegendaryCard
extends SettlerQuestGoal

func start_listening(run: Run) -> void:
	run.signals.card_added.connect(_on_card_added)

func stop_listening(run: Run) -> void:
	run.signals.card_added.disconnect(_on_card_added)

func _on_card_added(_card_type: CardType) -> void:
	for card_type in Utils.get_active_run().get_deck_cards():
		if card_type.rarity == CardType.Rarity.LEGENDARY:
			achieved.emit()
			break

func describe() -> String:
	return tr('Add a legendary <term_lower:glyph> to your <term_lower:card_deck>')
