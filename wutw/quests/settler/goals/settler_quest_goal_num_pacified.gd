class_name SettlerQuestGoal_NumPacifiedHauntings
extends SettlerQuestGoal

@export var num_required: int = 10

func start_listening(run: Run) -> void:
	run.signals.haunting_pacified.connect(_on_haunting_pacified.unbind(1))

func stop_listening(run: Run) -> void:
	run.signals.haunting_pacified.disconnect(_on_haunting_pacified.unbind(1))

func _on_haunting_pacified() -> void:
	if _count_pacified() >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [_count_pacified(), num_required]
	result += tr('<term:pacify> at least %d <term_lower:haunting>s.') % num_required
	return result

func _count_pacified() -> int:
	var num_pacified := 0
	var run := Utils.get_active_run()
	for num_pacified_type: int in run.get_run_data().pacified_hauntings.values():
		num_pacified += num_pacified_type
	return num_pacified
