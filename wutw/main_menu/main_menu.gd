class_name MainMenu
extends Node2D

signal intro_selected
signal hub_selected
signal resume_run_selected

static var SETTINGS_DIALOG_SCENE := AsyncLoadedResource.new('res://settings/settings_dialog.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var SLOTS_MENU_SCENE := AsyncLoadedResource.new('res://main_menu/save_slots_menu.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var CREDITS_MENU_SCENE := AsyncLoadedResource.new('res://main_menu/credits_menu.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)

const MAX_SAVES := 100  # If you have 100 savegames, you've got bigger problems.

@export var preview_mode := false

var _fade_tween: Tween

func _ready() -> void:
	(%LoadingLabel as Control).modulate.a = 0
	if preview_mode:
		for cloud: MainMenuCloud in %Clouds.get_children():
			cloud.set_process(false)
		(%Logo as Control).modulate.a = 0
		(%ButtonsList as Control).modulate.a = 0
		(%DiscordButton as Control).modulate.a = 0
		(%CreditsIcon as Control).modulate.a = 0
		for child in get_children():
			if child is Control:
				Utils.set_input_enabled(child as Control, false)
		Utils.set_input_enabled(%CloudsFader as Control, false)
	else:
		GlobalAudioSystem.switch_music(AK.SWITCHES.MUSIC.SWITCH.MAIN_MENU)
		(%CatAnimationPlayer as AnimationPlayer).play('idle')

		if _get_used_save_slots().is_empty():
			(%ContinueButton as Button).visible = false

	if Utils.is_steam_deck() and not GameSettings.FirstRun.steam_deck_welcomed.value():
		if GameSettings.Interface.zoom_on_hover.value() == UI.ZoomMode.DISABLED:
			GameSettings.Interface.zoom_on_hover.set_value(UI.ZoomMode.SHIFT)
		GameSettings.Display.clouds_on_map.set_value(false)
		if GameSettings.Interface.paragraph_font_scale.value() < 1.3:
			GameSettings.Interface.paragraph_font_scale.set_value(1.3)
		if GameSettings.Interface.tooltip_font_scale.value() < 1.3:
			GameSettings.Interface.tooltip_font_scale.set_value(1.3)
		GameSettings.FirstRun.steam_deck_welcomed.set_value(true)
		GlobalGameSettings.save()
		if (%ContinueButton as Button).visible:
			var text := tr('The game has been updated with better Steam Deck support.')
			text += tr('\n\nSome default settings have changed, and the game now has an official input layout. You can check the full control bindings in the Steam controller menu.')
			GlobalUI.show_confirm(tr('Steam Deck Update'), text)
			# Don't really care what happens afterwards.

func _on_new_game_button_pressed() -> void:
	if not GlobalStartup.is_phase_finished(AsyncLoadedResource.LoadPhase.LIKELY):
		_fade_out()
		await GlobalStartup.wait_loaded_likely()

	var slot := 0
	for i in range(MAX_SAVES):  # If you have 100 savegames, you've got other problems.
		if not SaveGame.savegame_exists(i):
			slot = i
			break

	if _get_used_save_slots().is_empty():
		_start_new_game(slot, false)
	else:
		var text := tr('This will create a new savegame slot.')
		text += '\n\n' + tr('Existing savegames will be unaffected, but previously seen hints will be skipped. You can also optionally skip the entire tutorial expedition.')
		var confirmation := GlobalUI.show_confirm(tr('New Savegame Slot'), text, tr('Ok'), tr('Cancel'), tr('Skip Tutorial'))
		confirmation.canceled.connect(func() -> void:
			# We might have deleted slots.
			(%ContinueButton as Button).visible = not _get_used_save_slots().is_empty()
			_fade_in()
		)
		confirmation.confirmed.connect(_start_new_game.bind(slot, false))
		confirmation.extra_selected.connect(_start_new_game.bind(slot, true))

func _on_continue_button_pressed() -> void:
	var used_slots := _get_used_save_slots()
	if used_slots.size() == 1:
		if not GlobalStartup.is_phase_finished(AsyncLoadedResource.LoadPhase.NORMAL):
			_fade_out()
			await GlobalStartup.wait_loaded_normal()
		_continue_from_slot(used_slots[0])
	else:
		Utils.ensure(used_slots.size() > 1)
		if not GlobalStartup.is_phase_finished(AsyncLoadedResource.LoadPhase.LIKELY):
			_fade_out()
			await GlobalStartup.wait_loaded_likely()
			while not SLOTS_MENU_SCENE.is_ready():
				await get_tree().process_frame
		var slots_menu := SLOTS_MENU_SCENE.instantiate_loaded_scene() as SaveSlotsMenu
		slots_menu.slots = used_slots
		slots_menu.selected.connect(_continue_from_slot)
		slots_menu.canceled.connect(_fade_in)
		GlobalUI.add_layer_content(slots_menu, UI.Layer.PAUSE_MENU_SUBMENU)

func _continue_from_slot(slot: int) -> void:
	GlobalSaveGame.load_game(slot)
	if Utils.is_demo() and GlobalSaveGame.get_main_quest_progress() > SaveGame.MainQuestProgress.P230_PREPARED_RITUAL:
		var text := tr('This is a savegame from the full version of the game, and cannot be loaded in the demo version.')
		GlobalUI.show_confirm(tr('That\'s a Full Game Save!'), text, tr('Ok'), '')
		GlobalSaveGame.clear()
		return
	if GlobalSaveGame.get_run_data():
		resume_run_selected.emit()
	else:
		hub_selected.emit()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _start_new_game(slot: int, skip_tutorial: bool) -> void:
	GlobalSaveGame.init_new_game(slot)
	GlobalSaveGame.save_game()
	if skip_tutorial:
		GlobalSaveGame.insights = 50
		GlobalSaveGame.set_main_quest_progress(SaveGame.MainQuestProgress.P110_COMPLETED_TUTORIAL)
		var relic_quest := load('res://quests/main/phase1/1_15_relics/quest_main_1_15_relics.tres') as Quest
		var next_instance := relic_quest.instantiate(QuestInstance.STATE_INACTIVE)
		GlobalSaveGame.add_quest_instance(next_instance)
		GlobalSaveGame.save_game()
		hub_selected.emit()
	else:
		intro_selected.emit()

func _on_settings_button_pressed() -> void:
	if not GlobalStartup.is_phase_finished(AsyncLoadedResource.LoadPhase.LIKELY):
		_fade_out()
		await GlobalStartup.wait_loaded_normal()
	await GlobalStartup.wait_loaded_normal()
	var settings_dialog := SETTINGS_DIALOG_SCENE.instantiate_loaded_scene() as SettingsDialog
	GlobalUI.add_layer_content(settings_dialog, UI.Layer.PAUSE_MENU_SUBMENU)
	settings_dialog.closed.connect(_fade_in)

func _get_used_save_slots() -> Array[int]:
	var result: Array[int]
	for i in range(MAX_SAVES):  # If you have 100 savegames, you've got other problems.
		if SaveGame.savegame_exists(i) and SaveGame.is_savegame_accessible(i):
			result.append(i)
	return result

func _on_credits_button_pressed() -> void:
	var credits := CREDITS_MENU_SCENE.instantiate_loaded_scene() as CreditsMenu
	GlobalUI.add_layer_content(credits, UI.Layer.PAUSE_MENU_SUBMENU)

func _on_cat_button_pressed() -> void:
	if (%CatAnimationPlayer as AnimationPlayer).current_animation != 'react':
		(%CatAnimationPlayer as AnimationPlayer).play('react')
		(%CatAnimationPlayer as AnimationPlayer).queue('idle')
		GlobalAudioSystem.play(AK.EVENTS.SFX_ANIMAL_COMPANION_CAT)

func _fade_out() -> void:
	(%MouseBlocker as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(%ButtonsList, 'modulate:a', 0.0, 1.0)
	_fade_tween.parallel().tween_property(%LoadingLabel, 'modulate:a', 1.0, 1.0)
	_fade_tween.play()

	(%LoadingLabelTimer as Timer).start()
	(%LoadingLabel as Label).visible_characters = (%LoadingLabel as Label).get_total_character_count() - 3

func _fade_in() -> void:
	(%MouseBlocker as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(%LoadingLabel, 'modulate:a', 0.0, 0.2)
	_fade_tween.parallel().tween_property(%ButtonsList, 'modulate:a', 1.0, 1.0)
	_fade_tween.play()

	(%LoadingLabelTimer as Timer).stop()
	(%LoadingLabel as Label).visible_characters = -1

func _on_loading_label_timer_timeout() -> void:
	var label := %LoadingLabel as Label
	if label.visible_characters in [-1, (%LoadingLabel as Label).get_total_character_count()]:
		label.visible_characters = (%LoadingLabel as Label).get_total_character_count() - 3
	else:
		label.visible_characters += 1
