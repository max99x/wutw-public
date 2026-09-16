@tool
class_name Survey
extends PanelContainer

signal started
signal episode_started(episode: SurveyEpisode)
signal outcome_started
signal outcome_finished
signal finished_all_episodes
signal seen_outcome_on_death

static var RECIPE_SCENE := AsyncLoadedResource.new('res://stage/survey/survey_recipe.tscn')

enum ScrollMode { OFF, ON, FINISH }
const TEXT_ANIMATION_DURATION := 0.015
const CHOICES_ANIMATION_WAIT := 0.3
const CHOICES_ANIMATION_DURATION := 0.3

@export var map_location: Vector2
@export_custom(PROPERTY_HINT_NONE, '', PropertyUsageFlags.PROPERTY_USAGE_EDITOR)
var debug_episode: SurveyEpisode:
	set(value):
		debug_episode = value
		if debug_episode:
			assert(Utils.is_in_editor())
			_start_episode(debug_episode, false, false)

@onready var _scroll_panel: ScrollPanel = %ScrollPanel
@onready var _main_text: MarkedUpLabel = %MainText
@onready var _choices_list: HBoxContainer = %ChoicesList
@onready var _multiuse_prep_buttons: Array[SurveyPrepButton] = [
	%PrepButton_Food,
	%PrepButton_Safety,
	%PrepButton_Beauty,
	%PrepButton_Harmony,
	%PrepButton_Knowledge,
	%PrepButton_Productivity,
]
var _available_episodes: Dictionary[SurveyEpisode, float]
var _overridden_result_text: String
var _reveal_tween: Tween
var _sfx_playing_id: int = 0
var _finished_episodes: Array[SurveyEpisode]
var _max_episodes: int = 0
var _scroll_mode := ScrollMode.OFF
var _max_scroll: float = 0

func _ready() -> void:
	(%SkipButton as Control).visible = false
	(%EndText as Control).visible = false

	if Utils.is_in_editor():
		return

	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)

	# Cancel auto-scroll if user scrolled.
	var scroller := %Scroller as ScrollContainer
	scroller.get_v_scroll_bar().scrolling.connect(func() -> void:
		_scroll_mode = ScrollMode.OFF
	)

	# Handle prep.
	var fade_in := true
	var num_preps := Skill.get_skill_var(Skill.Var.SURVEY_PREPS)
	if num_preps > 0:
		(%VBox_Preparation as Control).visible = true
		(%VBox_Episode as Control).visible = false
		Utils.clear_node(_choices_list)

		for prep_button in _multiuse_prep_buttons:
			prep_button.max_uses = num_preps

		await _scroll_panel.animate_unroll(_scroll_panel.default_unroll_duration)
		fade_in = false

		await (%StartButton as Button).pressed

		Utils.set_input_enabled(_scroll_panel, false)
		await _scroll_panel.animate_roll(_scroll_panel.default_roll_duration, false)

	(%VBox_Preparation as Control).visible = false
	(%VBox_Episode as Control).visible = true

	# Choose episodes.
	var run := Utils.get_active_run()
	_available_episodes = SurveyEpisode.choose_episodes(run, map_location)
	if not Utils.ensure(not _available_episodes.is_empty()):
		_available_episodes = {SurveyEpisode.get_all_episodes().values()[0]: 1}
	_max_episodes = run.scaling.survey_episode_count_base + Skill.get_skill_var(Skill.Var.SURVEY_EXTRA_EPISODES)
	_max_episodes = mini(_max_episodes, _available_episodes.size())

	# Start the first episode.
	var starting_episode := run.get_events_random().pick_weighted_dict(_available_episodes)[0] as SurveyEpisode
	_available_episodes.erase(starting_episode)
	await _start_episode(starting_episode, false, fade_in)

	started.emit()

func _process(_delta: float) -> void:
	if _scroll_mode != ScrollMode.OFF:
		# Auto-scroll if needed.
		var scroller := %Scroller as ScrollContainer
		var target_scroll_amount := minf(_max_scroll, (%ScrollerContents as Control).size.y - scroller.size.y)
		var scroll_delta := target_scroll_amount - scroller.scroll_vertical
		# Lame, but we have to use ints so delta is out.
		if scroll_delta > 0:
			scroller.scroll_vertical += min(scroll_delta, 4)
		if _scroll_mode == ScrollMode.FINISH and target_scroll_amount <= scroller.scroll_vertical:
			_scroll_mode = ScrollMode.OFF

