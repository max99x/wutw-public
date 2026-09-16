class_name SettlerQuestGoal_NumConnectedSettlements
extends SettlerQuestGoal

@export var num_required: int = 8

func start_listening(run: Run) -> void:
	run.signals.settlement_connected.connect(_on_settlement_connected)

func stop_listening(run: Run) -> void:
	run.signals.settlement_connected.disconnect(_on_settlement_connected)

func _on_settlement_connected(_settlement: Settlement) -> void:
	if _count_connected() >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [_count_connected(), num_required]
	result += tr('Connect at least %d <term_lower:settlement>s.') % num_required
	return result

func _count_connected() -> int:
	var connected := 0
	for settlement in Utils.get_active_run().get_settlements():
		if settlement.is_settlement_connected():
			connected += 1
			if connected >= num_required:
				break
	return connected
