@tool
class_name Relic_Yuzu
extends Relic

@export var required_card: CardType
@export var granted_card: CardType

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.card_slotted.connect(_on_card_played.unbind(1))
	_run.signals.card_cast_finished.connect(_on_card_played)

func on_removed() -> void:
	_run.signals.card_slotted.disconnect(_on_card_played.unbind(1))
	_run.signals.card_cast_finished.disconnect(_on_card_played)
	super.on_removed()

func _on_card_played(card: Card) -> void:
	if card.card_type == required_card:
		_run.run_or_queue_action(func() -> void:
			triggered.emit()
			await _run.get_current_stage().get_card_deck().add_card_to_hand(
				granted_card, CardDeck.CardDrawReason.RELIC)
		)

func get_description() -> String:
	return tr(default_description) % [required_card.get_term_tag(), granted_card.get_term_tag()]
