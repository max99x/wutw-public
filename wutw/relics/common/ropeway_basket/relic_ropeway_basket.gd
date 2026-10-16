@tool
class_name Relic_RopewayBasket
extends Relic

@export var mountain_spot_type: SpotType
@export var hand_size_increase: int = 1

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.redraw_started.connect(_on_redraw_started)
	_run.signals.stage_finished.connect(_on_stage_finished)

func on_removed() -> void:
	_run.signals.redraw_started.disconnect(_on_redraw_started)
	_run.signals.stage_finished.disconnect(_on_stage_finished)
	super.on_removed()

func _on_redraw_started(is_first: bool) -> void:
	if not is_first:
		return

	var has_mountain := false

	var stage := _run.get_current_stage()
	if stage.mode == Stage.Mode.REGULAR:
		var spots := _run.get_current_stage().get_spots()
		for spot in spots:
			if spot.spot_type == mountain_spot_type:
				has_mountain = true
				break
	elif stage.mode == Stage.Mode.SURVEY:
		var radius := _run.scaling.survey_scan_radius
		has_mountain = MapBiomes.Biome.MOUNTAIN in _run.get_map().get_biomes_in_radius(stage.get_survey().map_location, radius)

	if has_mountain:
		_state = State.ACTIVE
		triggered.emit()
		_run.get_vars().add_modifier(RunVars.Var.HAND_SIZE, hand_size_increase, _get_modifier_tag())

func _on_stage_finished() -> void:
	_run.get_vars().remove_modifier(_get_modifier_tag())
	_state = State.PASSIVE

func get_description() -> String:
	return tr(default_description) % hand_size_increase
