class_name SettlerQuestGoal_NumCards
extends SettlerQuestGoal

@export var aspect_required: AspectType
@export var num_required: int = 5

func start_listening(run: Run) -> void:
	run.signals.card_added.connect(_on_card_added)

func stop_listening(run: Run) -> void:
	run.signals.card_added.disconnect(_on_card_added)

func _on_card_added(_card_type: CardType) -> void:
	if _get_num_owned() >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var text := ''
	if Utils.get_active_run():
		text += tr('[%d/%d] ') % [_get_num_owned(), num_required]
	text += tr('Have at least %d <term_lower:glyph>s') % num_required
	if aspect_required:
		text +=tr( ' with %s <term_lower:aspect>') % aspect_required.get_term_tag()
	return text + tr('.')

func _get_num_owned() -> int:
	if aspect_required:
		var num_owned := 0
		for card_type in Utils.get_active_run().get_deck_cards():
			if aspect_required in card_type.aspects:
				num_owned += 1
		return num_owned
	else:
		return Utils.get_active_run().get_deck_cards().size()
