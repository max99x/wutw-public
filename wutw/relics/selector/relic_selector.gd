class_name RelicSelector
extends Node

signal finished
signal selected(relic: Relic)
signal canceled

static var RELIC_CHOICE_SCENE := AsyncLoadedResource.new('res://relics/selector/relic_choice.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var DECK_VIEWER_SCENE := AsyncLoadedResource.new('res://cards/viewer/card_deck_viewer.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

const MINIMIZE_BUTTON_ANIMATION_DURATION := 0.15
const MINIMIZE_ANIMATION_DURATION := 0.6

var relic_reward_pool: Array[Relic]
var extra_choices: Array[Relic]
var manual_select: bool = true
var add_selected: bool = true
var _closing := false
var _minimize_tween: Tween
var _minimized: bool = false

func _ready() -> void:
	_refill_relics_list()
	_refresh_reroll_button()

	var tween := create_tween()
	(%MinimizeButton as Control).modulate.a = 0.0
	tween.tween_property(%MinimizeButton, 'modulate:a', 0.75, 0.5)
	tween.play()
	(%ScrollPanel as ScrollPanel).animate_unroll()

func _shortcut_input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed('minimize', false):
		_on_minimize_button_pressed()
		get_viewport().set_input_as_handled()

func _refill_relics_list() -> void:
	var run := Utils.get_active_run()
	Utils.clear_node(%RelicsList)

	var selected_relics: Array[Relic]
	if manual_select:
		selected_relics = relic_reward_pool
	else:
		var weighted_pool: Dictionary[Relic, float] = {}
		var owned_relic_ids: Dictionary[String, bool] = {}
		for relic in run.get_current_relics():
			owned_relic_ids[relic.relic_id] = true
		for relic in relic_reward_pool:
			if relic.relic_id not in owned_relic_ids and relic not in extra_choices:
				weighted_pool[relic] = Relic.RARITY_WEIGHTS[relic.rarity]
		if not weighted_pool:
			weighted_pool[Relic.get_fallback_relic()] = 1.0

		var num_choices := run.get_var(RunVars.Var.RELIC_REWARD_CHOICES)
		selected_relics.assign(run.get_relic_reward_random().pick_weighted_dict(weighted_pool, num_choices))
		if not Utils.ensure(not selected_relics.is_empty()):
			selected_relics.assign(relic_reward_pool.slice(0, num_choices))
		for extra_choice in extra_choices:
			if Utils.ensure(extra_choice not in selected_relics):
				selected_relics.append(extra_choice)

	for relic: Relic in selected_relics:
		var relic_choice: RelicChoice = RELIC_CHOICE_SCENE.instantiate_loaded_scene()
		relic_choice.relic = relic
		relic_choice.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		relic_choice.new_icon_visible = not GlobalSaveGame.has_seen_relic(relic)
		relic_choice.selected.connect(_on_relic_selected.bind(relic))
		%RelicsList.add_child(relic_choice)

func _on_relic_selected(relic: Relic) -> void:
	if add_selected:
		Utils.get_active_run().add_relic(relic)
	selected.emit(relic)
	close()

func _refresh_reroll_button() -> void:
	var run := Utils.get_active_run()
	(%RerollButton as Button).visible = not manual_select and run.get_var(RunVars.Var.RELIC_REWARD_REROLLS) > 0

func _on_reroll_button_pressed() -> void:
	var run := Utils.get_active_run()
	assert(run.get_var(RunVars.Var.RELIC_REWARD_REROLLS) > 0)

	_refill_relics_list()
	run.get_vars().modify_base_value(RunVars.Var.RELIC_REWARD_REROLLS, -1)
	_refresh_reroll_button()

func _on_view_deck_button_pressed() -> void:
	var viewer := DECK_VIEWER_SCENE.instantiate_loaded_scene() as CardDeckViewer
	viewer.cards = Utils.get_active_run().get_deck_cards().duplicate()
	viewer.cards.sort_custom(CardType.compare)
	# HACK: This node could be in several layers up to STATE_MENU, so to be safe, place the submenu higher.
	GlobalUI.add_layer_content(viewer, UI.Layer.STATE_MENU_SUBMENU)

func _on_skip_button_pressed() -> void:
	canceled.emit()
	close()

func close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
		(%BG as FadedBackground).fade_out()
		var tween := create_tween()
		tween.tween_property(%MinimizeButton, 'modulate:a', 0.0, 0.5)
		tween.play()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		finished.emit()
		queue_free()

func _on_minimize_button_pressed() -> void:
	Utils.set_input_enabled(%ScrollPanel as Control, false)
	Utils.set_input_enabled(%MinimizeButton as Control, false)
	_minimize_tween = create_tween()
	if _minimized:
		_minimize_tween.set_ease(Tween.EASE_OUT)
		var visible_y := (%InputBlocker as Control).position.y - 1000
		_minimize_tween.tween_property(%InputBlocker, 'position:y', visible_y, MINIMIZE_ANIMATION_DURATION)
		_minimize_tween.parallel().tween_property(%BG, 'modulate:a', 1.0, MINIMIZE_ANIMATION_DURATION)
		_minimize_tween.parallel().tween_property(%MinimizeButton, 'modulate:a', 0.9, MINIMIZE_ANIMATION_DURATION)
	else:
		_minimize_tween.set_ease(Tween.EASE_IN)
		var hidden_y := (%InputBlocker as Control).position.y + 1000
		_minimize_tween.tween_property(%InputBlocker, 'position:y', hidden_y, MINIMIZE_ANIMATION_DURATION)
		_minimize_tween.parallel().tween_property(%BG, 'modulate:a', 0.2, MINIMIZE_ANIMATION_DURATION)
		_minimize_tween.parallel().tween_property(%MinimizeButton, 'modulate:a', 0.5, MINIMIZE_ANIMATION_DURATION)
	_minimize_tween.parallel().tween_callback(func() -> void:
		await get_tree().create_timer(MINIMIZE_ANIMATION_DURATION * 0.3).timeout
		(%MinimizeButton as Button).icon = (
			load('res://events/system/scenes/minimize_arrow_down.png') if _minimized
			else load('res://events/system/scenes/minimize_arrow_up.png'))
		(%MinimizeButton as Button).text = tr('Hide') if _minimized else tr('Show')
		_minimized = not _minimized
	)
	_minimize_tween.set_speed_scale(Utils.anim_speed())
	_minimize_tween.play()
	await _minimize_tween.finished
	Utils.set_input_enabled(%ScrollPanel as Control, true)
	Utils.set_input_enabled(%MinimizeButton as Control, true)
