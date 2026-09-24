class_name RunEnd
extends Node2D

signal finished

static var DECK_VIEWER_SCENE := AsyncLoadedResource.new('res://cards/viewer/card_deck_viewer.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var RELIC_ICON_SCENE := AsyncLoadedResource.new('res://relics/selector/relic_icon.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var RELIC_CHOICE_SCENE := AsyncLoadedResource.new('res://relics/selector/relic_choice.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var DISCOVERY_EVENT_SCENE := AsyncLoadedResource.new('res://run/run_end/discovery_event.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var DISCOVERY_SURVEY_EPISODE_SCENE := AsyncLoadedResource.new('res://run/run_end/discovery_survey_episode.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var DISCOVERY_HAUNTING_SCENE := AsyncLoadedResource.new('res://run/run_end/discovery_haunting.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var DISCOVERY_SHOP_SCENE := AsyncLoadedResource.new('res://run/run_end/discovery_shop.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var DISCOVERY_UPGRADE_SCENE := AsyncLoadedResource.new('res://run/run_end/discovery_upgrade.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var CARD_SCENE := AsyncLoadedResource.new('res://cards/card.tscn')
static var SHARD_NAMES := AsyncLoadedResource.new('res://shard_types/shard_names.tres', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)

var won: bool = false

var _past_run: PastRun
var _should_warn_about_kept_card := false

func _ready() -> void:
	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)

	if GlobalSaveGame.get_main_quest_progress() < SaveGame.MainQuestProgress.P110_COMPLETED_TUTORIAL:
		won = true  # No penalty during tutorial.

	var run := Utils.get_active_run()

	# Reached
	var season_stage_index := (run.get_current_stage_index() % run.scaling.stages_per_season) + 1
	@warning_ignore('integer_division')  # intentional
	var season_index_by_stage := run.get_current_stage_index() / run.scaling.stages_per_season
	var foray_text: String
	if season_index_by_stage == run.get_current_season_index():
		foray_text = tr('Foray %d') % season_stage_index
	else:
		foray_text = tr('Convergence')
	(%ReachedLabel as Label).text = tr('Phase %d - %s') % [run.get_current_season_index() + 1, foray_text]

	# Insights
	var granted_insights := _get_granted_insights()
	(%InsightsLabel as Label).text = str(granted_insights)
	if granted_insights > run.get_total_insights_gained():  # Got a bonus.
		(%InsightsLabel as Label).text += '*'
	GlobalTooltipSystem.attach(%HBox_Insights as Control, _make_insights_tooltip_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.BEGIN])

	# Cards
	(%AspectCountersPanel as AspectCountersPanel).card_types = run.get_deck_cards()

	# Companion
	if run.run_config.companion:
		(%CompanionIcon as TextureRect).visible = true
		(%CompanionIcon as TextureRect).texture = run.run_config.companion.image
		GlobalTooltipSystem.attach(%CompanionIcon as Control, _make_companion_tooltip_text,
				[Tooltip.RelativeDirection.ABOVE], [Tooltip.Alignment.CENTERED])
	else:
		(%CompanionIcon as TextureRect).visible = false

	# Relics
	Utils.clear_node(%RelicsList)
	for relic in run.get_current_relics():
		var relic_icon: RelicIcon = RELIC_ICON_SCENE.instantiate_loaded_scene()
		relic_icon.relic = relic
		relic_icon.forced_size = 80
		%RelicsList.add_child(relic_icon)

	# Bonuses
	for bonus_counter: BonusCounter in %BasicBonuses.get_children() + %AdvancedBonuses.get_children():
		bonus_counter.current_value = run.get_bonus_amounts().get_amount(bonus_counter.bonus_type)

	# Discoveries.
	(%TabButton_Cards as Button).disabled = run.get_run_data().newly_seen_cards.is_empty()
	(%TabButton_Relics as Button).disabled = run.get_run_data().newly_seen_relics.is_empty()
	(%TabButton_Events as Button).disabled = run.get_run_data().newly_seen_event_outcomes.is_empty()
	(%TabButton_Shops as Button).disabled = run.get_run_data().newly_seen_shops.is_empty()
	(%TabButton_Upgrades as Button).disabled = run.get_run_data().newly_seen_upgrades.is_empty()
	(%TabButton_Surveys as Button).visible = Utils.are_surveys_unlocked()
	(%TabButton_Surveys as Button).disabled = run.get_run_data().newly_seen_survey_outcomes.is_empty()
	(%TabButton_Hauntings as Button).visible = Utils.are_hauntings_unlocked()
	if Utils.is_realistic_era():
		(%TabButton_Hauntings as Button).text = tr('Challenges')
	(%TabButton_Hauntings as Button).disabled = run.get_run_data().newly_seen_hauntings.is_empty()
	var any_discoveries := false
	for button: Button in %TabBar.get_children():
		if not button.disabled:
			button.button_pressed = true
			any_discoveries = true
			break
	if any_discoveries:
		(%DiscoveriesLabel as Label).visible = true
		(%DiscoveriesPanel as Control).visible = true
		(%NoDiscoveriesLabel as Label).visible = false
		(%VBox_Main as Control).custom_minimum_size.y = 730
	else:
		(%DiscoveriesLabel as Label).visible = false
		(%DiscoveriesPanel as Control).visible = false
		(%NoDiscoveriesLabel as Label).visible = true
		(%VBox_Main as Control).custom_minimum_size.y = 500

	# Manage inherited card.
	var inherit_button := %InheritButton as Button
	if Skill.get_skill_var(Skill.Var.INHERIT_CARD):
		inherit_button.visible = true
		if _get_inheritable_cards():
			_should_warn_about_kept_card = true
		else:
			inherit_button.disabled = true
			GlobalTooltipSystem.attach(inherit_button, _make_no_inheritable_card_tooltip_text,
					[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])
		GlobalSaveGame.set_inherited_card(null)
	else:
		inherit_button.visible = false

	# Prepare for animation.
	Utils.set_input_enabled(%DiscoveriesPanel as Control, false)
	Utils.set_input_enabled(%ContinueButton as Control, false)
	(%ScrollPanel as ScrollPanel).visible = false
	(%SkipButton as Button).visible = false
	(%ShardNameLabel as Control).visible = false
	(%ShardTypeLabel as Control).visible = false

	if run.get_run_data().settlement_states: # Don't save empty shards.
		# Create the PastRun, including assigning shard name and type.
		_past_run = PastRun.new()
		_past_run.uid = GlobalSaveGame.get_current_slot() * 10000 + 1 + GlobalSaveGame.get_past_run_ids().size()
		_past_run.run_data = run.get_run_data()
		_past_run.date_settled = GlobalSaveGame.get_current_date()
		var best_shard_type: ShardType
		var best_shard_type_score: float = -1
		for shard_type: ShardType in ShardType.get_all_shard_types().values():
			if GlobalSaveGame.is_shard_type_unlocked(shard_type):
				continue  # Already assigned.
			elif shard_type.min_main_quest_progress > GlobalSaveGame.get_main_quest_progress():
				continue  # Not yet accessible.
			var score := shard_type.score(run.get_run_data())
			if score >= 1 and GlobalSaveGame.get_pinned_shard_type() == shard_type:
				score = 100.0
			if score > best_shard_type_score:
				best_shard_type = shard_type
				best_shard_type_score = score
		if best_shard_type_score >= 1:
			_past_run.shard_type = best_shard_type
			_past_run.shard_name = best_shard_type.shard_name_override
			_past_run.shard_name_jp = best_shard_type.shard_name_override_jp
			_past_run.shard_name_meaning = best_shard_type.shard_name_override_meaning
		else:
			var shard_names := SHARD_NAMES.get_loaded() as ShardNameSet
			var shard_name_index := (GlobalSaveGame.get_playthrough_seed() + _past_run.uid) % shard_names.names.size()
			var shard_name_option := shard_names.names[shard_name_index]
			_past_run.shard_name = shard_name_option.name
			_past_run.shard_name_jp = shard_name_option.name_jp
			_past_run.shard_name_meaning = shard_name_option.meaning

		# Hide UI and take full shard screenshot.
		for settlement in run.get_settlements():
			settlement.mode = Settlement.Mode.SHOPPABLE  # Make sure radius indicators are hidden.
		var map := run.get_map()
		map.focus_location(map.generated_map.size / 2.0, 2.0, Utils.anim_duration(2.0))
		var hide_tween := create_tween()
		hide_tween.parallel().tween_property(run.get_top_hud(), 'modulate:a', 0.0, 2.1)
		hide_tween.parallel().tween_property(map.get_credits_icon(), 'modulate:a', 0.0, 2.1)
		hide_tween.parallel().tween_property(map.get_compass_icon(), 'modulate:a', 0.0, 2.1)
		hide_tween.parallel().tween_property(map.get_fow_layer(), 'modulate:a', 0.0, 2.1)
		hide_tween.tween_property(run.get_top_hud(), 'visible', false, 0.01)
		hide_tween.set_speed_scale(Utils.anim_speed())
		hide_tween.play()
		await hide_tween.finished
		await Utils.wait_with_timeout(map.is_camera_moving, 2.0)
		_past_run.screenshot = map.get_subviewport().get_texture().get_image()
		GlobalSaveGame.add_past_run(_past_run)

		# Set up font based on language.
		var name_label := %ShardNameLabel as Label
		if GameSettings.Japanese.shard_names.value() in [GameSettings.ShardNameDisplayType.ROMAJI, GameSettings.ShardNameDisplayType.MEANING]:
			name_label.label_settings.font = load('res://theme/fonts/Merienda/static/Merienda-Bold.ttf')
			name_label.label_settings.font_size = 60
		else:
			name_label.label_settings.font = load('res://theme/fonts/Yuji_Mai/YujiMai-Regular.ttf')
			name_label.label_settings.font_size = 62

		# Show name & type animation.
		name_label.text = _past_run.get_shard_display_name()
		var name_mat := name_label.material as ShaderMaterial
		name_mat.set_shader_parameter('reveal_progress', 0)
		var name_tween := create_tween()
		name_tween.tween_method(func(t: float) -> void:
			name_mat.set_shader_parameter('reveal_progress', t)
		, 0.0, 1.0, 2.0)
		name_tween.set_speed_scale(Utils.anim_speed())
		name_tween.play()
		(%ShardNameRevealFVX as GPUParticles2D).emitting = true
		(%ShardNameLabel as Control).visible = true
		name_mat.set_shader_parameter('width', name_label.size.x)
		GlobalAudioSystem.play(AK.EVENTS.SFX_MAP_EXPEDITION_FINISH_NAME)
		await name_tween.finished

		if _past_run.shard_type:
			await get_tree().create_timer(Utils.anim_duration(1.2)).timeout
			var type_label := %ShardTypeLabel as Label
			type_label.text = tr(_past_run.shard_type.name)
			var type_mat := type_label.material as ShaderMaterial
			type_mat.set_shader_parameter('reveal_progress', 0)
			var type_tween := create_tween()
			type_tween.tween_method(func(t: float) -> void:
				type_mat.set_shader_parameter('reveal_progress', t)
			, 0.0, 1.0, 2.0)
			type_tween.set_speed_scale(Utils.anim_speed())
			type_tween.play()
			(%ShardTypeRevealFVX as GPUParticles2D).emitting = true
			(%ShardTypeLabel as Control).visible = true
			type_mat.set_shader_parameter('width', type_label.size.x)
			GlobalAudioSystem.play(AK.EVENTS.SFX_MAP_EXPEDITION_FINISH_TITLE)
			await type_tween.finished

		if _past_run.shard_name_jp:  # Old savegames don't have JP names.
			GlobalTooltipSystem.attach(%ShardNameLabel as Control, _make_shard_name_tooltip_text,
					[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

	await get_tree().create_timer(Utils.anim_duration(2.0)).timeout

	(%ScrollPanel as ScrollPanel).visible = true
	(%SkipButton as Button).visible = true
	(%BG as FadedBackground).fade_in()
	(%ScrollPanel as ScrollPanel).animate_unroll()
	(%AnimationPlayer as AnimationPlayer).play('reveal', -1, Utils.anim_speed())
	await (%AnimationPlayer as AnimationPlayer).animation_finished
	(%SkipButton as Button).visible = false

	Utils.set_input_enabled(%DiscoveriesPanel as Control, true)
	Utils.set_input_enabled(%ContinueButton as Control, true)

func _enter_tree() -> void:
	UI.register_zoomable(%VBox_Bonuses as Control, 1.0, 0.5)

func _update_font_size() -> void:
	var font_size := roundi(16 * GameSettings.Interface.paragraph_font_scale.value())
	(%ReachedLabel as Label).add_theme_font_size_override('font_size', font_size)
	(%ViewDeckButton as Button).add_theme_font_size_override('font_size', font_size)
	(%TabButton_Cards as Button).add_theme_font_size_override('font_size', font_size)
	(%TabButton_Relics as Button).add_theme_font_size_override('font_size', font_size)
	(%TabButton_Upgrades as Button).add_theme_font_size_override('font_size', font_size)
	(%TabButton_Events as Button).add_theme_font_size_override('font_size', font_size)
	(%TabButton_Surveys as Button).add_theme_font_size_override('font_size', font_size)
	(%TabButton_Shops as Button).add_theme_font_size_override('font_size', font_size)
	(%TabButton_Hauntings as Button).add_theme_font_size_override('font_size', font_size)
	(%InheritButton as Button).add_theme_font_size_override('font_size', font_size)
	(%ContinueButton as Button).add_theme_font_size_override('font_size', font_size)

func _on_continue_button_pressed() -> void:
	if _should_warn_about_kept_card:
		_should_warn_about_kept_card = false
		var prompt := tr('You have not selected a glyph to keep.\n\nAre you sure you want to proceed?')
		await GlobalUI.show_confirm(tr('Skip Kept Glyph?'), prompt, tr('Yes'), tr('No')).confirmed

	GlobalSaveGame.insights += _get_granted_insights()
	# WARNING: Not saving now, because if we were to reload, we'd get the insights again. The hub will save on entry.
	Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)

	var map := Utils.get_active_run().get_map()
	var show_compass_tween := create_tween()
	show_compass_tween.parallel().tween_property(map.get_compass_icon(), 'modulate:a', 1.0, 1.0)
	show_compass_tween.set_speed_scale(Utils.anim_speed())
	show_compass_tween.play()

	await (%ScrollPanel as ScrollPanel).animate_roll()
	finished.emit()

func _on_view_deck_button_pressed() -> void:
	var viewer := DECK_VIEWER_SCENE.instantiate_loaded_scene() as CardDeckViewer
	viewer.title = tr('Final Deck')
	viewer.cards = Utils.get_active_run().get_deck_cards().duplicate()
	viewer.cards.sort_custom(CardType.compare)
	GlobalUI.add_layer_content(viewer, UI.Layer.STATE_MENU_SUBMENU)

func _get_granted_insights() -> int:
	var run := Utils.get_active_run()
	var insights := run.get_total_insights_gained()
	insights += run.get_insights_from_discoveries()
	if won:  # *After* the discoveries.
		insights += run.scaling.get_early_exit_insights_bonus(insights)
	return insights

func _on_tab_button_cards_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_fill_discoveries_cards()
		_unselect_other_tabs(%TabButton_Cards as Button)

func _unselect_other_tabs(selected_tab: Button) -> void:
	for button: Button in %TabBar.get_children():
		if button != selected_tab:
			button.button_pressed = false

func _fill_discoveries_cards() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%DiscoveriesList)
	for card_type in run.get_run_data().newly_seen_cards:
		var card := CARD_SCENE.instantiate_loaded_scene() as Card
		card.card_type = card_type
		card.selected.connect(func() -> void: card.is_selected = false)
		%DiscoveriesList.add_child(card)

