@tool
class_name Haunting_Harmonization
extends HauntingBase

static var ASPECT_SLOT_SCENE := AsyncLoadedResource.new('res://aspects/slot/aspect_slot.tscn')

const TRIGGER_ANIM_DURATION := 1.0

@export var attached_to_settlement: Settlement

var _fadeout_tween: Tween
var _trigger_tween: Tween

func _ready() -> void:
	super._ready()

	if not Utils.is_in_editor():
		(%NewIcon as Control).visible = not GlobalSaveGame.has_seen_haunting(haunting_type)

	var run := Utils.get_active_run()
	if run:
		run.signals.haunting_pacified.connect(_update_pacify_button.unbind(1))

func get_spot() -> Spot:
	return null

func _get_mode() -> HauntingTrigger.Mode:
	return HauntingTrigger.Mode.HARMONIZATION

func get_settlement() -> Settlement:
	return attached_to_settlement

func _recreate() -> void:
	if not haunting_type:
		return

	if Utils.is_realistic_era():
		(%BG as TextureRect).texture = haunting_type.image_small_realistic
		(%CreditsIcon as CreditsIcon).art_piece = haunting_type.image_realistic_credit
	else:
		(%BG as TextureRect).texture = haunting_type.image_small
		(%CreditsIcon as CreditsIcon).art_piece = haunting_type.image_credit
	(%EffectLabel as MarkedUpLabel).set_markedup_text('%s\n[b]↓[/b]\n%s' % [
		_haunting_trigger.get_short_description(HauntingTrigger.Mode.HARMONIZATION),
		_haunting_effect.get_short_description(HauntingTrigger.Mode.HARMONIZATION)])

	Utils.clear_node(%AspectsList)
	var run := Utils.get_active_run()
	var aspect_types := haunting_type.get_toal_aspect_slots(run, HauntingTrigger.Mode.HARMONIZATION)
	for aspect_type in aspect_types:
		var aspect_slot := ASPECT_SLOT_SCENE.instantiate_loaded_scene() as AspectSlot
		aspect_slot.aspect_type = aspect_type
		aspect_slot.filled.connect(_on_aspect_filled)
		%AspectsList.add_child(aspect_slot)

	_update_pacify_button()

func _update_pacify_button() -> void:
	var run := Utils.get_active_run()
	if run:  # Could be in editor.
		var verb := tr('Mitigate') if Utils.is_realistic_era() else tr('Pacify')
		var pacifies_left := run.get_var(RunVars.Var.HAUNTING_PACIFIES)
		if pacifies_left == 0:
			(%PacifyButton as Button).visible = false
		elif pacifies_left == 1:
			(%PacifyButton as Button).text = verb
			(%PacifyButton as Button).visible = true
		else:
			(%PacifyButton as Button).text = '%s (%d)' % [verb, pacifies_left]
			(%PacifyButton as Button).visible = true

func _play_trigger_animation() -> void:
	if not _is_setup:  # Pacified by the time it's called.
		return
	var stage := Utils.get_active_run().get_current_stage()
	if not GameSettings.Interface.show_harmonization_haunting_preview.value():
		await stage.ensure_slot_visible(get_aspect_slots()[0])
	if _trigger_tween:
		_trigger_tween.kill()
	_trigger_tween = create_tween()
	GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_SELECT_TAIKO_LOW)
	_trigger_tween.tween_property(self, 'offset_transform_scale', Vector2(1.1, 1.1), TRIGGER_ANIM_DURATION / 2)
	_trigger_tween.tween_property(self, 'offset_transform_scale', Vector2(1.0, 1.0), TRIGGER_ANIM_DURATION / 2)
	_trigger_tween.set_speed_scale(Utils.anim_speed())
	_trigger_tween.play()
	await _trigger_tween.finished

func set_faded_out(is_faded_out: bool) -> void:
	if _fadeout_tween:
		_fadeout_tween.kill()
	_fadeout_tween = create_tween()
	_fadeout_tween.tween_property(%AspectsList, 'modulate:a', 0.35 if is_faded_out else 1.0, FADEOUT_ANIM_DURATION)
	_fadeout_tween.play()

func cleanup() -> void:
	return _cleanup()

func _close(duration: float = 1.0) -> void:
	Utils.set_input_enabled(self, false)
	var tween := create_tween()
	GlobalAudioSystem.play(AK.EVENTS.SFX_TRANSITION_MISC)  # Close enough.
	tween.tween_property(self, 'offset_transform_scale', Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, 'modulate:a', 0.0, 1.0)
	tween.set_speed_scale(Utils.anim_speed() / duration)
	tween.play()
	await tween.finished
	queue_free()

func get_aspect_slots() -> Array[AspectSlot]:
	var aspect_slots: Array[AspectSlot]
	for aspect_slot in %AspectsList.get_children():
		aspect_slots.append(aspect_slot as AspectSlot)
	return aspect_slots

func _on_pacify_button_pressed() -> void:
	_pacify_manually()

func _make_tooltip_text() -> String:
	var result := super._make_tooltip_text()
	result = '<header_font_size>[b]<term:haunting>: %s[/b][/font_size]\n\n' % haunting_type.get_effective_name() + result
	return result
