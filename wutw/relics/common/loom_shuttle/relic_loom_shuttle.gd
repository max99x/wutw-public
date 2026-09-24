@tool
class_name Relic_LoomShuttle
extends Relic

@export var min_cards: int = 2
@export var bonus_increase_percent: int = 25

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.card_added_to_hand.connect(_on_card_added_to_hand)
	_run.signals.discard_finished.connect(_on_discard_finished)
	_run.signals.redraw_started.connect(_on_redraw_started)
	_update_state()

func on_removed() -> void:
	_run.signals.card_added_to_hand.disconnect(_on_card_added_to_hand)
	_run.signals.discard_finished.disconnect(_on_discard_finished)
	_run.signals.redraw_started.disconnect(_on_redraw_started)
	super.on_removed()

func _on_redraw_started(_is_first: bool) -> void:
	_update_state()  # For good measure.
	if _state == State.ACTIVE:
		_run.run_or_queue_action(func() -> void:
			triggered.emit()
			await _brief_wait()
		)

func _on_card_added_to_hand(_card: Card, _reason: CardDeck.CardDrawReason, _from_discards: bool) -> void:
	_update_state()

func _on_discard_finished(_card: Card, _reason: CardDeck.DiscardReason) -> void:
	_update_state()

func _update_state() -> void:
	var stage := _run.get_current_stage()
	if not stage:
		_state = State.PASSIVE
		return

	var tag := _get_modifier_tag()
	var card_counts: Dictionary[CardType, int]
	for card in stage.get_card_deck().get_hand_cards():
		var new_count: int = card_counts.get(card.card_type, 0) + 1
		if new_count >= min_cards:
			_run.get_vars().add_modifier(RunVars.Var.BONUS_GAIN_PERCENT, bonus_increase_percent, tag)
			_state = State.ACTIVE
			return
		card_counts[card.card_type] = new_count

	# Couldn't find enough.
	_run.get_vars().remove_modifier(tag)
	_state = State.PASSIVE

func get_description() -> String:
	return tr(default_description) % [min_cards, bonus_increase_percent]
