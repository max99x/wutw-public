class_name Main
extends Node

enum State {
	INITIAL,
	MAIN_MENU,
	CUTSCENE_INTRO,
	HUB,
	RUN,
	CUTSCENE_1_TO_2,
	CUTSCENE_2_TO_3,
	CUTSCENE_3_TO_4,
	CUTSCENE_OUTRO,
	CUTSCENE_DEMO_END
}

signal state_changed(state: State)

const EDITOR_CONFIG_PATH := 'res://addons/wutw_editor/editor_game_startup_config.tres'
static var MAIN_MENU_SCENE := AsyncLoadedResource.new('res://main_menu/main_menu.tscn', false, AsyncLoadedResource.LoadPhase.STARTUP)
static var HUB_SCENE := AsyncLoadedResource.new('res://hub/hub.tscn')
static var RUN_SCENE := AsyncLoadedResource.new('res://run/run.tscn')
static var INTRO_SCENE := AsyncLoadedResource.new('res://cutscenes/intro/cutscene_intro.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var CUTSCENE_1_TO_2_SCENE := AsyncLoadedResource.new('res://cutscenes/1to2/cutscene_1to2.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)
static var CUTSCENE_2_TO_3_SCENE := AsyncLoadedResource.new('res://cutscenes/2to3/cutscene_2to3.tscn', true, AsyncLoadedResource.LoadPhase.UNLIKELY)
static var CUTSCENE_3_TO_4_SCENE := AsyncLoadedResource.new('res://cutscenes/3to4/cutscene_3to4.tscn', true, AsyncLoadedResource.LoadPhase.UNLIKELY)
static var CUTSCENE_OUTRO := AsyncLoadedResource.new('res://cutscenes/outro/cutscene_outro.tscn', true, AsyncLoadedResource.LoadPhase.UNLIKELY)
static var CUTSCENE_DEMO_END_SCENE := AsyncLoadedResource.new('res://cutscenes/demo_end/cutscene_demo_end.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)

@export var starting_state: State = State.MAIN_MENU

var _state: State = State.INITIAL:
	set = _transition_to_state
var _current_scene: Node
var _requested_run_config: RunConfig
var _transition_type: UI.TransitionType = UI.TransitionType.NONE

func _ready() -> void:
	# Restore graphics settings.
	DisplayServer.window_set_mode(GameSettings.Display.window_mode.value() as DisplayServer.WindowMode)
	DisplayServer.window_set_vsync_mode(GameSettings.Display.vsync.value() as DisplayServer.VSyncMode)
	Engine.max_fps = GameSettings.Display.fps_cap.value()

	_print_system_info()

	# Load translation if locale is set.
	var chosen_locale := GameSettings.Interface.locale.value()
	if not chosen_locale.is_empty():
		var available_translations := GameSettings.get_translatable_locales()
		if chosen_locale in available_translations:
			var t := load(available_translations[chosen_locale]) as Translation
			t.locale = chosen_locale
			TranslationServer.add_translation(t)
			TranslationServer.set_locale(t.locale)
		else:
			push_warning('Translation for chosen locale "%s" not found.' % chosen_locale)

	# Handle the game ending to go to the outro cutscene.
	GlobalSaveGame.game_finished.connect(go_to_outro)

	await GlobalStartup.wait_loaded_startup()

	# Handle editor startup config.
	if Utils.is_dev() and FileAccess.file_exists(EDITOR_CONFIG_PATH):
		var startup_config := load(EDITOR_CONFIG_PATH) as EditorGameStartupConfig
		if startup_config.start_state != State.MAIN_MENU:
			await GlobalStartup.wait_loaded_normal()
		startup_config.apply(self)

	var tween := create_tween()
	tween.tween_property(%LoadingScreen, 'modulate:a', 0, 0.2 if Utils.is_dev() else 1.0)
	tween.tween_property(%LoadingScreen, 'visible', false, 0.001)
	tween.play()

	GlobalUI.return_to_main_menu_requested.connect(func() -> void:
		_state = State.INITIAL
		_requested_run_config = null
		GlobalUI.reset()
		GlobalSaveGame.clear()
		_state = State.MAIN_MENU
	)

	_state = starting_state

func get_current_scene() -> Node:
	return _current_scene

func get_state() -> State:
	return _state

func go_to_outro() -> void:
	_state = State.CUTSCENE_OUTRO

func _handle_esc() -> bool:
	return _state == State.MAIN_MENU  # Prevent pause menu.

func _transition_to_state(new_state: State) -> void:
	if _state == new_state:
		return

	if _state == State.RUN:
		GlobalSaveGame.run_exited.emit(Utils.get_active_run())
	elif _state == State.HUB:
		GlobalSaveGame.hub_exited.emit(Utils.get_active_hub())

	_state = new_state
	_clear_current_scene()
	match _state:
		State.INITIAL:
			return
		State.MAIN_MENU:
			_transition_main_menu()
		State.CUTSCENE_INTRO:
			_transition_intro()
		State.HUB:
			_transition_hub()
		State.RUN:
			_transition_run()
		State.CUTSCENE_1_TO_2:
			_transition_cutscene_1to2()
		State.CUTSCENE_2_TO_3:
			_transition_cutscene_2to3()
		State.CUTSCENE_3_TO_4:
			_transition_cutscene_3to4()
		State.CUTSCENE_OUTRO:
			_transition_cutscene_outro()
		State.CUTSCENE_DEMO_END:
			_transition_cutscene_demo_end()
		_:
			push_error('Main game state invalid.')
	state_changed.emit(_state)

	if _state == State.RUN:
		GlobalSaveGame.run_entered.emit(Utils.get_active_run())
	elif _state == State.HUB:
		GlobalSaveGame.hub_entered.emit(Utils.get_active_hub())

func _transition_main_menu() -> void:
	var main_menu := MAIN_MENU_SCENE.instantiate_loaded_scene() as MainMenu
	main_menu.intro_selected.connect(func() -> void: _state = State.CUTSCENE_INTRO)
	main_menu.hub_selected.connect(func() -> void: _state = State.HUB)
	main_menu.resume_run_selected.connect(func() -> void: _state = State.RUN)
	_set_current_scene(main_menu, UI.Layer.GAME)

func _transition_intro() -> void:
	var intro := INTRO_SCENE.instantiate_loaded_scene() as Cutscene_Slideshow
	intro.finished.connect(func() -> void:
		_requested_run_config = RunConfig.new()
		_requested_run_config.run_type = load('res://run/types/run_type_tutorial.tres') as RunType
		_requested_run_config.starting_cards = SaveGame.get_starter_cards()
		_requested_run_config.run_seed = 101
		_requested_run_config.force_legacy_random = true
		# Using the default (fallback) map generation config and legacy random,
		# since it's well tested for this case.
		_transition_type = UI.TransitionType.ZOOM
		_state = State.RUN)
	_transition_type = UI.TransitionType.FADE_TO_BLACK
	_set_current_scene(intro, UI.Layer.CUTSCENE)

func _transition_hub() -> void:
	GlobalSaveGame.clear_run()
	var hub := HUB_SCENE.instantiate_loaded_scene() as Hub
	hub.run_requested.connect(func(run_config: RunConfig) -> void:
		_requested_run_config = run_config
		_transition_type = UI.TransitionType.PORTAL
		_state = State.RUN
	)
	_set_current_scene(hub, UI.Layer.GAME)

func _transition_run() -> void:
	var run := RUN_SCENE.instantiate_loaded_scene() as Run
	run.run_config = _requested_run_config
	run.run_ended.connect(func() -> void:
		await get_tree().process_frame  # Make sure anything waiting for run end gets to run first.

		if run.get_settlement_states().is_empty():
			_transition_type = UI.TransitionType.CLEAR
		else:
			_transition_type = UI.TransitionType.SCROLLIFY

		var main_quest_progress := GlobalSaveGame.get_main_quest_progress()
		if main_quest_progress == SaveGame.MainQuestProgress.P140_DEDICATED_STATUE:
			_state = State.CUTSCENE_1_TO_2
		elif main_quest_progress == SaveGame.MainQuestProgress.P230_PREPARED_RITUAL:
			if Utils.is_demo():
				if GameSettings.FirstRun.demo_end_seen.value():
					_state = State.HUB
				else:
					_state = State.CUTSCENE_DEMO_END
					GameSettings.FirstRun.demo_end_seen.set_value(true, true)
			else:
				_state = State.CUTSCENE_2_TO_3
		elif main_quest_progress == SaveGame.MainQuestProgress.P350_SIGNED_ACCORD:
			_state = State.CUTSCENE_3_TO_4
		else:
			_state = State.HUB
	)
	run.reload_requested.connect(_reload)
	_set_current_scene(run, UI.Layer.GAME)

func _transition_cutscene_1to2() -> void:
	var cutscene := CUTSCENE_1_TO_2_SCENE.instantiate_loaded_scene() as Cutscene_Slideshow
	cutscene.finished.connect(func() -> void: _state = State.HUB)
	_set_current_scene(cutscene, UI.Layer.CUTSCENE)

func _transition_cutscene_2to3() -> void:
	var cutscene := CUTSCENE_2_TO_3_SCENE.instantiate_loaded_scene() as Cutscene_Slideshow
	cutscene.finished.connect(func() -> void: _state = State.HUB)
	_set_current_scene(cutscene, UI.Layer.CUTSCENE)

func _transition_cutscene_3to4() -> void:
	var cutscene := CUTSCENE_3_TO_4_SCENE.instantiate_loaded_scene() as Cutscene_Slideshow
	cutscene.finished.connect(func() -> void: _state = State.HUB)
	_set_current_scene(cutscene, UI.Layer.CUTSCENE)

func _transition_cutscene_outro() -> void:
	var cutscene := CUTSCENE_OUTRO.instantiate_loaded_scene() as Cutscene_Slideshow
	cutscene.finished.connect(func() -> void:
		_transition_type = UI.TransitionType.ZOOM
		_state = State.MAIN_MENU
	)
	_transition_type = UI.TransitionType.FADE_TO_BLACK
	_set_current_scene(cutscene, UI.Layer.CUTSCENE)

func _transition_cutscene_demo_end() -> void:
	var cutscene := CUTSCENE_DEMO_END_SCENE.instantiate_loaded_scene() as Cutscene_Demo_End
	cutscene.finished.connect(func() -> void: _state = State.HUB)
	_set_current_scene(cutscene, UI.Layer.CUTSCENE)

func _clear_current_scene() -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null
	GlobalUI.clear_layer(UI.Layer.STATE_MENU_SUBMENU)
	GlobalUI.clear_layer(UI.Layer.STATE_MENU)
	GlobalUI.clear_layer(UI.Layer.GAME_MENU_SUBMENU)
	GlobalUI.clear_layer(UI.Layer.GAME_MENU)
	GlobalUI.clear_layer(UI.Layer.GAME)

func _set_current_scene(new_scene: Node, layer: UI.Layer) -> void:
	_current_scene = new_scene
	GlobalUI.add_layer_content(_current_scene, layer)
	GlobalUI.show_loading_transition(_transition_type)
	_transition_type = UI.TransitionType.CLEAR

func _reload() -> void:
	_state = State.INITIAL
	_requested_run_config = null
	GlobalUI.reset()
	GlobalSaveGame.load_game(GlobalSaveGame.get_current_slot())
	if GlobalSaveGame.get_run_data():
		_state = State.RUN
	elif GlobalSaveGame.get_main_quest_progress() <= SaveGame.MainQuestProgress.P000_INTRO:
		_state = State.CUTSCENE_INTRO
	else:
		_state = State.HUB

func _print_system_info() -> void:
	if not Utils.is_packaged():
		return

	var build_metadata := load(BuildMetadata.EXPORT_PATH) as BuildMetadata
	prints('Build Commit:', build_metadata.git_commit_hash)
	prints('Build Tag:', build_metadata.git_tag)

	prints('OS:', '%s (%s)' % [OS.get_name(), OS.get_version()])
	prints('CPU:', '%s (%d threads)' % [OS.get_processor_name(), OS.get_processor_count()])

	prints('GPU:', RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor())
	prints('GPU Driver:', ' | '.join(OS.get_video_adapter_driver_info()))
	prints('GPU API Version:', RenderingServer.get_video_adapter_api_version())

	var mem := OS.get_memory_info()
	prints('RAM Physical:', String.humanize_size(mem['physical'] as int))
	prints('RAM Available:', String.humanize_size(mem['available'] as int))
	prints('RAM Stack:', String.humanize_size(mem['stack'] as int))

	prints('Screen Size:', DisplayServer.screen_get_size())
	prints('Screen Count:', DisplayServer.get_screen_count())
	prints('Screen DPI:', DisplayServer.screen_get_dpi())
	prints('Screen Scale:', DisplayServer.screen_get_scale())
	const WINDOW_MODES := {
		DisplayServer.WINDOW_MODE_WINDOWED: 'Windowed',
		DisplayServer.WINDOW_MODE_MINIMIZED: 'Minimized',
		DisplayServer.WINDOW_MODE_MAXIMIZED: 'Maximized',
		DisplayServer.WINDOW_MODE_FULLSCREEN: 'Fullscreen',
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: 'Exclusive Fullscreen'
	}
	var window_mode := DisplayServer.window_get_mode()
	prints('Window Mode:', WINDOW_MODES.get(window_mode, 'Unknown (%s)' % window_mode))
	prints('Touchscreen:', DisplayServer.is_touchscreen_available())

	var user_dir := DirAccess.open('user://')
	if user_dir:
		prints('Space (user://):', String.humanize_size(user_dir.get_space_left()))

	var temp_path := OS.get_temp_dir()
	if not temp_path:
		temp_path = '/tmp'
	var temp_dir := DirAccess.open(temp_path)
	if temp_dir:
		prints('Space (Temp):', String.humanize_size(temp_dir.get_space_left()))
	print('--------------------')
