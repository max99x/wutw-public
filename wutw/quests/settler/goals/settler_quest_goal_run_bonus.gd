class_name SettlerQuestGoal_RunBonus
extends SettlerQuestGoal

@export var bonus_type: BonusType
@export var bonus_amount: int = 100

func start_listening(run: Run) -> void:
	run.signals.bonus_gained.connect(_on_bonus_gained)

func stop_listening(run: Run) -> void:
	run.signals.bonus_gained.disconnect(_on_bonus_gained)

func _on_bonus_gained(gained_bonus_type: BonusType, _amount: int, _reason: BonusGain.Reason) -> void:
	if gained_bonus_type != bonus_type:
		return
	if Utils.get_active_run().get_bonus_amounts().get_amount(bonus_type) >= bonus_amount:
		achieved.emit()

func describe() -> String:
	assert(bonus_type)
	assert(bonus_amount > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [Utils.get_active_run().get_bonus_amounts().get_amount(bonus_type), bonus_amount]
	result += tr('Reach %d total %s <term_lower:bonus>.') % [bonus_amount, bonus_type.get_term_tag()]
	return result
