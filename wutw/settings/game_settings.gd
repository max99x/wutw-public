@tool
class_name GameSettings
extends Node

signal changed

enum CardNameDisplayType { MEANING, KUNYOMI, ONYOMI, KUNYOMI_ROMAJI, ONYOMI_ROMAJI }
enum TownNameDisplayType { ROMAJI, KANJI, HIRAGANA, MEANING }
enum ShardNameDisplayType { ROMAJI, KANJI, HIRAGANA, MEANING }
enum HauntingNameDisplayType { ROMAJI, KANJI, HIRAGANA, MEANING }
enum FuriganaMode { OFF, WHEL_SOLVED, ALWAYS }
enum AspectIconStyle { CLASSIC, ACCESSIBLE, SUPER_ACCESSIBLE }
enum DictionaryMode { NONE, KANA, ROMAJI, KANA_AND_ROMAJI }

# All the settings with their defaults, exposed as syntax sugar.
class Interface:
	static var tooltip_speed := FloatSetting.new('ui', 'tooltip_speed', 1.0)
	static var animation_speed := FloatSetting.new('ui', 'animation_speed', 1.0)
	static var aspect_icons := IntSetting.new('ui', 'aspect_icons', AspectIconStyle.ACCESSIBLE)
	static var show_card_names := BoolSetting.new('ui', 'show_card_names', true)
	static var show_pause_button := BoolSetting.new('ui', 'show_pause_button', false)
	static var vary_roof_color := BoolSetting.new('ui', 'vary_roof_color', true)
	static var show_settlement_border := BoolSetting.new('ui', 'show_settlement_border', true)
	static var zoom_on_hover := IntSetting.new('ui', 'zoom_on_hover', UI.ZoomMode.DISABLED)
	static var tooltip_font_scale := FloatSetting.new('ui', 'tooltip_font_scale', 1.0)
	static var paragraph_font_scale := FloatSetting.new('ui', 'paragraph_font_scale', 1.0)
	static var show_stage_bonuses := BoolSetting.new('ui', 'show_stage_bonuses', false)
	static var sort_predicted_yields := BoolSetting.new('ui', 'sort_predicted_yields', true)
	static var show_version_watermark := BoolSetting.new('ui', 'show_version_watermark', true)
	# Not configurable unless we find a reason for it to be.
	static var show_harmonization_haunting_preview := BoolSetting.new('ui', 'show_harmonization_haunting_preview', true)
	# Deprecated
	static var _deprecated_accessible_aspect_icons := BoolSetting.new('ui', 'accessible_aspect_icons', true)
class FirstRun:
	static var demo_end_seen := BoolSetting.new('first_run', 'demo_end_seen', false)
	static var ever_run := BoolSetting.new('first_run', 'ever_run', false)
	static var steam_deck_welcomed := BoolSetting.new('first_run', 'steam_deck_wlecomed', false)
class Display:
	static var window_mode := IntSetting.new('display', 'window_mode', DisplayServer.window_get_mode())
	static var vsync := IntSetting.new('display', 'vsync', DisplayServer.window_get_vsync_mode())
	static var fps_cap := IntSetting.new('display', 'fps_cap', 59)
	static var clouds_on_map := BoolSetting.new('display', 'clouds_on_map', true)
	static var animate_sprite_changes := BoolSetting.new('display', 'animate_sprite_changes', true)
	static var enable_map_effects := BoolSetting.new('display', 'enable_map_effects', true)
class Audio:
	static var master_volume := FloatSetting.new('audio', 'master_volume', 0.75)
	static var music_volume := FloatSetting.new('audio', 'music_volume', 0.75)
	static var ambience_volume := FloatSetting.new('audio', 'ambience_volume', 0.75)
	static var effects_volume := FloatSetting.new('audio', 'effects_volume', 0.75)
	static var ui_volume := FloatSetting.new('audio', 'ui_volume', 0.75)
	static var voice_volume := FloatSetting.new('audio', 'voice_volume', 0.75)
	static var skip_claimed_music := BoolSetting.new('audio', 'skip_claimed_music', false)
	static var mute_unfocused := BoolSetting.new('audio', 'mute_unfocused', false)
