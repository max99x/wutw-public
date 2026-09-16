class_name SettlerQuestGoal_NumSettlements
extends SettlerQuestGoal

@export var num_settlements: int = 8

func start_listening(run: Run) -> void:
	run.signals.foray_finished.connect(_on_stage_finished)

func stop_listening(run: Run) -> void:
	run.signals.foray_finished.disconnect(_on_stage_finished)

func _on_stage_finished(_settlement_state: SettlementState) -> void:
	# 1 for the settlement just finished, not yet included in the run's settlement states list.
	if 1 + Utils.get_active_run().get_settlement_states().size() >= num_settlements:
		achieved.emit()

func describe() -> String:
	assert(num_settlements > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [Utils.get_active_run().get_settlement_states().size(), num_settlements]
	result += tr('Establish at least %d <term_lower:settlement>s.') % num_settlements
	return result
