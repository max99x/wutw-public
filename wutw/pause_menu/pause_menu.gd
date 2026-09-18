class_name PauseMenu
extends Node2D

signal closed

const FORAY_STATES := [
	RunData.State.STAGE,
	RunData.State.STAGE_END,
	RunData.State.STAGE_CARD_REWARD,
]
const SURVEY_STATES := [
	RunData.State.SURVEY,
	RunData.State.SURVEY_END,
]
const HARMONIZATION_STATES := [
	RunData.State.HARMONIZATION,
	RunData.State.HARMONIZATION_END,
	RunData.State.SEASON_END,
]
const END_STATES := [
	RunData.State.RUN_WON,
	RunData.State.RUN_LOST,
]
const CUTSCENE_STATES := [
	Main.State.CUTSCENE_INTRO,
	Main.State.CUTSCENE_1_TO_2,
	Main.State.CUTSCENE_2_TO_3,
	Main.State.CUTSCENE_3_TO_4,
	Main.State.CUTSCENE_OUTRO,
]

const STEAM_URL := 'https://store.steampowered.com/app/3640430/Worlds_Upon_The_Wind/'

static var RELIC_ICON_SCENE := AsyncLoadedResource.new('res://relics/selector/relic_icon.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var DECK_VIEWER_SCENE := AsyncLoadedResource.new('res://cards/viewer/card_deck_viewer.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var SETTINGS_DIALOG_SCENE := AsyncLoadedResource.new('res://settings/settings_dialog.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var LIKELY_SHARD_TYPES_LIST_SCENE := AsyncLoadedResource.new('res://shard_types/likely_shard_types_list.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var MUSEUM_BROWSER_SCENE := AsyncLoadedResource.new('res://hub/museum/museum_browser.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var BUG_REPORTER_SCENE := AsyncLoadedResource.new('res://utils/bug_reporter/bug_reporter.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)
static var STATS_DIALOG_SCENE := AsyncLoadedResource.new('res://pause_menu/stats_dialog.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)
static var CRAFTING_SCENE := AsyncLoadedResource.new('res://hub/crafting/crafting.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)

var _closing := false

func _ready() -> void:
	Utils.clear_node(%RelicList)

	var run := Utils.get_active_run()
	if run:
		(%StagePanel as Control).visible = true
		(%StageLabel as Label).text = _get_stage_title()
		var relics := run.get_current_relics()
		var too_many_relics := relics.size() > 9
		(%RelicList as GridContainer).columns = 4 if too_many_relics else 3
		for relic in relics:
			var relic_icon: RelicIcon = RELIC_ICON_SCENE.instantiate_loaded_scene()
			relic_icon.relic = relic
			relic_icon.forced_size = 80 if too_many_relics else 128
			%RelicList.add_child(relic_icon)
		(%InsightsLabel as Label).text = str(run.get_total_insights_gained())
		(%AspectCountersPanel as AspectCountersPanel).card_types = run.get_deck_cards()
		(%ViewDeckButton as Button).text = tr('View Glyph Deck (%d)') % run.get_deck_cards().size()

		(%BackToHubButton as Control).visible = (
			GlobalSaveGame.get_main_quest_progress() >= SaveGame.MainQuestProgress.P110_COMPLETED_TUTORIAL
			and run.get_state() not in END_STATES)
		if run.get_current_event_scene():
			(%BackToHubButton as Button).disabled = true
			GlobalTooltipSystem.attach(%BackToHubButton as Button, func() -> String:
				return tr('Cannot finish the expedition while an event is in progress.')
			, [Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

		if GlobalSaveGame.get_main_quest_progress() < SaveGame.MainQuestProgress.P110_COMPLETED_TUTORIAL:
			(%RetryButton as Button).visible = false
		elif run.get_state() in FORAY_STATES:
			(%RetryButton as Button).visible = true
			(%RetryButton as Button).text = tr('Retry Foray')
		elif run.get_state() in SURVEY_STATES:
			(%RetryButton as Button).visible = true
			(%RetryButton as Button).text = tr('Retry Survey')
		elif run.get_state() in HARMONIZATION_STATES:
			(%RetryButton as Button).visible = true
			(%RetryButton as Button).text = tr('Retry Convergence')
		else:
			(%RetryButton as Button).visible = false

		(%SkipButton as Control).visible = false
		(%ViewCardsListButton as Button).visible = Skill.get_skill_var(Skill.Var.SIGNATURE_CARDS) > 0
		(%ViewShardTypesButton as Button).visible = Utils.are_shard_types_unlocked()
		(%ViewMuseumButton as Button).visible = Utils.is_museum_unlocked()
	else:
		(%SkipButton as Control).visible = GlobalUI.get_layer(UI.Layer.CUTSCENE).get_child_count() > 0
		(%StagePanel as Control).visible = false
		(%BackToHubButton as Button).visible = false
		(%RetryButton as Button).visible = false
		for child: Control in %LeftColumn.get_children():
			child.visible = false
		(%ViewCardsListButton as Button).visible = false
		(%ViewShardTypesButton as Button).visible = false
		(%ViewMuseumButton as Button).visible = false

	var tween := create_tween()
	(%MainContainer as Control).modulate.a = 0
	tween.tween_property(%MainContainer, 'modulate:a', 1.0, (%BG as FadedBackground).default_duration)
	tween.play()

	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)

	(%CTAs as Control).visible = Utils.is_demo()

func _handle_esc() -> bool:
	close()
	return true

func close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%MainContainer as Control, false)
		var tween := create_tween()
		tween.tween_property(%MainContainer, 'modulate:a', 0.0, (%BG as FadedBackground).default_duration)
		tween.play()
		await (%BG as FadedBackground).fade_out()
		closed.emit()
		queue_free()

func _update_font_size() -> void:
	var font_size := roundi(16 * GameSettings.Interface.paragraph_font_scale.value())
	(%InsightsHintLabel as Label).add_theme_font_size_override('font_size', font_size)
	(%InsightsLabel as Label).add_theme_font_size_override('font_size', font_size)

func _on_resume_button_pressed() -> void:
	close()

func _on_back_to_hub_button_pressed() -> void:
	var prompt := tr('Are you sure you want to finish this expedition?') + '\n\n'
	var run := Utils.get_active_run()
	var insights := run.get_total_insights_gained()
	insights += run.get_insights_from_discoveries()

	var bonus_insights := run.scaling.get_early_exit_insights_bonus(insights)
	if bonus_insights:
		var penalized := run.get_state() in FORAY_STATES or run.get_state() in HARMONIZATION_STATES
		var base_insights_label := tr_n('%d insight', '%d insights', insights) % insights
		var bonus_insights_label := tr_n('%d insight', '%d insights', bonus_insights) % bonus_insights
		if penalized:
			if run.get_state() in FORAY_STATES:
				prompt += tr('You will keep %s but forfeit %s because you are currently in a foray.') % [
					base_insights_label, bonus_insights_label]
			else:
				prompt += tr('You will keep %s but forfeit %s because you are currently in a convergence.') % [
					base_insights_label, bonus_insights_label]
		else:
			prompt += tr('You will gain %s in addition to the %s you earned for returning before inspiration is exhausted.') % [
				bonus_insights_label, bonus_insights_label]

	GlobalUI.show_confirm(tr('Finish Expedition?'), prompt).confirmed.connect(func() -> void:
		if run.get_state() in FORAY_STATES or run.get_state() in HARMONIZATION_STATES:
			Utils.get_active_run().set_state(RunData.State.RUN_LOST)
		else:
			Utils.get_active_run().set_state(RunData.State.RUN_WON)
		close()
	)

func _on_quit_button_pressed() -> void:
	var last_save_timestamp := GlobalSaveGame.get_last_saved_timestamp()
	var last_save_time: String
	if last_save_timestamp == -1:
		last_save_time = tr('The game is not saved before the end of the tutorial.')
	else:
		last_save_time = tr('Last saved: ') + Utils.describe_relative_time(last_save_timestamp)
	var prompt := tr('Are you sure you want to exit the game?') + '\n\n' + last_save_time
	var confirm := GlobalUI.show_confirm(
		tr('Exit Game?'), prompt, tr('Quit'), tr('Cancel'), tr('Return to Main Menu'))
	confirm.confirmed.connect(get_tree().quit)
	confirm.extra_selected.connect(GlobalUI.return_to_main_menu_requested.emit)

func _get_stage_title() -> String:
	var run := Utils.get_active_run()
	var season_number := run.get_current_season_index() + 1
	var season_stage_index := (run.get_current_stage_index() % run.scaling.stages_per_season) + 1
	var season_prefix := '' if run.scaling.stages_per_season >= 100 else (tr('Phase %d - ') % season_number)
	match run.get_state():
		RunData.State.SEASON_START:
			return season_prefix + tr('Start')
		RunData.State.STAGE_SELECTOR:
			return season_prefix + tr('Foray %d Location Choice') % season_stage_index
		RunData.State.STAGE:
			return season_prefix + tr('Foray %d') % season_stage_index
		RunData.State.STAGE_END, RunData.State.STAGE_CARD_REWARD:
			return season_prefix + tr('Foray %d Results') % season_stage_index
		RunData.State.CAPITAL_PLACEMENT:
			return tr('Capital Planning')
		RunData.State.HARMONIZATION:
			return season_prefix + tr('Convergence')
		RunData.State.HARMONIZATION_END:
			return season_prefix + tr('Convergence Results')
		RunData.State.SEASON_END:
			return season_prefix + tr('End')
		RunData.State.RUN_LOST:
			return tr('Expedition End (Premature)')
		RunData.State.RUN_WON:
			return tr('Expedition End')
		RunData.State.STARTER_TUTORIAL:
			return season_prefix + tr('Tutorial')
		RunData.State.SURVEY_SELECTOR:
			return season_prefix + tr('Survey Planning')
		RunData.State.SURVEY:
			return season_prefix + tr('Survey')
		RunData.State.SURVEY_END:
			return season_prefix + tr('Survey Results')
		_:
			push_error('Unrecognized run state in pause menu: ' + str(run.get_state()))
			return ''

func _on_view_deck_button_pressed() -> void:
	var viewer := DECK_VIEWER_SCENE.instantiate_loaded_scene() as CardDeckViewer
	viewer.cards = Utils.get_active_run().get_deck_cards().duplicate()
	viewer.cards.sort_custom(CardType.compare)
	GlobalUI.add_layer_content(viewer, UI.Layer.PAUSE_MENU_SUBMENU)

func _on_retry_button_pressed() -> void:
	GlobalTutorialSystem.get_tutorial(Tutorial_Retry).mark_skipped()
	var run := Utils.get_active_run()
	run.reload_requested.emit()

func _on_settings_button_pressed() -> void:
	var settings_dialog := SETTINGS_DIALOG_SCENE.instantiate_loaded_scene() as SettingsDialog
	GlobalUI.add_layer_content(settings_dialog, UI.Layer.PAUSE_MENU_SUBMENU)

func _on_skip_button_pressed() -> void:
	var scene := GlobalUI.get_layer(UI.Layer.CUTSCENE).get_child(0)
	assert(scene is Cutscene_Slideshow)
	(scene as Cutscene_Slideshow).skip_cutscene()
	close()

func _on_bug_report_button_pressed() -> void:
	var bug_reporter := BUG_REPORTER_SCENE.instantiate_loaded_scene() as BugReporter
	GlobalUI.add_layer_content(bug_reporter, UI.Layer.MODAL)

func _on_view_shard_types_button_pressed() -> void:
	var list := LIKELY_SHARD_TYPES_LIST_SCENE.instantiate_loaded_scene() as LikelyShardTypesList
	GlobalUI.add_layer_content(list, UI.Layer.PAUSE_MENU_SUBMENU)

func _on_view_museum_button_pressed() -> void:
	var browser := MUSEUM_BROWSER_SCENE.instantiate_loaded_scene() as MuseumBrowser
	GlobalUI.add_layer_content(browser, UI.Layer.PAUSE_MENU_SUBMENU)

func _on_view_stats_button_pressed() -> void:
	var dialog := STATS_DIALOG_SCENE.instantiate_loaded_scene() as StatsDialog
	GlobalUI.add_layer_content(dialog, UI.Layer.PAUSE_MENU_SUBMENU)

func _on_discord_button_pressed() -> void:
	OS.shell_open(DiscordButton.DISCORD_INVITE_URL)

func _on_steam_button_pressed() -> void:
	OS.shell_open(STEAM_URL)

func _on_discord_button_mouse_entered() -> void:
	(%DiscordButton as Button).modulate = Color(1.5, 1.5, 1.5)

func _on_discord_button_mouse_exited() -> void:
	(%DiscordButton as Button).modulate = Color.WHITE

func _on_steam_button_mouse_entered() -> void:
	(%SteamButton as Button).modulate = Color(1.5, 1.5, 1.5)

func _on_steam_button_mouse_exited() -> void:
	(%SteamButton as Button).modulate = Color.WHITE

func _on_relic_list_resized() -> void:
	(%RelicScroller as Control).custom_minimum_size.y = clampf((%RelicList as Control).size.y, 0, 260)

func _on_view_cards_list_button_pressed() -> void:
	var crafting := CRAFTING_SCENE.instantiate_loaded_scene() as Crafting
	crafting.preview_mode = true
	GlobalUI.add_layer_content(crafting, UI.Layer.PAUSE_MENU_SUBMENU)
