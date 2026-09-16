class_name SettlerQuestGoal_NumRelics
extends SettlerQuestGoal

@export var num_required: int = 5

func start_listening(run: Run) -> void:
	run.signals.relic_added.connect(_on_relic_added)

func stop_listening(run: Run) -> void:
	run.signals.relic_added.disconnect(_on_relic_added)

func _on_relic_added(_relic: Relic) -> void:
	if Utils.get_active_run().get_current_relics().size() >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [Utils.get_active_run().get_current_relics().size(), num_required]
	result += tr('Acquire at least %d <term_lower:relic>s.') % num_required
	return result
