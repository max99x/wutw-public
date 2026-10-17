class_name SettingsDialog
extends Node2D

signal closed

var _closing: bool

func _ready() -> void:
	# Video
	(%Dropdown_Fullscreen as Dropdown).add_item(tr('Borderless'), DisplayServer.WINDOW_MODE_FULLSCREEN)
	(%Dropdown_Fullscreen as Dropdown).add_item(tr('Exclusive'), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	(%Dropdown_Fullscreen as Dropdown).add_item(tr('Windowed'), DisplayServer.WINDOW_MODE_WINDOWED)
	(%Dropdown_Fullscreen as Dropdown).set_selected_value(GameSettings.Display.window_mode.value())
	_setup_tooltip(%HBox_Fullscreen, tr('Game window display mode. Exclusive can be faster on older systems, but adds a delay when switching to a different application.'))
	if Utils.is_steam_deck():
		(%HBox_Fullscreen as Control).visible = false

	var vsync_enabled := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	(%Button_VSync as Button).button_pressed = vsync_enabled
	(%Button_VSync as Button).text = tr('ON') if vsync_enabled else tr('OFF')
	_setup_tooltip(%HBox_VSync, tr('Whether to synchronize game rendering to screen updates. Best left on unless troubleshooting.'))

	(%Dropdown_FPSCap as Dropdown).set_selected_value(GameSettings.Display.fps_cap.value())
	_setup_tooltip(%HBox_FPSCap, tr('The maximum framerate at which to run game updates. Choosing 30 can reduce power usage on battery-powered devices.'))

	var clouds_on_map := GameSettings.Display.clouds_on_map.value()
	(%Button_MapClouds as Button).button_pressed = clouds_on_map
	(%Button_MapClouds as Button).text = tr('ON') if clouds_on_map else tr('OFF')
	if Utils.is_compatibility_renderer():
		(%HBox_MapClouds as Control).visible = false
	elif Utils.get_active_run():
		(%Label_MapClouds as Label).text += tr(' (requires reload)')
	_setup_tooltip(%HBox_MapClouds, tr('Whether to display animated clouds on the shard maps. Can impact performance on older systems.'))

	var enable_map_effects := GameSettings.Display.enable_map_effects.value()
	(%Button_MapVFX as Button).button_pressed = enable_map_effects
	(%Button_MapVFX as Button).text = tr('ON') if enable_map_effects else tr('OFF')
	if Utils.is_compatibility_renderer():
		(%HBox_MapVFX as Control).visible = false
	elif Utils.get_active_run():
		(%Label_MapVFX as Label).text += tr(' (requires reload)')
	_setup_tooltip(%HBox_MapVFX, tr('Whether to display particle effects like smoke and insects on the shard maps. Can impact performance on older systems.'))

	var animate_sprite_changes := GameSettings.Display.animate_sprite_changes.value()
	(%Button_AnimateSpriteChanges as Button).button_pressed = animate_sprite_changes
	(%Button_AnimateSpriteChanges as Button).text = tr('ON') if animate_sprite_changes else tr('OFF')
	_setup_tooltip(%HBox_AnimateSpriteChanges, tr('Whether to fade in map changes. Can be turned off on older systems if performance dips when developments are activated.'))

	# Audio
	(%Slider_MasterVolume as Slider).set_value(GlobalAudioSystem.get_master_volume())
	_setup_tooltip(%HBox_MasterVolume, tr('Controls the volume of all audio in the game.'))

	(%Slider_MusicVolume as Slider).set_value(GlobalAudioSystem.get_music_volume())
	_setup_tooltip(%HBox_MusicVolume, tr('Controls the volume of game music.'))
	(%Slider_AmbienceVolume as Slider).set_value(GlobalAudioSystem.get_ambience_volume())
	_setup_tooltip(%HBox_AmbienceVolume, tr('Controls the volume of game ambience, such as wind, birdsong, and cicadas.'))
	(%Slider_EffectsVolume as Slider).set_value(GlobalAudioSystem.get_effects_volume())
	_setup_tooltip(%HBox_EffectsVolume, tr('Controls the volume of gameplay sound effects.'))
	(%Slider_VoiceVolume as Slider).set_value(GlobalAudioSystem.get_voice_volume())
	_setup_tooltip(%HBox_VoiceVolume, tr('Controls the volume of voice-overs in cutscenes.'))
	(%Button_MuteUnfocused as Button).button_pressed = GameSettings.Audio.mute_unfocused.value()
	_setup_tooltip(%HBox_MuteUnfocused, tr('Whether to mute the game when the application is not in focus.'))
	_on_button_mute_unfocused_pressed()
	(%Button_SkipClaimedMusic as Button).button_pressed = GameSettings.Audio.skip_claimed_music.value()
	_setup_tooltip(%HBox_SkipClaimedMusic, tr('Whether to skip music tracks that may trigger Content ID claims on platforms like YouTube. If you receive a claim, license certificates are available upon request.'))
	_on_button_skip_claimed_music_pressed()

	# Interface
	var available_translations := GameSettings.get_translatable_locales()
	if available_translations.is_empty():
		(%HBox_Locale as Control).visible = false
	else:
		(%HBox_Locale as Control).visible = true
		_setup_tooltip(%HBox_Locale, tr('The game\'s language.'))
		(%Dropdown_Locale as Dropdown).add_item('English', '')
		for locale in available_translations:
			(%Dropdown_Locale as Dropdown).add_item(locale, locale)
		(%Dropdown_Locale as Dropdown).set_selected_value(GameSettings.Interface.locale.value())
	(%Slider_AnimSpeed as Slider).set_value(_multiplier_to_speed(
		GameSettings.Interface.animation_speed.value()))
	_setup_tooltip(%HBox_AnimSpeed, tr('How fast to play gameplay and UI animations.'))
	(%Slider_TooltipDelay as Slider).set_value(_multiplier_to_delay(
		GameSettings.Interface.tooltip_speed.value()))
	_setup_tooltip(%HBox_TooltipDelay, tr('How long to delay before showing tooltips on hover.'))
	(%Slider_TooltipFontScale as Slider).set_value(
		GameSettings.Interface.tooltip_font_scale.value())
	_setup_tooltip(%HBox_TooltipFontScale, tr('How to scale tooltip text.'))
	(%Slider_ParagraphFontScale as Slider).set_value(
		GameSettings.Interface.paragraph_font_scale.value())
	_setup_tooltip(%HBox_ParagraphFontScale, tr('How to scale free-flowing UI text.'))

	var icon_style := GameSettings.Interface.aspect_icons.value()
	(%Button_Icons_Normal as Button).button_pressed = icon_style == GameSettings.AspectIconStyle.CLASSIC
	(%Button_Icons_Accessible as Button).button_pressed = icon_style == GameSettings.AspectIconStyle.ACCESSIBLE
	(%Button_Icons_SuperAccessible as Button).button_pressed = icon_style == GameSettings.AspectIconStyle.SUPER_ACCESSIBLE
	(%Button_Icons_Accessible as Button).button_group.pressed.connect(_on_accessible_icons_changed)
	_setup_tooltip(%HBox_AccessibleIcons, tr('Which icons to use for essences everywhere in the game.'))

	var show_card_names := GameSettings.Interface.show_card_names.value()
	(%Button_AlwaysShowCardName as Button).button_pressed = show_card_names
	(%Button_AlwaysShowCardName as Button).text = tr('ON') if show_card_names else tr('OFF')
	_setup_tooltip(%HBox_AlwaysShowCardName, tr('Whether to show the name above glyph cards.'))

	var show_pause_button := GameSettings.Interface.show_pause_button.value()
	(%Button_ShowPauseButton as Button).button_pressed = show_pause_button
	(%Button_ShowPauseButton as Button).text = tr('ON') if show_pause_button else tr('OFF')
	_setup_tooltip(%HBox_ShowPauseButton, tr('Whether to show a button in the top right corner that opens the pause menu. The pause menu can always be opened by pressing Escape.'))

	(%Dropdown_ZoomOnHover as Dropdown).add_item(tr('Disabled'), UI.ZoomMode.DISABLED)
	if Utils.is_steam_deck():
		(%Dropdown_ZoomOnHover as Dropdown).add_item(tr('When L1 Held'), UI.ZoomMode.SHIFT)
	else:
		(%Dropdown_ZoomOnHover as Dropdown).add_item(tr('When Shift Held'), UI.ZoomMode.SHIFT)
	(%Dropdown_ZoomOnHover as Dropdown).add_item(tr('Always'), UI.ZoomMode.ALWAYS)
	var zoom_on_hover := GameSettings.Interface.zoom_on_hover.value() as UI.ZoomMode
	(%Dropdown_ZoomOnHover as Dropdown).set_selected_value(zoom_on_hover)
	_setup_tooltip(%HBox_ZoomOnHover, tr('Whether to zoom key UI elements when hovered. Useful for small screens.'))

	var show_settlement_border := GameSettings.Interface.show_settlement_border.value()
	(%Button_ShowSettlementBorder as Button).button_pressed = show_settlement_border
	(%Button_ShowSettlementBorder as Button).text = tr('ON') if show_settlement_border else tr('OFF')
	_setup_tooltip(%HBox_ShowSettlementBorder, tr('Whether to display settlement borders when selecting the location for a new settlement.'))

	var show_stage_bonuses := GameSettings.Interface.show_stage_bonuses.value()
	(%Button_ShowStageBonuses as Button).button_pressed = show_stage_bonuses
	(%Button_ShowStageBonuses as Button).text = tr('ON') if show_stage_bonuses else tr('OFF')
	_setup_tooltip(%HBox_ShowStageBonuses, tr('Whether to display the yields gained in the current foray above the goal bar, in addition to the standard expedition-long yields in the top right corner.'))

	var sort_predicted_yields := GameSettings.Interface.sort_predicted_yields.value()
	(%Button_SortPredictedYields as Button).button_pressed = sort_predicted_yields
	(%Button_SortPredictedYields as Button).text = tr('ON') if sort_predicted_yields else tr('OFF')
	_setup_tooltip(%HBox_SortPredictedYields, tr('Whether to sort yield predictions to show higher yields first when selecting a foray location.'))

	var vary_roof_color := GameSettings.Interface.vary_roof_color.value()
	(%Button_VaryRoofColor as Button).button_pressed = vary_roof_color
	(%Button_VaryRoofColor as Button).text = tr('ON') if vary_roof_color else tr('OFF')
	_setup_tooltip(%HBox_VaryRoofColor, tr('Whether to randomly choose a different roof color for each settlement. When off, all settlements share a standard color.'))

	var show_version_watermark := GameSettings.Interface.show_version_watermark.value()
	(%Button_ShowVersionWatermark as Button).button_pressed = show_version_watermark
	(%Button_ShowVersionWatermark as Button).text = tr('ON') if show_version_watermark else tr('OFF')
	_setup_tooltip(%HBox_ShowVersionWatermark, tr('Whether to show the game version label in the bottom right corner.'))

	_setup_tooltip(%ResetTutorialsButton, tr('Re-enable all previously seen contextual tutorials.'))

	# Controls
	(%Label_DeckControls as Control).visible = Utils.is_steam_deck()
	(%Button_ResetControls as Control).visible = not Utils.is_steam_deck()

	# Japanese
	var practice_enabled := GameSettings.Japanese.practice_enabled.value()
	(%Button_KanjiPractice as Button).button_pressed = practice_enabled
	(%Button_KanjiPractice as Button).text = tr('ON') if practice_enabled else tr('OFF')
	_setup_tooltip(%HBox_KanjiPractice, tr('Whether to enable the kanji practice minigame in the Haven. This allows you to practice vocabulary, readings, and example sentences to gain a small number of extra insight points.'))
	var kanji_drawing_enabled := GameSettings.Japanese.kanji_drawing_enabled.value()
	(%Button_KanjiDrawing as Button).button_pressed = kanji_drawing_enabled
	(%Button_KanjiDrawing as Button).text = tr('ON') if kanji_drawing_enabled else tr('OFF')
	_setup_tooltip(%HBox_KanjiDrawing, tr('Whether to enable the kanji drawing minigame when inscribing glyphs. When this is on, inscribing a glyph requires you to draw it successfully. There are no penalties for failing.'))

	var use_drawn_kanji := GameSettings.Japanese.use_drawn_kanji.value()
	(%Button_UseDrawnKanji as Button).button_pressed = use_drawn_kanji
	(%Button_UseDrawnKanji as Button).text = tr('ON') if use_drawn_kanji else tr('OFF')
	(%HBox_UseDrawnKanji as Control).modulate.a = 1.0 if kanji_drawing_enabled else 0.5
	(%HBox_UseDrawnKanji as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if kanji_drawing_enabled else Control.MOUSE_BEHAVIOR_DISABLED
	_setup_tooltip(%HBox_UseDrawnKanji, tr('Whether to use the player-drawn kanji as the image on inscribed glyph cards.'))

	(%Dropdown_CardNames as Dropdown).add_item(tr('Meaning'), GameSettings.CardNameDisplayType.MEANING)
	(%Dropdown_CardNames as Dropdown).add_item('くんよみ', GameSettings.CardNameDisplayType.KUNYOMI)
	(%Dropdown_CardNames as Dropdown).add_item('オンヨミ', GameSettings.CardNameDisplayType.ONYOMI)
	(%Dropdown_CardNames as Dropdown).add_item(tr('Kunyomi'), GameSettings.CardNameDisplayType.KUNYOMI_ROMAJI)
	(%Dropdown_CardNames as Dropdown).add_item(tr('Onyomi'), GameSettings.CardNameDisplayType.ONYOMI_ROMAJI)
	var card_names_display := GameSettings.Japanese.card_names.value() as GameSettings.CardNameDisplayType
	(%Dropdown_CardNames as Dropdown).set_selected_value(card_names_display)
	_setup_tooltip(%HBox_CardNames, tr('Whether to display the English meaning or the most common kunyomi or onyomi reading as the title above glyph cards.'))

	(%Dropdown_SettlementNames as Dropdown).add_item(tr('Romaji'), GameSettings.TownNameDisplayType.ROMAJI)
	(%Dropdown_SettlementNames as Dropdown).add_item('漢字', GameSettings.TownNameDisplayType.KANJI)
	(%Dropdown_SettlementNames as Dropdown).add_item('ひらがな', GameSettings.TownNameDisplayType.HIRAGANA)
	(%Dropdown_SettlementNames as Dropdown).add_item(tr('Meaning'), GameSettings.TownNameDisplayType.MEANING)
	var town_names_display := GameSettings.Japanese.town_names.value() as GameSettings.TownNameDisplayType
	(%Dropdown_SettlementNames as Dropdown).set_selected_value(town_names_display)
	_setup_tooltip(%HBox_SettlementNames, tr('How to display settlement names on the map and in various UIs. If kanji or hiragana are chosen, the translation appears in settlement tooltips.'))

	(%Dropdown_ShardNames as Dropdown).add_item(tr('Romaji'), GameSettings.ShardNameDisplayType.ROMAJI)
	(%Dropdown_ShardNames as Dropdown).add_item('漢字', GameSettings.ShardNameDisplayType.KANJI)
	(%Dropdown_ShardNames as Dropdown).add_item('ひらがな', GameSettings.ShardNameDisplayType.HIRAGANA)
	(%Dropdown_ShardNames as Dropdown).add_item(tr('Meaning'), GameSettings.ShardNameDisplayType.MEANING)
	var shard_names_display := GameSettings.Japanese.shard_names.value() as GameSettings.ShardNameDisplayType
	(%Dropdown_ShardNames as Dropdown).set_selected_value(shard_names_display)
	_setup_tooltip(%HBox_ShardNames, tr('How to display shard names on the map and in various UIs. If kanji or hiragana are chosen, the translation appears when hovering over the name.'))

	(%Dropdown_HauntingNames as Dropdown).add_item(tr('Romaji'), GameSettings.HauntingNameDisplayType.ROMAJI)
	(%Dropdown_HauntingNames as Dropdown).add_item('漢字', GameSettings.HauntingNameDisplayType.KANJI)
	(%Dropdown_HauntingNames as Dropdown).add_item('ひらがな', GameSettings.HauntingNameDisplayType.HIRAGANA)
	(%Dropdown_HauntingNames as Dropdown).add_item(tr('Meaning'), GameSettings.HauntingNameDisplayType.MEANING)
	var haunting_names_display := GameSettings.Japanese.haunting_names.value() as GameSettings.HauntingNameDisplayType
	(%Dropdown_HauntingNames as Dropdown).set_selected_value(haunting_names_display)
	_setup_tooltip(%HBox_HauntingNames, tr('How to display the names of hauntings (yōkai). If kanji or hiragana are chosen, the translation appears in tooltips.'))

	var embed_jp := GameSettings.Japanese.embed_jp.value()
	(%Button_EmbedJapanese as Button).button_pressed = embed_jp
	(%Button_EmbedJapanese as Button).text = tr('ON') if embed_jp else tr('OFF')
	_setup_tooltip(%HBox_EmbedJapanese, tr('Whether to use kanji names for shards and settlements in shard culture histories.'))

	(%Dropdown_Dictionary as Dropdown).add_item(tr('None'), GameSettings.DictionaryMode.NONE)
	(%Dropdown_Dictionary as Dropdown).add_item('かな', GameSettings.DictionaryMode.KANA)
	(%Dropdown_Dictionary as Dropdown).add_item(tr('Romaji'), GameSettings.DictionaryMode.ROMAJI)
	(%Dropdown_Dictionary as Dropdown).add_item(tr('かな (Romaji)'), GameSettings.DictionaryMode.KANA_AND_ROMAJI)
	var dictionary_mode := GameSettings.Japanese.dictionary_mode.value() as GameSettings.DictionaryMode
	(%Dropdown_Dictionary as Dropdown).set_selected_value(dictionary_mode)
	_setup_tooltip(%HBox_Dictionary, tr('How to display kanji readings and meanings in glyph tooltips everywhere in the game.'))

	var romaji_furigana := GameSettings.Japanese.romaji_furigana.value()
	(%Button_RomajiFurgana as Button).button_pressed = romaji_furigana
	(%Button_RomajiFurgana as Button).text = tr('ON') if romaji_furigana else tr('OFF')
	_setup_tooltip(%HBox_RomajiFurgana, tr('Whether to display romaji readings above kanji in the kanji practice minigame in place of furigana.'))

	# Default tab
	(%TabButton_Interface as Button).button_pressed = true
	_on_tab_button_interface_pressed()

	UI.register_zoomable(%ScrollPanel as ScrollPanel, 0.5, 0.5)

	(%ScrollPanel as ScrollPanel).animate_unroll()

func _enter_tree() -> void:
	GlobalAudioSystem.is_in_settings_menu = true

func _exit_tree() -> void:
	GlobalAudioSystem.is_in_audio_settings = false
	GlobalAudioSystem.is_in_settings_menu = false

func _handle_esc() -> bool:
	_close()
	return true

func _close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		queue_free()
		closed.emit()

func _on_close_button_pressed() -> void:
	GlobalGameSettings.save()
	_close()

func _on_dropdown_fullscreen_selected(item: DropdownItem) -> void:
	var window_mode := item.value as DisplayServer.WindowMode
	DisplayServer.window_set_mode(window_mode)
	GameSettings.Display.window_mode.set_value(window_mode, true)

func _on_button_v_sync_pressed() -> void:
	var new_vsync_enabled := (%Button_VSync as Button).button_pressed
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ADAPTIVE if new_vsync_enabled else DisplayServer.VSYNC_DISABLED)
	GameSettings.Display.vsync.set_value(DisplayServer.window_get_vsync_mode(), true)
	(%Button_VSync as Button).text = tr('ON') if new_vsync_enabled else tr('OFF')

func _on_dropdown_fps_cap_selected(item: DropdownItem) -> void:
	var fps_cap := item.value as int
	Engine.max_fps = fps_cap
	GameSettings.Display.fps_cap.set_value(fps_cap, true)

func _on_button_map_clouds_pressed() -> void:
	var clouds_on_map := (%Button_MapClouds as Button).button_pressed
	GameSettings.Display.clouds_on_map.set_value(clouds_on_map)
	(%Button_MapClouds as Button).text = tr('ON') if clouds_on_map else tr('OFF')

func _on_button_map_vfx_pressed() -> void:
	var enable_map_effects := (%Button_MapVFX as Button).button_pressed
	GameSettings.Display.enable_map_effects.set_value(enable_map_effects)
	(%Button_MapVFX as Button).text = tr('ON') if enable_map_effects else tr('OFF')

func _on_button_animate_sprite_changes_pressed() -> void:
	var animate_sprite_changes := (%Button_AnimateSpriteChanges as Button).button_pressed
	GameSettings.Display.animate_sprite_changes.set_value(animate_sprite_changes)
	(%Button_AnimateSpriteChanges as Button).text = tr('ON') if animate_sprite_changes else tr('OFF')

func _on_slider_anim_speed_value_changed(value: float) -> void:
	var multiplier := _speed_to_multiplier(roundi(value))
	GameSettings.Interface.animation_speed.set_value(multiplier, true)
	(%Label_AnimSpeedValue as Label).text = _speed_to_description(roundi(value))

func _on_slider_tooltip_delay_value_changed(value: float) -> void:
	var multiplier := _delay_to_multiplier(roundi(value))
	GameSettings.Interface.tooltip_speed.set_value(multiplier, true)
	(%Label_TooltipDelayValue as Label).text = _delay_to_description(roundi(value))

func _on_slider_tooltip_font_scale_value_changed(value: float) -> void:
	var tooltip_font_scale := value
	GameSettings.Interface.tooltip_font_scale.set_value(tooltip_font_scale, true)
	(%Label_TooltipFontScaleValue as Label).text = tr('%.1fx') % tooltip_font_scale

func _on_slider_paragraph_font_scale_value_changed(value: float) -> void:
	var paragraph_font_scale := value
	GameSettings.Interface.paragraph_font_scale.set_value(paragraph_font_scale, true)
	(%Label_ParagraphFontScaleValue as Label).text = tr('%.1fx') % paragraph_font_scale

func _on_reset_tutorials_button_pressed() -> void:
	GlobalTutorialSystem.reset_all_tutorials()
	(%ResetTutorialsButton as Button).disabled = true

func _on_master_volume_slider_value_changed(value: float) -> void:
	GlobalAudioSystem.set_master_volume(value)
	(%Label_MasterVolumeValue as Label).text = str(roundi(value * 100))

func _on_slider_music_volume_value_changed(value: float) -> void:
	GlobalAudioSystem.set_music_volume(value)
	(%Label_MusicVolumeValue as Label).text = str(roundi(value * 100))

func _on_slider_ambience_volume_value_changed(value: float) -> void:
	GlobalAudioSystem.set_ambience_volume(value)
	(%Label_AmbienceVolumeValue as Label).text = str(roundi(value * 100))

func _on_slider_effects_volume_value_changed(value: float) -> void:
	GlobalAudioSystem.set_effects_volume(value)
	GlobalAudioSystem.set_ui_volume(value)
	(%Label_EffectsVolumeValue as Label).text = str(roundi(value * 100))

func _on_slider_voice_volume_value_changed(value: float) -> void:
	GlobalAudioSystem.set_voice_volume(value)
	(%Label_VoiceVolumeValue as Label).text = str(roundi(value * 100))

func _speed_to_multiplier(level: int) -> float:
	match level:
		1: return 0.25
		2: return 0.5
		3: return 1.0
		4: return 1.5
		5: return 2.0
		6: return 4.0
		7: return 10.0
		_: Utils.ensure(false); return 1.0

func _multiplier_to_speed(multiplier: float) -> int:
	var result: int
	if multiplier <= 0.3:
		result = 1
	elif multiplier <= 0.6:
		result = 2
	elif multiplier <= 1.1:
		result = 3
	elif multiplier <= 1.6:
		result = 4
	elif multiplier <= 2.1:
		result = 5
	elif multiplier <= 4.1:
		result = 6
	else:
		result = 7
	return result

func _speed_to_description(level: int) -> String:
	match level:
		1: return tr('0.25x')
		2: return tr('0.5x')
		3: return tr('1x')
		4: return tr('1.5x')
		5: return tr('2x')
		6: return tr('4x')
		7: return tr('10x')
		_: Utils.ensure(false); return tr('???')

func _delay_to_multiplier(level: int) -> float:
	match level:
		1: return 10.0
		2: return 2.0
		3: return 1.0
		4: return 0.5
		5: return 0.25
		_: Utils.ensure(false); return 1.0

func _multiplier_to_delay(multiplier: float) -> int:
	var result: int
	if multiplier <= 0.3:
		result = 5
	elif multiplier <= 0.9:
		result = 4
	elif multiplier <= 1.5:
		result = 3
	elif multiplier <= 3:
		result = 2
	else:
		result = 1
	return result

func _delay_to_description(level: int) -> String:
	match level:
		1: return tr('0.1x')
		2: return tr('0.5x')
		3: return tr('1x')
		4: return tr('2x')
		5: return tr('4x')
		_: Utils.ensure(false); return tr('???')

func _on_tab_button_interface_pressed() -> void:
	(%VBox_Interface as Control).visible = true
	(%VBox_Audio as Control).visible = false
	(%VBox_Video as Control).visible = false
	(%VBox_Controls as Control).visible = false
	(%VBox_Japanese as Control).visible = false
	GlobalAudioSystem.is_in_audio_settings = false

func _on_tab_button_video_pressed() -> void:
	(%VBox_Interface as Control).visible = false
	(%VBox_Audio as Control).visible = false
	(%VBox_Video as Control).visible = true
	(%VBox_Controls as Control).visible = false
	(%VBox_Japanese as Control).visible = false
	GlobalAudioSystem.is_in_audio_settings = false

func _on_tab_button_audio_pressed() -> void:
	(%VBox_Interface as Control).visible = false
	(%VBox_Audio as Control).visible = true
	(%VBox_Video as Control).visible = false
	(%VBox_Controls as Control).visible = false
	(%VBox_Japanese as Control).visible = false
	GlobalAudioSystem.is_in_audio_settings = true

func _on_tab_button_controls_pressed() -> void:
	(%VBox_Interface as Control).visible = false
	(%VBox_Audio as Control).visible = false
	(%VBox_Video as Control).visible = false
	(%VBox_Controls as Control).visible = true
	(%VBox_Japanese as Control).visible = false
	GlobalAudioSystem.is_in_audio_settings = false

func _on_tab_button_japanese_pressed() -> void:
	(%VBox_Interface as Control).visible = false
	(%VBox_Audio as Control).visible = false
	(%VBox_Video as Control).visible = false
	(%VBox_Controls as Control).visible = false
	(%VBox_Japanese as Control).visible = true
	GlobalAudioSystem.is_in_audio_settings = false

func _on_accessible_icons_changed(_button: BaseButton) -> void:
	if (%Button_Icons_Normal as Button).button_pressed:
		GameSettings.Interface.aspect_icons.set_value(GameSettings.AspectIconStyle.CLASSIC)
	elif (%Button_Icons_Accessible as Button).button_pressed:
		GameSettings.Interface.aspect_icons.set_value(GameSettings.AspectIconStyle.ACCESSIBLE)
	elif (%Button_Icons_SuperAccessible as Button).button_pressed:
		GameSettings.Interface.aspect_icons.set_value(GameSettings.AspectIconStyle.SUPER_ACCESSIBLE)
	else:
		Utils.ensure(false)

func _on_button_always_show_card_name_pressed() -> void:
	var show_card_names := (%Button_AlwaysShowCardName as Button).button_pressed
	GameSettings.Interface.show_card_names.set_value(show_card_names, true)
	(%Button_AlwaysShowCardName as Button).text = tr('ON') if show_card_names else tr('OFF')

func _on_button_reset_controls_pressed() -> void:
	GlobalGameSettings.reset_controls()
	for binding: ControlBindingSetting in %ControlsList.get_children():
		GameSettings.Controls.set_binding(binding.action_name, Key.KEY_NONE)
		binding.update()
	GlobalGameSettings.save()

func _on_dropdown_card_names_selected(item: DropdownItem) -> void:
	var shard_names_display := item.value as GameSettings.CardNameDisplayType
	GameSettings.Japanese.card_names.set_value(shard_names_display)

func _on_dropdown_settlement_names_selected(item: DropdownItem) -> void:
	var town_names_display := item.value as GameSettings.TownNameDisplayType
	GameSettings.Japanese.town_names.set_value(town_names_display)

func _on_dropdown_shard_names_selected(item: DropdownItem) -> void:
	var shard_names_display := item.value as GameSettings.ShardNameDisplayType
	GameSettings.Japanese.shard_names.set_value(shard_names_display)

func _on_dropdown_haunting_names_selected(item: DropdownItem) -> void:
	var haunting_names_display := item.value as GameSettings.HauntingNameDisplayType
	GameSettings.Japanese.haunting_names.set_value(haunting_names_display)

func _on_button_embed_japanese_pressed() -> void:
	var embed_jp := (%Button_EmbedJapanese as Button).button_pressed
	GameSettings.Japanese.embed_jp.set_value(embed_jp)
	(%Button_EmbedJapanese as Button).text = tr('ON') if embed_jp else tr('OFF')

func _on_dropdown_dictionary_selected(item: DropdownItem) -> void:
	var dictionary_mode := item.value as GameSettings.DictionaryMode
	GameSettings.Japanese.dictionary_mode.set_value(dictionary_mode)

func _on_button_romaji_furgana_pressed() -> void:
	var romaji_furigana := (%Button_RomajiFurgana as Button).button_pressed
	GameSettings.Japanese.romaji_furigana.set_value(romaji_furigana)
	(%Button_RomajiFurgana as Button).text = tr('ON') if romaji_furigana else tr('OFF')

func _on_button_use_drawn_kanji_pressed() -> void:
	var use_drawn_kanji := (%Button_UseDrawnKanji as Button).button_pressed
	GameSettings.Japanese.use_drawn_kanji.set_value(use_drawn_kanji)
	(%Button_UseDrawnKanji as Button).text = tr('ON') if use_drawn_kanji else tr('OFF')

func _on_button_mute_unfocused_pressed() -> void:
	var mute_unfocused := (%Button_MuteUnfocused as Button).button_pressed
	GameSettings.Audio.mute_unfocused.set_value(mute_unfocused)
	(%Button_MuteUnfocused as Button).text = tr('ON') if mute_unfocused else tr('OFF')

func _on_button_skip_claimed_music_pressed() -> void:
	var skip_claimed_music := (%Button_SkipClaimedMusic as Button).button_pressed
	GameSettings.Audio.skip_claimed_music.set_value(skip_claimed_music)
	(%Button_SkipClaimedMusic as Button).text = tr('ON') if skip_claimed_music else tr('OFF')
	if Utils.get_active_run():
		GlobalAudioSystem.switch_music(AK.SWITCHES.MUSIC.SWITCH.GAMEPLAY_STREAMER)
	elif Utils.get_active_hub():
		Utils.get_active_hub()._switch_to_hub_music()

func _on_reset_audio_button_pressed() -> void:
	(%Slider_MasterVolume as Slider).set_value(GameSettings.Audio.master_volume.get_default())
	(%Slider_MusicVolume as Slider).set_value(GameSettings.Audio.music_volume.get_default())
	(%Slider_AmbienceVolume as Slider).set_value(GameSettings.Audio.ambience_volume.get_default())
	(%Slider_EffectsVolume as Slider).set_value(GameSettings.Audio.effects_volume.get_default())
	(%Slider_VoiceVolume as Slider).set_value(GameSettings.Audio.voice_volume.get_default())
	(%Button_MuteUnfocused as Button).button_pressed = GameSettings.Audio.mute_unfocused.get_default()
	_on_button_mute_unfocused_pressed()
	(%Button_SkipClaimedMusic as Button).button_pressed = GameSettings.Audio.skip_claimed_music.get_default()
	_on_button_skip_claimed_music_pressed()

func _on_button_show_pause_button_pressed() -> void:
	var show_pause_button := (%Button_ShowPauseButton as Button).button_pressed
	GameSettings.Interface.show_pause_button.set_value(show_pause_button)
	(%Button_ShowPauseButton as Button).text = tr('ON') if show_pause_button else tr('OFF')

func _on_dropdown_zoom_on_hover_selected(item: DropdownItem) -> void:
	var zoom_on_hover := item.value as UI.ZoomMode
	GameSettings.Interface.zoom_on_hover.set_value(zoom_on_hover)

func _on_button_show_settlement_border_pressed() -> void:
	var show_settlement_border := (%Button_ShowSettlementBorder as Button).button_pressed
	GameSettings.Interface.show_settlement_border.set_value(show_settlement_border)
	(%Button_ShowSettlementBorder as Button).text = tr('ON') if show_settlement_border else tr('OFF')

func _on_button_show_stage_bonuses_pressed() -> void:
	var show_stage_bonuses := (%Button_ShowStageBonuses as Button).button_pressed
	GameSettings.Interface.show_stage_bonuses.set_value(show_stage_bonuses)
	(%Button_ShowStageBonuses as Button).text = tr('ON') if show_stage_bonuses else tr('OFF')

func _on_button_sort_predicted_yields_pressed() -> void:
	var sort_predicted_yields := (%Button_SortPredictedYields as Button).button_pressed
	GameSettings.Interface.sort_predicted_yields.set_value(sort_predicted_yields)
	(%Button_SortPredictedYields as Button).text = tr('ON') if sort_predicted_yields else tr('OFF')

func _on_button_vary_roof_color_pressed() -> void:
	var vary_roof_color := (%Button_VaryRoofColor as Button).button_pressed
	GameSettings.Interface.vary_roof_color.set_value(vary_roof_color)
	(%Button_VaryRoofColor as Button).text = tr('ON') if vary_roof_color else tr('OFF')

func _on_button_show_version_watermark_pressed() -> void:
	var show_version_watermark := (%Button_ShowVersionWatermark as Button).button_pressed
	GameSettings.Interface.show_version_watermark.set_value(show_version_watermark)
	(%Button_ShowVersionWatermark as Button).text = tr('ON') if show_version_watermark else tr('OFF')

func _on_button_kanji_practice_pressed() -> void:
	var practice_enabled := (%Button_KanjiPractice as Button).button_pressed
	GameSettings.Japanese.practice_enabled.set_value(practice_enabled)
	(%Button_KanjiPractice as Button).text = tr('ON') if practice_enabled else tr('OFF')

func _on_button_kanji_drawing_pressed() -> void:
	var kanji_drawing_enabled := (%Button_KanjiDrawing as Button).button_pressed
	GameSettings.Japanese.kanji_drawing_enabled.set_value(kanji_drawing_enabled)
	(%Button_KanjiDrawing as Button).text = tr('ON') if kanji_drawing_enabled else tr('OFF')
	(%HBox_UseDrawnKanji as Control).modulate.a = 1.0 if kanji_drawing_enabled else 0.5
	(%HBox_UseDrawnKanji as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if kanji_drawing_enabled else Control.MOUSE_BEHAVIOR_DISABLED

func _setup_tooltip(node: Node, text: String) -> void:
	if not Utils.ensure(node is Control):
		return
	GlobalTooltipSystem.attach(node as Control, func() -> String:
		return text
	, [Tooltip.RelativeDirection.LEFT], [Tooltip.Alignment.CENTERED, Tooltip.Alignment.BEGIN])

func _on_dropdown_locale_selected(item: DropdownItem) -> void:
	var chosen_locale := item.value as String
	GameSettings.Interface.locale.set_value(chosen_locale)
	if chosen_locale:
		var available_translations := GameSettings.get_translatable_locales()
		if chosen_locale in available_translations:
			var t := ResourceLoader.load(available_translations[chosen_locale], '', ResourceLoader.CACHE_MODE_IGNORE) as Translation
			t.locale = chosen_locale
			TranslationServer.clear()
			TranslationServer.add_translation(t)
			TranslationServer.set_locale(t.locale)
		else:
			push_warning('Translation for chosen locale "%s" not found.' % chosen_locale)
	else:
		TranslationServer.set_locale('en')
