class_name SettlerQuestGoal_NumPerfectSettlements
extends SettlerQuestGoal

@export var num_required: int = 8

func start_listening(run: Run) -> void:
	run.signals.foray_finished.connect(_on_stage_finished)

func stop_listening(run: Run) -> void:
	run.signals.foray_finished.disconnect(_on_stage_finished)

func _on_stage_finished(new_settlement_state: SettlementState) -> void:
	if _count_perfect(new_settlement_state) >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [_count_perfect(null), num_required]
	result += tr('Finish at least %d <term_lower:foray>s with all <term_lower:stage_goal>s fully satisfied.') % num_required
	return result

func _count_perfect(new_settlement_state: SettlementState) -> int:
	var settlement_states: Array[SettlementState] = Utils.get_active_run().get_settlement_states().duplicate()
	if new_settlement_state:
		settlement_states.append(new_settlement_state)
	var num_perfect := 0
	for settlement_state in settlement_states:
		if settlement_state.goal.get_remaining_requirements(settlement_state.bonus_amounts).is_empty():
			num_perfect += 1
			if num_perfect >= num_required:
				break
	return num_perfect
