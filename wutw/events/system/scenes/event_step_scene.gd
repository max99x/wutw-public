@tool
class_name EventStepScene
extends Control

static var EVENT_CHOICE_SCENE := AsyncLoadedResource.new('res://events/system/scenes/event_choice_scene.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
const TEXT_ANIMATION_DURATION := 0.015
const CHOICES_ANIMATION_WAIT := 0.3
const CHOICES_ANIMATION_DURATION := 0.3

signal finished(next_step: EventStep, outcome: EventOutcomeWidget)

@export var event: Event
@export var event_step: EventStep:
	set(value):
		event_step = value
		if is_node_ready():
			_recreate()
@export var outcome_widget: EventOutcomeWidget:
	set(value):
		outcome_widget = value
		if is_node_ready():
			_recreate()

var _overridden_next_step: EventStep
var _overridden_result_text: String

var _reveal_tween: Tween
var _sfx_playing_id: int = 0

func _ready() -> void:
	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)
	_recreate()
	_reveal()

func _exit_tree() -> void:
	_stop_sfx()

func override_next_step(next_step_id: String, result_text: String) -> void:  # Input translated.
	if _overridden_next_step or _overridden_result_text:
		push_warning('Overriding next step when already overridden.')
	_overridden_next_step = event.get_step_by_id(next_step_id) if next_step_id else null
	_overridden_result_text = result_text

func _update_font_size() -> void:
	Utils._scale_font_size(%MainText as RichTextLabel, false, 18)

func _recreate() -> void:
	if not event_step:
		return

	(%BG as TextureRect).texture = event_step.background
	(%MainText as MarkedUpLabel).set_markedup_text(
		tr(event_step.markedup_text), MarkedUpLabel.LinkMode.LINK)
	(%CreditsIcon as CreditsIcon).art_piece = event_step.background_credit

	Utils.clear_node(%ChoicesList)
	var all_choices: Array[EventChoice] = event_step.choices.duplicate()
	var run := Utils.get_active_run()
	if run:
		run.get_events_random().shuffle(all_choices)
	if event_step.exit_choice:
		all_choices.append(event_step.exit_choice)
	for choice in all_choices:
		if choice.show_condition and not choice.show_condition.is_satisfied(run, event):
			continue
		var choice_scene := EVENT_CHOICE_SCENE.instantiate_loaded_scene() as EventChoiceScene
		choice_scene.event = event
		choice_scene.event_step = event_step
		choice_scene.event_choice = choice
		choice_scene.selected.connect(_on_choice_selected.bind(choice))
		%ChoicesList.add_child(choice_scene)
	if all_choices.size() <= 4:
		(%ScrollContainer as Control).custom_minimum_size.y = 310
	else:
		(%ScrollContainer as Control).custom_minimum_size.y = 250

func _on_choice_selected(choice: EventChoice) -> void:
	var widget: EventOutcomeWidget = null
	if choice.outcome:
		GlobalSaveGame.mark_event_choice_seen(event, event.get_choice_index(choice))
		widget = choice.outcome.apply(event)

	var result_text := _overridden_result_text if _overridden_result_text else tr(choice.markedup_result_text)
	var result_next_step := _overridden_next_step if _overridden_next_step else event.get_step_by_id(choice.result_event_step_id)

	if result_text:
		var fake_step := EventStep.new()
		fake_step.background_image = LazyTextureResource.new()
		fake_step.background_image._texture_path = event_step.background.resource_path
		fake_step.background_image._cached_texture = event_step.background
		fake_step.background_credit = event_step.background_credit
		fake_step.markedup_text = result_text
		fake_step.choices = [EventChoice.new()]
		fake_step.choices[0].markedup_text = tr('Continue')
		fake_step.choices[0].result_event_step_id = choice.result_event_step_id
		finished.emit(fake_step, widget)
	elif result_next_step:
		finished.emit(result_next_step, widget)
	else:
		finished.emit(null, widget)

	_overridden_next_step = null
	_overridden_result_text = ''

func _reveal() -> void:
	if not Utils.is_in_editor():
		if outcome_widget:
			(%Spacer as Control).visible = true
		else:
			(%Spacer as Control).visible = false

		var main_label := %MainText as MarkedUpLabel
		main_label.visible_ratio = 0.0
		(%ChoicesList as Control).modulate.a = 0
		(%ChoicesList as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		(%SkipButton as Control).visible = true
		_reveal_tween = create_tween()
		var duration := TEXT_ANIMATION_DURATION * float(main_label.get_total_character_count())
		_reveal_tween.tween_callback(_start_sfx)
		_reveal_tween.tween_property(main_label, 'visible_ratio', 1.0, duration)
		_reveal_tween.tween_callback(_stop_sfx)
		_reveal_tween.tween_property(%SkipButton, 'visible', false, 0)
		_reveal_tween.set_speed_scale(Utils.anim_speed())
		_reveal_tween.play()
		await _reveal_tween.finished

		Utils.clear_node(%OutcomeBox)
		if outcome_widget:
			%OutcomeBox.add_child(outcome_widget)
			await outcome_widget.finished
			# Force choice recreation since requirements may have been affected by the outcome.
			for choice: EventChoiceScene in %ChoicesList.get_children():
				choice.event_choice = choice.event_choice

		var tween := create_tween()
		tween.tween_interval(CHOICES_ANIMATION_WAIT)
		tween.tween_property(%ChoicesList, 'modulate:a', 1.0, CHOICES_ANIMATION_DURATION)
		tween.play()
		await tween.finished
		(%ChoicesList as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED

func _start_sfx() -> void:
	_stop_sfx()
	_sfx_playing_id = GlobalAudioSystem.start_loop(AK.EVENTS.UI_DIALOGUE_TEXT_LOOP)

func _stop_sfx() -> void:
	if _sfx_playing_id:
		GlobalAudioSystem.stop_loop(_sfx_playing_id)
		_sfx_playing_id = 0

func _on_skip_button_pressed() -> void:
	if _reveal_tween.is_running():
		_reveal_tween.set_speed_scale(100)
