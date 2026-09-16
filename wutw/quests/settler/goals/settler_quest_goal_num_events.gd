class_name SettlerQuestGoal_NumEvents
extends SettlerQuestGoal

@export var num_required: int = 5

func start_listening(run: Run) -> void:
	run.signals.event_finished.connect(_on_event_finished)

func stop_listening(run: Run) -> void:
	run.signals.event_finished.disconnect(_on_event_finished)

func _on_event_finished(_event: Event) -> void:
	if _count_triggered_events() >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [_count_triggered_events(), num_required]
	result += tr('Finish at least %d <term_lower:event>s.') % num_required
	return result

func _count_triggered_events() -> int:
	var num_finished := 0
	for key in Utils.get_active_run().get_events_state().to_flat():
		if key.ends_with(':TRIGGERED_STAGE_INDEX'):
			num_finished += 1
			if num_finished >= num_required:
				break
	return num_finished
