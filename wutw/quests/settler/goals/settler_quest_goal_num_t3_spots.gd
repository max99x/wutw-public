class_name SettlerQuestGoal_NumT3Spots
extends SettlerQuestGoal

@export var num_required: int = 20

func start_listening(run: Run) -> void:
	run.signals.spot_recipe_activated.connect(_on_spot_recipe_activated.unbind(1))

func stop_listening(run: Run) -> void:
	run.signals.spot_recipe_activated.disconnect(_on_spot_recipe_activated.unbind(1))

func _on_spot_recipe_activated() -> void:
	if _count_t3() >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [_count_t3(), num_required]
	result += tr('Activate 3 <term_lower:spot_upgrade>s on %d <term_lower:spot>s.') % num_required
	return result

func _count_t3() -> int:
	var settlement_states: Array[SettlementState] = Utils.get_active_run().get_settlement_states().duplicate()
	if Utils.get_active_run().get_current_settlement():
		settlement_states.append(Utils.get_active_run().get_current_settlement().state)
	var num_t3 := 0
	for settlement_state in settlement_states:
		for spot_upgrades in settlement_state.activated_upgrades:
			if spot_upgrades.size() >= 3:
				num_t3 += 1
				if num_t3 >= num_required:
					break
	return num_t3
