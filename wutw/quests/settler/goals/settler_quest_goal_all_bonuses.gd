class_name SettlerQuestGoal_AllBonuses
extends SettlerQuestGoal

@export var bonus_amount: int = 100

func start_listening(run: Run) -> void:
	run.signals.bonus_gained.connect(_on_bonus_gained.unbind(3))

func stop_listening(run: Run) -> void:
	run.signals.bonus_gained.disconnect(_on_bonus_gained.unbind(3))

func _on_bonus_gained() -> void:
	var amounts := Utils.get_active_run().get_bonus_amounts()
	for bonus_type in BonusType.get_all_types():
		if amounts.get_amount(bonus_type) < bonus_amount:
			return
	achieved.emit()

func describe() -> String:
	assert(bonus_amount > 0)
	var result := ''
	if Utils.get_active_run():
		var min_amount := bonus_amount + 1
		var amounts := Utils.get_active_run().get_bonus_amounts()
		for bonus_type in BonusType.get_all_types():
			min_amount = min(min_amount, amounts.get_amount(bonus_type))
		result += tr('[%d/%d] ') % [min(bonus_amount, min_amount), bonus_amount]
	result += tr('Reach %d of every <term_lower:bonus>.') % bonus_amount
	return result
