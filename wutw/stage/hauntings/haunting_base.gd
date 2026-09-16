@abstract
class_name HauntingBase
extends Recipe

signal triggered
signal pacified

@abstract func get_spot() -> Spot
@abstract func get_settlement() -> Settlement
@abstract func _get_mode() -> HauntingTrigger.Mode
@abstract func _recreate() -> void
@abstract func _play_trigger_animation() -> void
@abstract func _close(duration: float = 1.0) -> void

@export var haunting_type: HauntingType:
	set(value):
		if haunting_type == value:
			return
		haunting_type = value
		# IMPORTANT: Must copy or signals are duped.
		_haunting_trigger = haunting_type.trigger.duplicate()
		_haunting_effect = haunting_type.effect.duplicate()
		if is_node_ready():
			_recreate()

var _haunting_trigger: HauntingTrigger
var _haunting_effect: HauntingEffect
var _is_setup := false
var _blocks_left := 0

func _ready() -> void:
	_recreate()
	super._ready()  # After slots are created.

	var run := Utils.get_active_run()
	if run:
		_blocks_left = run.get_var(RunVars.Var.HAUNTING_BLOCKS_PER_STAGE)

	GlobalTooltipSystem.attach(self, _make_tooltip_text,
			[Tooltip.RelativeDirection.RIGHT, Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.BELOW],
			[Tooltip.Alignment.BEGIN])

func _exit_tree() -> void:
	if _is_setup and Utils.get_active_run():  # In case of Retry Foray.
		_cleanup()

func _gui_input(input_event: InputEvent) -> void:
	var mouse_event := input_event as InputEventMouseButton
	if not mouse_event:
		return
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and Utils.is_museum_unlocked():
		MuseumBrowser.open_museum_entry(haunting_type, UI.Layer.GAME_MENU)

func setup() -> void:
	Utils.ensure(not _is_setup)
	_haunting_trigger.setup(get_spot(), get_settlement())
	_haunting_effect.setup(get_spot(), get_settlement())
	_haunting_trigger.triggered.connect(_on_triggered)
	_is_setup = true
	GlobalSaveGame.mark_haunting_seen(haunting_type)
	var run := Utils.get_active_run()
	run.get_run_data().recent_hauntings[haunting_type] = run.get_current_stage_index()
	run.signals.haunting_spawned.emit(self)

func _cleanup() -> void:
	Utils.ensure(_is_setup)
	_haunting_trigger.triggered.disconnect(_on_triggered)
	_haunting_trigger.cleanup(get_spot(), get_settlement())
	_haunting_effect.cleanup(get_spot(), get_settlement())
	_is_setup = false

func _on_triggered(related_gain: BonusGain, related_slot: AspectSlot, related_card: CardType) -> void:
	var run := Utils.get_active_run()
	var stage := run.get_current_stage()
	if not stage.is_processing_card() and not stage.get_card_deck().is_redrawing():
		# Don't trigger off event rewards.
		return

	if _blocks_left > 0:
		_blocks_left -= 1
		run.signals.haunting_blocked.emit(self)
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_ENVIRONMENTAL_CHALLENGE)
		# TODO: Better player feedback.
		return

	stage.queue_action(func() -> void:
		if not _is_setup:  # Pacified by the time it's called.
			return
		triggered.emit()
		@warning_ignore('redundant_await')
		await _play_trigger_animation()
	)
	# This usually queues actions, but may react immediately.
	_haunting_effect.triggered(related_gain, related_slot, related_card)

func is_available() -> bool:
	return _is_setup

func cleanup_and_close(duration: float = 1.0) -> void:
	_cleanup()
	_close(duration)

func _on_aspect_filled() -> void:
	var all_filled := true
	for slot in get_aspect_slots():
		if not (slot as AspectSlot).is_filled:
			all_filled = false
			break
	if all_filled:
		_pacify()

func _pacify() -> void:
	_cleanup()
	GlobalSaveGame.mark_haunting_pacified(haunting_type)
	pacified.emit()
	Utils.get_active_run().signals.haunting_pacified.emit(self)
	_close()

func _make_tooltip_text() -> String:
	var text := '[b]<term:haunting>: %s[/b]\n\n' % haunting_type.get_mechanics_description(_get_mode())

	if Utils.is_realistic_era():
		text += tr('This <term_lower:haunting> can be mitigated by <term_lower:fill>ing the associated <term_lower:aspect_slot>s.')
	else:
		text += tr('This <term_lower:haunting> can be pacified by <term_lower:fill>ing the associated <term_lower:aspect_slot>s.')

	var scaling := Utils.get_active_run().scaling
	var max_slots := scaling.haunting_max_slots_spot if _get_mode() == HauntingTrigger.Mode.SPOT else scaling.haunting_max_slots_harmonization
	text += tr(' It has an extra slot (up to %d) for every %d %s the shard produces.') % [
		max_slots, scaling.haunting_bonus_per_slot, haunting_type.scaling_bonus_type.get_term_tag()]

	text += '\n\n'
	if Utils.is_realistic_era():
		text += tr('“%s”') % haunting_type.description_realistic
	else:
		text += tr('“%s”') % haunting_type.description

	if Utils.is_museum_unlocked():
		text += '\n\n'
		text += tr('[i]%s to open museum entry.[/i]') % InputPrompts.get_input_markup(
				InputPrompts.InputType.RIGHT_CLICK)

	return text

func _pacify_manually() -> void:
	var run := Utils.get_active_run()
	assert(run.get_var(RunVars.Var.HAUNTING_PACIFIES) > 0)
	run.get_vars().modify_base_value(RunVars.Var.HAUNTING_PACIFIES, -1)
	_pacify()