class Japanese:
	static var card_names := IntSetting.new('japanese', 'card_names', CardNameDisplayType.MEANING)
	static var town_names := IntSetting.new('japanese', 'town_names', TownNameDisplayType.ROMAJI)
	static var shard_names := IntSetting.new('japanese', 'shard_names', ShardNameDisplayType.ROMAJI)
	static var haunting_names := IntSetting.new('japanese', 'haunting_names', HauntingNameDisplayType.ROMAJI)
	static var dictionary_mode := IntSetting.new('japanese', 'dictionary_mode', DictionaryMode.NONE)
	static var embed_jp := BoolSetting.new('japanese', 'embed_jp', false)
	static var practice_enabled := BoolSetting.new('japanese', 'practice_enabled', false)
	static var kanji_drawing_enabled := BoolSetting.new('japanese', 'kanji_drawing_enabled', false)
	static var use_drawn_kanji := BoolSetting.new('japanese', 'use_drawn_kanji', true)
	static var romaji_furigana := BoolSetting.new('japanese', 'romaji_furigana', false)
	# Controlled from within practice minigame.
	static var kanji_practice_max_level := IntSetting.new('japanese', 'kanji_practice_max_level', 0)
	static var kanji_practice_lru_level := IntSetting.new('japanese', 'kanji_practice_lru_level', 0)
	static var kanji_practice_lru_level_cap := IntSetting.new('japanese', 'kanji_practice_lru_level_cap', 59)
	static var kanji_practice_lru_grade := IntSetting.new('japanese', 'kanji_practice_lru_grade', 999)
	static var kanji_practice_lru_jlpt := IntSetting.new('japanese', 'kanji_practice_lru_jlpt', 999)
	static var kanji_practice_furigana_mode := IntSetting.new('japanese', 'kanji_practice_furigana_mode', FuriganaMode.WHEL_SOLVED)
	# Deprecated
	static var _deprecated_show_dictionary_entries := BoolSetting.new('japanese', 'show_dictionary_entries', false)
	static var _deprecated_romaji_in_dictionary := BoolSetting.new('japanese', 'romaji_in_dictionary', false)
	static var _deprecated_minigames_enabled := BoolSetting.new('japanese', 'minigames_enabled', false) # DEPRECATED

class SkipTutorials:
	static func is_skipped(tutorial_id: String) -> bool:
		if Utils.is_in_editor():
			return Key.KEY_NONE
		return GlobalGameSettings.get_setting('skip_tutorials', tutorial_id, false) as bool
	static func set_skipped(tutorial_id: String, new_skipped: bool, autosave: bool = false) -> void:
		GlobalGameSettings.set_setting('skip_tutorials', tutorial_id, new_skipped, autosave)
	static func keys() -> Array[String]:
		return GlobalGameSettings.get_setting_keys('skip_tutorials')
class Controls:
	static func get_binding(action_name: String) -> Key:
		if Utils.is_in_editor():
			return Key.KEY_NONE
		return GlobalGameSettings.get_setting('controls', action_name, Key.KEY_NONE) as Key
	static func set_binding(action_name: String, key: Key, autosave: bool = false) -> void:
		if Utils.is_in_editor():
			return
		GlobalGameSettings.set_setting('controls', action_name, key as int, autosave)

const FILE_PATH := 'user://game_settings.ini'

var read_only: bool = false  # Used for debugging and dev tools.

var _config_file: ConfigFile
var _default_controls: Dictionary[String, Array]  # Array[InputEvent]