func _on_tab_button_relics_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_fill_discoveries_relics()
		_unselect_other_tabs(%TabButton_Relics as Button)

func _fill_discoveries_relics() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%DiscoveriesList)
	for relic in run.get_run_data().newly_seen_relics:
		var relic_choice := RELIC_CHOICE_SCENE.instantiate_loaded_scene() as RelicChoice
		relic_choice.relic = relic
		relic_choice.interactive = false
		%DiscoveriesList.add_child(relic_choice)

func _on_tab_button_events_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_fill_discoveries_events()
		_unselect_other_tabs(%TabButton_Events as Button)

func _fill_discoveries_events() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%DiscoveriesList)
	for event in run.get_run_data().newly_seen_event_outcomes:
		if event.steps:
			var discovery := DISCOVERY_EVENT_SCENE.instantiate_loaded_scene() as Discovery_Event
			discovery.event = event
			%DiscoveriesList.add_child(discovery)

func _on_tab_button_surveys_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_fill_discoveries_survey_episodes()
		_unselect_other_tabs(%TabButton_Surveys as Button)

func _fill_discoveries_survey_episodes() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%DiscoveriesList)
	for episode in run.get_run_data().newly_seen_survey_outcomes:
		var discovery := DISCOVERY_SURVEY_EPISODE_SCENE.instantiate_loaded_scene() as Discovery_SurveyEpisode
		discovery.episode = episode
		%DiscoveriesList.add_child(discovery)

