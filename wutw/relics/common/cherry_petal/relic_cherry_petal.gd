@tool
class_name Relic_CherryPetal
extends Relic

@export var amount_reduced: int = 2

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.redraw_started.connect(_update_state.unbind(1))
	_run.signals.foray_finished.connect(_update_state.unbind(1))
	_update_state()

func on_removed() -> void:
	_update_state()
	_run.signals.redraw_started.disconnect(_update_state.unbind(1))
	_run.signals.foray_finished.disconnect(_update_state.unbind(1))
	super.on_removed()

func _update_state() -> void:
	var stage := _run.get_current_stage()
	if not stage:
		_state = State.PASSIVE
		return

	var tag := _get_modifier_tag()
	if _run.get_var(RunVars.Var.REDRAWS) <= 0:
		_run.get_vars().add_modifier(RunVars.Var.EXTRA_EVENT_ASPECT_REQS, -amount_reduced, tag)
		_state = State.ACTIVE
	else:
		_run.get_vars().remove_modifier(tag)
		_state = State.PASSIVE

func get_description() -> String:
	var amount_str := tr_n(
		'%d fewer <term_lower:aspect>',
		'%d fewer <term_lower:aspect>s',
		amount_reduced) % amount_reduced
	return tr(default_description) % amount_str