func _ready() -> void:
	if Utils.is_in_editor():
		return
	_config_file = ConfigFile.new()
	if _config_file.load(FILE_PATH) != OK:
		return

	for action_name in InputMap.get_actions():
		_default_controls[action_name] = InputMap.action_get_events(action_name).map(func(e: InputEvent) -> InputEvent:
			return e.duplicate(true)
		)
		var remapped_key := Controls.get_binding(action_name) as int
		if remapped_key:
			var config_input_event := InputMap.action_get_events(action_name)[0] as InputEventKey
			config_input_event.physical_keycode = (remapped_key & ~KEY_MODIFIER_MASK) as Key
			config_input_event.ctrl_pressed = remapped_key & KEY_MASK_CTRL
			config_input_event.alt_pressed = remapped_key & KEY_MASK_ALT
			config_input_event.shift_pressed = remapped_key & KEY_MASK_SHIFT
			config_input_event.meta_pressed = remapped_key & KEY_MASK_META

	# Backward-compatility.
	var need_save := false
	if Japanese._deprecated_minigames_enabled.value():
		Japanese.practice_enabled.set_value(true)
		Japanese.kanji_drawing_enabled.set_value(true)
		Japanese._deprecated_minigames_enabled.set_value(false)
		need_save = true
	if not Interface._deprecated_accessible_aspect_icons.value():
		Interface.aspect_icons.set_value(AspectIconStyle.CLASSIC)
		Interface._deprecated_accessible_aspect_icons.set_value(true)
		need_save = true
	if Japanese._deprecated_show_dictionary_entries.value():
		if Japanese._deprecated_romaji_in_dictionary.value():
			Japanese.dictionary_mode.set_value(DictionaryMode.ROMAJI)
		else:
			Japanese.dictionary_mode.set_value(DictionaryMode.KANA)
		Japanese._deprecated_show_dictionary_entries.set_value(false)
	if not FirstRun.ever_run.value():
		FirstRun.ever_run.set_value(true)
		need_save = true

	if need_save:
		save()

func set_setting(category: String, key: String, value: Variant, autosave: bool = false) -> void:
	_config_file.set_value(category, key, value)
	changed.emit()
	if autosave:
		save()

func get_setting(category: String, key: String, default: Variant = null) -> Variant:
	return _config_file.get_value(category, key, default)

func get_setting_keys(category: String) -> Array[String]:
	if not _config_file.has_section(category):
		return []
	var result: Array[String]
	result.assign(_config_file.get_section_keys(category))
	return result

func reset_controls() -> void:
	# In theory, InputMap.load_from_project_settings() should do this, but it seems broken?
	for action_name in _default_controls:
		InputMap.action_erase_events(action_name)
		for event: InputEvent in _default_controls[action_name]:
			InputMap.action_add_event(action_name, event)

func save() -> void:
	if not read_only:
		_config_file.save(FILE_PATH)

# Syntax sugar helpers.

class FloatSetting extends RefCounted:
	var _category: String
	var _key: String
	var _default: float

	func _init(category: String, key: String, default: float) -> void:
		_category = category
		_key = key
		_default = default

	func value() -> float:
		if Utils.is_in_editor():
			return _default
		return GlobalGameSettings.get_setting(_category, _key, _default) as float

	func set_value(new_value: float, autosave: bool = false) -> void:
		if Utils.is_in_editor():
			return
		GlobalGameSettings.set_setting(_category, _key, new_value, autosave)

	func get_default() -> float:
		return _default

class IntSetting extends RefCounted:
	var _category: String
	var _key: String
	var _default: int

	func _init(category: String, key: String, default: int) -> void:
		_category = category
		_key = key
		_default = default

	func value() -> int:
		if Utils.is_in_editor():
			return _default
		return GlobalGameSettings.get_setting(_category, _key, _default) as int

	func set_value(new_value: int, autosave: bool = false) -> void:
		if Utils.is_in_editor():
			return
		GlobalGameSettings.set_setting(_category, _key, new_value, autosave)

	func get_default() -> int:
		return _default

class BoolSetting extends RefCounted:
	var _category: String
	var _key: String
	var _default: bool

	func _init(category: String, key: String, default: bool) -> void:
		_category = category
		_key = key
		_default = default

	func value() -> bool:
		if Utils.is_in_editor():
			return _default
		return GlobalGameSettings.get_setting(_category, _key, _default) as bool

	func set_value(new_value: bool, autosave: bool = false) -> void:
		if Utils.is_in_editor():
			return
		GlobalGameSettings.set_setting(_category, _key, new_value, autosave)

	func get_default() -> bool:
		return _default