func _on_tab_button_shops_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_fill_discoveries_shops()
		_unselect_other_tabs(%TabButton_Shops as Button)

func _fill_discoveries_shops() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%DiscoveriesList)
	for shop_type in run.get_run_data().newly_seen_shops:
		var discovery := DISCOVERY_SHOP_SCENE.instantiate_loaded_scene() as Discovery_Shop
		discovery.shop_type = shop_type
		%DiscoveriesList.add_child(discovery)

func _on_tab_button_hauntings_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_fill_discoveries_hauntings()
		_unselect_other_tabs(%TabButton_Hauntings as Button)

func _fill_discoveries_hauntings() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%DiscoveriesList)
	for haunting_type in run.get_run_data().newly_seen_hauntings:
		var discovery := DISCOVERY_HAUNTING_SCENE.instantiate_loaded_scene() as Discovery_Haunting
		discovery.haunting_type = haunting_type
		%DiscoveriesList.add_child(discovery)

func _on_tab_button_upgrades_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_fill_discoveries_upgrades()
		_unselect_other_tabs(%TabButton_Upgrades as Button)

func _fill_discoveries_upgrades() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%DiscoveriesList)
	for spot_upgrade in run.get_run_data().newly_seen_upgrades:
		var discovery := DISCOVERY_UPGRADE_SCENE.instantiate_loaded_scene() as Discovery_Upgdrade
		discovery.spot_upgrade = spot_upgrade
		%DiscoveriesList.add_child(discovery)

