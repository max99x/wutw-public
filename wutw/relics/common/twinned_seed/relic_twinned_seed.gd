@tool
class_name Relic_TwinnedSeed
extends Relic

var _adding_card := false

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.card_added.connect(_on_card_added)

func on_removed() -> void:
	_run.signals.card_added.disconnect(_on_card_added)
	super.on_removed()

func _on_card_added(card_type: CardType) -> void:
	if _adding_card:  # Not re-entrant!
		return

	_run.run_or_queue_action(func() -> void:
		triggered.emit()
		_adding_card = true
		_run.add_card_to_deck(card_type)
		_adding_card = false
	)
