@tool
class_name HauntingHarmonizationPreview
extends UkiyoePanelContainer

var haunting: Haunting_Harmonization

var _trigger_tween: Tween

func _ready() -> void:
	super._ready()

	(%EffectLabel as MarkedUpLabel).set_markedup_text('%s\n[b]↓[/b]\n%s' % [
		haunting.haunting_type.trigger.get_short_description(HauntingTrigger.Mode.HARMONIZATION),
		haunting.haunting_type.effect.get_short_description(HauntingTrigger.Mode.HARMONIZATION)])
	haunting.triggered.connect(_on_triggered)
	haunting.pacified.connect(_on_pacified)

	GlobalTooltipSystem.attach(self, _make_tooltip_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

func _gui_input(event: InputEvent) -> void:
	pass
	var mouse_event := event as InputEventMouseButton
	if not mouse_event:
		return
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		var stage := Utils.get_active_run().get_current_stage()
		await stage.ensure_slot_visible(haunting.get_aspect_slots()[0])
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and Utils.is_museum_unlocked():
		MuseumBrowser.open_museum_entry(haunting.haunting_type, UI.Layer.GAME_MENU)

func _on_triggered() -> void:
	if _trigger_tween:
		_trigger_tween.kill()
	_trigger_tween = create_tween()
	GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_SELECT_TAIKO_LOW)
	_trigger_tween.tween_property(self, 'offset_transform_scale', Vector2(1.1, 1.1), Haunting_Harmonization.TRIGGER_ANIM_DURATION / 2)
	_trigger_tween.tween_property(self, 'offset_transform_scale', Vector2(1.0, 1.0), Haunting_Harmonization.TRIGGER_ANIM_DURATION / 2)
	_trigger_tween.set_speed_scale(Utils.anim_speed())
	_trigger_tween.play()
	await _trigger_tween.finished

func _on_pacified() -> void:
	Utils.set_input_enabled(self, false)
	var tween := create_tween()
	tween.tween_property(self, 'custom_maximum_size:x', 0.0, 0.5)
	tween.parallel().tween_property(self, 'modulate:a', 0.0, 0.5)
	tween.set_speed_scale(Utils.anim_speed())
	tween.play()
	await tween.finished
	queue_free()

func _make_tooltip_text() -> String:
	var result := haunting._make_tooltip_text()
	if not Utils.is_museum_unlocked():  # HACK: Already have a break if museum is unlocked.
		result += '\n'
	result += tr('\n[i]%s to pan to the relevant settlement.[/i]') % InputPrompts.get_input_markup(
			InputPrompts.InputType.LEFT_CLICK)
	return result