func _make_insights_tooltip_text() -> String:
	var term := load('res://glossary/terms/standalone/term_insight.tres') as Term
	var text := '<header_font_size>[b]%s[/b][/font_size]' % term.get_term_name(true)
	text += '\n\n' + term.get_markedup_description()
	var run := Utils.get_active_run()
	var insights := run.get_total_insights_gained()
	var insights_from_discoveries := run.get_insights_from_discoveries()
	if insights_from_discoveries > 0:
		text += '\n\n'
		text += tr('* You received %d bonus insights from new discoveries.') % insights_from_discoveries
		insights += insights_from_discoveries
	if won:
		text += '\n\n'
		text += (tr('* You received %d bonus insights because you returned before running out of <term:inspiration>.') %
				 run.scaling.get_early_exit_insights_bonus(insights))
	return text

func _on_skip_button_pressed() -> void:
	(%AnimationPlayer as AnimationPlayer).speed_scale = 100

func _on_keep_card_button_pressed() -> void:
	var viewer := DECK_VIEWER_SCENE.instantiate_loaded_scene() as CardDeckViewer
	viewer.title = tr('Choose a Glyph to Keep')
	viewer.cards = _get_inheritable_cards()
	viewer.cards.sort_custom(CardType.compare)
	viewer.allow_card_selection = true
	viewer.card_selected.connect(func(card: Card) -> void:
		GlobalSaveGame.set_inherited_card(card.card_type)
		(%InheritButton as Button).text = tr('Change Kept Glyph')
		_should_warn_about_kept_card = false
		viewer.close()
	)
	GlobalUI.add_layer_content(viewer, UI.Layer.STATE_MENU_SUBMENU)