# I've seen too many people do this unintentionally, and none actually mean it.
#func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
#	assert(data is Card)
#	return SlotUtils.match_slot(get_all_aspect_slots(), (data as Card).card_type.aspects) != null
#
#func _drop_data(_pos: Vector2, data: Variant) -> void:
#	assert(data is Card)
#	var slot := SlotUtils.match_slot(get_all_aspect_slots(), (data as Card).card_type.aspects)
#	assert(slot)
#	slot.card_dropped.emit(data as Card)

func _exit_tree() -> void:
	_stop_sfx()  # Just in case.

func _update_font_size() -> void:
	Utils._scale_font_size(_main_text, false, 18)
	Utils._scale_font_size(%EndText as RichTextLabel, false, 18)

func is_preparing() -> bool:
	return (%VBox_Preparation as Control).visible

func get_recipes() -> Array[SurveyRecipe]:
	var result: Array[SurveyRecipe]
	result.assign(_choices_list.get_children())
	return result

func get_all_aspect_slots() -> Array[AspectSlot]:
	var result: Array[AspectSlot]
	for recipe in _choices_list.get_children():
		if recipe is SurveyRecipe:  # IMPORTANT: Not a placeholder!
			result.append_array((recipe as SurveyRecipe).get_aspect_slots())
	return result

func get_max_episodes() -> int:
	return _max_episodes

func get_finished_episodes() -> Array[SurveyEpisode]:
	return _finished_episodes

func get_num_episodes_finished() -> int:
	return _finished_episodes.size()

func override_result_text(result_text: String) -> void:  # Input already translated.
	if _overridden_result_text:
		push_warning('Overriding text when already overridden.')
	_overridden_result_text = result_text

func _start_episode(episode: SurveyEpisode, roll: bool, fade_in: bool) -> void:
	if roll and not Utils.is_in_editor():
		Utils.set_input_enabled(_scroll_panel, false)
		await _scroll_panel.animate_roll(_scroll_panel.default_roll_duration, false)

	(%TitleLabel as Label).text = '%s (%d/%d)' % [
		tr(episode.title), _finished_episodes.size() + 1, _max_episodes]
	(%BG as TextureRect).texture = await episode.background_image.get_texture_async()
	(%CreditsIcon as CreditsIcon).art_piece = episode.background_credit
	(%NewIcon as Control).visible = Utils.is_in_editor() or not GlobalSaveGame.has_seen_survey(episode)

	_main_text.set_markedup_text(tr(episode.text))
	Utils.clear_node(%OutcomeBox)
	(%ContinueButton as Button).visible = false
	(%Scroller as ScrollContainer).scroll_vertical = 0

	Utils.clear_node(_choices_list)
	for choice in episode.choices:
		var recipe := RECIPE_SCENE.instantiate_loaded_scene() as SurveyRecipe
		recipe.episode = episode
		recipe.survey_choice = choice
		recipe.size_flags_vertical = Control.SIZE_SHRINK_END
		recipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe.activated.connect(_on_choice_activated.bind(episode, recipe))
		_choices_list.add_child(recipe)

	if not Utils.is_in_editor():
		_choices_list.modulate.a = 0
		_choices_list.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		_main_text.visible_characters = 0
		_main_text.visible_ratio = 0.0

		await _scroll_panel.animate_unroll(_scroll_panel.default_unroll_duration, fade_in)
		Utils.set_input_enabled(_scroll_panel, true)

		await _reveal_intro()

		Utils.get_active_run().get_run_data().used_episodes[episode] = true
		GlobalSaveGame.add_recent_survey_episode(episode)
		GlobalSaveGame.mark_survey_seen(episode)

	episode_started.emit(episode)

func _reveal_intro() -> void:
	(%SkipButton as Control).visible = true
	_reveal_tween = create_tween()
	var duration := TEXT_ANIMATION_DURATION * _main_text.get_total_character_count()
	_reveal_tween.tween_callback(_start_sfx)
	_reveal_tween.tween_property(_main_text, 'visible_characters', _main_text.get_total_character_count(), duration)
	_reveal_tween.tween_callback(_stop_sfx)
	_reveal_tween.tween_property(%SkipButton, 'visible', false, 0)
	_reveal_tween.tween_interval(CHOICES_ANIMATION_WAIT)
	_reveal_tween.tween_property(_choices_list, 'modulate:a', 1.0, CHOICES_ANIMATION_DURATION)
	_reveal_tween.set_speed_scale(Utils.anim_speed())
	_reveal_tween.play()
	await _reveal_tween.finished

	_choices_list.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED

