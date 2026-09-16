@tool
class_name Relic_ForesterStaff
extends Relic

@export var spot_type: SpotType
@export var bonus_amount: int = 5

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.stage_started.connect(_on_stage_started)
	_run.signals.spot_recipe_activated.connect(_on_recipe_activated)
	_on_stage_started()

func on_removed() -> void:
	_run.signals.stage_started.disconnect(_on_stage_started)
	_run.signals.spot_recipe_activated.disconnect(_on_recipe_activated)
	super.on_removed()

func _on_stage_started() -> void:
	var stage := _run.get_current_stage()
	if stage and stage.mode == Stage.Mode.REGULAR and spot_type in stage.settlement.state.spot_types:
		_state = State.ACTIVE
	else:
		_state = State.PASSIVE

func _on_recipe_activated(spot_recipe: SpotRecipe) -> void:
	if spot_type.contains_upgrade(spot_recipe.spot_upgrade):
		assert(_state == State.ACTIVE)
		_run.run_or_queue_action(func() -> void:
			triggered.emit()
			for bonus_type in spot_recipe.spot_upgrade.granted_bonuses:
				if spot_recipe.spot_upgrade.granted_bonuses[bonus_type] > 0:
					_run.gain_bonus(BonusGain.new(bonus_type, bonus_amount, self))
			await _brief_wait()
		)

func get_description() -> String:
	return tr(default_description) % bonus_amount