func _get_inheritable_cards() -> Array[CardType]:
	var result: Array[CardType]
	var run := Utils.get_active_run()
	for card_type in run.get_deck_cards():
		if card_type not in run.run_config.starting_cards:
			result.append(card_type)
	return result

func _make_shard_name_tooltip_text() -> String:
	var text: String
	match GameSettings.Japanese.shard_names.value():
		GameSettings.ShardNameDisplayType.ROMAJI:
			text = tr(_past_run.shard_name_meaning)
		GameSettings.ShardNameDisplayType.KANJI:
			text = JapaneseUtils.romaji_to_hiragana(_past_run.shard_name) + '\n' + tr(_past_run.shard_name_meaning)
		GameSettings.ShardNameDisplayType.HIRAGANA:
			text = _past_run.shard_name_jp + '\n' + tr(_past_run.shard_name_meaning)
		GameSettings.ShardNameDisplayType.MEANING:
			text = tr(_past_run.shard_name)
	return '[center]' + text + '[/center]'

func _make_no_inheritable_card_tooltip_text() -> String:
	return tr('No glyphs were acquired during this expedition.')

func _make_companion_tooltip_text() -> String:
	var run := Utils.get_active_run()
	return (tr('<header_font_size>[b]%s <term:companion> Ability[/b][/font_size]\n%s') %
			[tr(run.run_config.companion.companion_name), tr(run.run_config.companion.ability_description)])
