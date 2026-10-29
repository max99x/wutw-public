@tool
class_name Relic_StrangeStatue
extends Relic

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.inspiration_excess_gained.connect(_on_inspiration_excess_gained)

func on_removed() -> void:
	_run.signals.inspiration_excess_gained.disconnect(_on_inspiration_excess_gained)
	super.on_removed()

func _on_inspiration_excess_gained(amount: int, _reason: Run.InspirationChangeReason) -> void:
	var stage := _run.get_current_stage()
	if not stage or stage.mode != Stage.Mode.REGULAR:
		return
	_run.run_or_queue_action(func() -> void:
		var reqs := stage.get_goal().get_remaining_requirements(stage.get_stage_bonus_amounts())
		if not reqs.is_empty():
			var bonus_type := stage.get_card_deck().get_random_state().pick(reqs.keys()) as BonusType
			triggered.emit()
			_run.gain_bonus(BonusGain.new(bonus_type, amount, self))
			await _brief_wait()
	)