func _on_choice_activated(episode: SurveyEpisode, recipe: SurveyRecipe) -> void:
	outcome_started.emit()

	_max_scroll = (%MainText as Control).size.y

	var choice := recipe.survey_choice
	GlobalSaveGame.mark_survey_choice_seen(episode, episode.choices.find(choice))

	# Disable inactive recipes to stop things like Fill.
	for other: SurveyRecipe in _choices_list.get_children():
		if other != recipe:
			other.disabled = true

	# This must happen *before* the text is updated, for text overrides to work.
	var outcome_widget: EventOutcomeWidget
	if choice.outcome:
		outcome_widget = choice.outcome.apply(null)

	var old_character_count := _main_text.get_total_character_count()
	var new_text := _main_text.get_markedup_text()
	new_text += '\n\n➤ ' + choice.label + '\n\n'
	if _overridden_result_text:
		new_text += _overridden_result_text
		_overridden_result_text = ''
	else:
		new_text += tr(choice.outcome_text)
	_main_text.set_markedup_text(new_text)
	var new_character_count := _main_text.get_total_character_count()

	(%SkipButton as Control).visible = true
	_reveal_tween = create_tween()
	var duration := TEXT_ANIMATION_DURATION * (new_character_count - old_character_count)
	_reveal_tween.tween_callback(_start_sfx)
	_reveal_tween.tween_property(_main_text, 'visible_characters', new_character_count, duration)
	_reveal_tween.tween_callback(_stop_sfx)
	_reveal_tween.tween_property(%SkipButton, 'visible', false, 0)

	_reveal_tween.tween_callback(recipe.update_outcome)

	if outcome_widget:
		_reveal_tween.tween_await(outcome_widget.finished)
		_reveal_tween.parallel().tween_callback(%OutcomeBox.add_child.bind(outcome_widget))

	_scroll_mode = ScrollMode.ON
	_reveal_tween.set_speed_scale(Utils.anim_speed())
	_reveal_tween.play()
	await _reveal_tween.finished

	_finished_episodes.append(episode)

	var run := Utils.get_active_run()
	run.signals.survey_episode_finished.emit(episode)

	var can_continue := _available_episodes and _finished_episodes.size() < _max_episodes
	if run.get_vars().get_current_value(RunVars.Var.CURRENT_INSPIRATION) <= 0:
		(%EndText as MarkedUpLabel).set_markedup_text(
			tr('[b]You have run out of inspiration, so the expedition is finished.[/b]'))
		(%EndText as Control).visible = true
		can_continue = true  # "Fake" continuie

	if can_continue:
		(%ContinueButton as Button).visible = true
		(%ContinueButton as Button).modulate.a = 0
		var tween := create_tween()
		tween.tween_property(%ContinueButton, 'modulate:a', 1.0, 0.3)
		tween.play()
		_scroll_mode = ScrollMode.FINISH

		await (%ContinueButton as Button).pressed

		outcome_finished.emit()

		_scroll_mode = ScrollMode.OFF
		_max_scroll = 0

		if run.get_vars().get_current_value(RunVars.Var.CURRENT_INSPIRATION) <= 0:
			seen_outcome_on_death.emit()

		# Start the next episode.
		var next_episode := run.get_events_random().pick_weighted_dict(_available_episodes)[0] as SurveyEpisode
		_available_episodes.erase(next_episode)
		_start_episode(next_episode, true, false)
	else:
		# TODO: Add a proper end screen with summary of inspiration, bonuses, relics, and insights.
		(%EndText as Control).visible = true
		_scroll_mode = ScrollMode.FINISH
		outcome_finished.emit()
		finished_all_episodes.emit()

func _start_sfx() -> void:
	_stop_sfx()
	_sfx_playing_id = GlobalAudioSystem.start_loop(AK.EVENTS.UI_DIALOGUE_TEXT_LOOP)

func _stop_sfx() -> void:
	if _sfx_playing_id:
		GlobalAudioSystem.stop_loop(_sfx_playing_id)
		_sfx_playing_id = 0

func _on_skip_button_pressed() -> void:
	if _reveal_tween.is_running():
		(%SkipButton as Control).visible = false
		_reveal_tween.set_speed_scale(100)
