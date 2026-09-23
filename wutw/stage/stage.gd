class_name Stage
extends Node2D

signal finish_button_pressed
signal stage_ended

enum Mode { STARTER_TUTORIAL, REGULAR, HARMONIZATION, SURVEY }

static var SPOT_SCENE := AsyncLoadedResource.new('res://stage/spots/spot.tscn')
static var HAUNTING_SPOT_SCENE := AsyncLoadedResource.new('res://stage/hauntings/haunting_spot.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var HAUNTING_HARMONIZATION_SCENE := AsyncLoadedResource.new('res://stage/hauntings/haunting_harmonization.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var SETTLEMENT_NAMES := AsyncLoadedResource.new('res://stage/settlement_names.tres', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var STARTER_TUTORIAL_SCENE := AsyncLoadedResource.new('res://tutorial/starter/starter_tutorial.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var SURVEY_SCENE := AsyncLoadedResource.new('res://stage/survey/survey.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

# To avoid repeated names. Keeping this as a static means name assignment is non-deterministic,
# but that is fine because they have no gameplay impact and this solution is super simple.
static var _recent_settlement_names: Array[String] = []

const ZOOM_STAGE := 8
const ZOOM_HARMONIZATION := 6.5
const ZOOM_SURVEY := 7.3
const ZOOM_SURVEY_END := 6
const ZOOM_MAP_SLOT := 7
const SCROLL_AMOUNT := 40
const SCROLL_SPEED := 0.1
const MAX_ACTIONS_BEFORE_GIVING_UP := 100
const MAX_RECENT_SETTLEMENT_NAMES := 30

@export var arrow_start_sound: WwiseEvent
@export var arrow_confirm_sound: WwiseEvent
@export var arrow_cancel_sound: WwiseEvent

var mode: Mode = Mode.REGULAR

# Only for regular, non-harmonization stages.
var settlement: Settlement
var events: Dictionary[SpotUpgrade, Event_Stage]

var _spots: Array[Spot]
var _hauntings: Array[HauntingBase]
var _scroll_offset: int = 0
var _scroll_tween: Tween
var _starter_tutorial: StarterTutorial
var _survey: Survey

# For both modes.
var _selected_card: Card
# Amounts granted within this stage, including both spots and other (e.g. card abilities).
# These are already added to the run bonuses by the time they are seen here.
var _stage_bonus_amounts: BonusAmounts = BonusAmounts.new()
var _redraws_left: int
var _card_just_slotted := false
var _num_stage_modifiers: int = 0

var _processing_card: Card
var _queued_actions: Array[Callable]
var _queued_events: Array[Event]
var _num_actions_processed: int
var _end_button_pending := false

func _ready() -> void:
	modulate.a = 0

	if mode == Mode.REGULAR:
		_setup_foray()
	elif mode == Mode.HARMONIZATION:
		_setup_harmonization()
	elif mode == Mode.SURVEY:
		_setup_survey()
	elif mode == Mode.STARTER_TUTORIAL:
		await _setup_starter_tutorial()
	else:
		Utils.ensure(false)

	var run := Utils.get_active_run()
	(%MulliganButton as Button).visible = run.get_var(RunVars.Var.MULLIGANS) > 0
	(%MulliganButton as Button).text = tr('Replan (%d)') % run.get_var(RunVars.Var.MULLIGANS)
	GlobalTooltipSystem.attach(%MulliganButton as Control, _make_mulligan_tooltip_text,
			[Tooltip.RelativeDirection.LEFT], [Tooltip.Alignment.CENTERED])

	if run.run_config.companion:
		var companion_scene := run.run_config.companion.scene.instantiate()
		%CompanionPanel.add_child(companion_scene)

	var tween := create_tween()
	tween.tween_property(self, 'modulate:a', 1.0, 0.5)
	tween.set_speed_scale(Utils.anim_speed())
	tween.play()
	GlobalUI.ui_hide_toggled.connect(func() -> void:
		modulate.a = 0 if GlobalUI.is_ui_hidden() else 1
	)

	if mode == Mode.SURVEY:
		get_card_deck().visible = false
		(%FinishButton as Button).visible = false
		(%MulliganButton as Button).visible = false
		await _survey.started
		get_card_deck().visible = true
		get_card_deck().modulate.a = 0
		tween = create_tween()
		tween.tween_property(get_card_deck(), 'modulate:a', 1.0, 0.5)
		tween.set_speed_scale(Utils.anim_speed())
		tween.play()
		(%FinishButton as Button).visible = true
		(%MulliganButton as Button).visible = run.get_var(RunVars.Var.MULLIGANS) > 0

	_redraws_left = run.get_var(RunVars.Var.REDRAWS)
	_update_redraws()

	(%FinishButton as Button).disabled = true
	(%MulliganButton as Button).disabled = true
	get_card_deck().disable_interaction()
	await get_card_deck().start(run.get_deck_cards(), run.get_card_deck_random(), _choose_helper_innate())
	get_card_deck().enable_interaction()
	(%FinishButton as Button).disabled = false
	(%MulliganButton as Button).disabled = false

	# Hauntings are set up after the initial draw, so they don't trigger for initially drawn cards.
	var run_data := run.get_run_data()
	for haunting in _hauntings:
		haunting.setup()
		run_data.encountered_hauntings[haunting.haunting_type] = 1 + run_data.encountered_hauntings.get(haunting.haunting_type, 0)
		haunting.pacified.connect(func() -> void:
			run_data.pacified_hauntings[haunting.haunting_type] = 1 + run_data.pacified_hauntings.get(haunting.haunting_type, 0)
		)

	if mode == Mode.REGULAR:
		# Needed to show initial bonuses when reloading.
		run.get_top_hud().get_stage_goal_tracker().update(_stage_bonus_amounts, false)

func _enter_tree() -> void:
	GlobalAudioSystem.is_in_stage = true

func _exit_tree() -> void:
	GlobalAudioSystem.is_in_stage = false

func _shortcut_input(event: InputEvent) -> void:
	if GlobalUI.is_higher_level_active(self):
		return
	if event.is_action_pressed('end_turn', false) and not (%FinishButton as Button).disabled:
		_on_finish_button_pressed()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('scroll_spots_right', true):
		_scroll_offset += SCROLL_AMOUNT
	elif event.is_action_pressed('scroll_spots_left', true):
		_scroll_offset -= SCROLL_AMOUNT
	else:
		return
	var scrollbar := (%SpotsScroller as ScrollContainer).get_h_scroll_bar() as ScrollBar
	_scroll_offset = clamp(_scroll_offset, scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	if _scroll_tween:
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(scrollbar, 'value', _scroll_offset, SCROLL_SPEED)
	_scroll_tween.play()

func get_card_deck() -> CardDeck:
	return %CardDeck

func get_selected_card() -> Card:
	return _selected_card

func get_redraws_left() -> int:
	return _redraws_left

func get_spots() -> Array[Spot]:
	return _spots.duplicate()

func get_survey() -> Survey:
	return _survey

func get_goal() -> StageGoal:
	if mode == Mode.REGULAR:
		return settlement.state.goal
	else:
		return null

func get_remaining_requirements() -> Dictionary[BonusType, int]:
	assert(mode == Mode.REGULAR)
	return get_goal().get_remaining_requirements(_stage_bonus_amounts)

func get_aspect_slots_availability(include_companion: bool = false) -> Dictionary[AspectSlot, bool]:
	var result: Dictionary[AspectSlot, bool] = {}
	for aspect_slot in get_all_aspect_slots(include_companion):
		var recipe := Utils.get_typed_ancestor(aspect_slot, Recipe) as Recipe
		result[aspect_slot] = recipe.is_available() and not aspect_slot.is_filled
	return result

func get_hauntings() -> Array[HauntingBase]:
	return _hauntings.duplicate()

func get_stage_bonus_amounts() -> BonusAmounts:
	return _stage_bonus_amounts

func grant_stage_bonus(bonus_type: BonusType, amount: int) -> void:
	_stage_bonus_amounts.add_amount(bonus_type, amount)
	if mode == Mode.REGULAR:
		_update_bonus_highlights()

func add_redraws(delta: int) -> void:
	assert(delta >= 0)
	_redraws_left += delta
	_update_redraws()

func add_modifier(type: RunVars.Var, delta: int) -> void:
	var tag := get_stage_modifier_tag(_num_stage_modifiers)
	_num_stage_modifiers += 1
	var run := Utils.get_active_run()
	run.get_vars().add_modifier(type, delta, tag)

func get_stage_modifier_tag(index: int) -> String:
	return 'stage_modifier_' + str(index)

func get_finish_button() -> Button:
	return %FinishButton as Button

# Animation action queuing system.

func queue_action(f: Callable) -> void:
	assert(_processing_card or get_card_deck().is_redrawing())
	if not Utils.ensure(f.get_argument_count() == 0):
		f = f.unbind(f.get_argument_count())
	_queued_actions.append(f)

func cast_ability(card: Card, ability: CardAbility) -> bool:
	assert(_processing_card)

	card.highlighted_ability = ability
	await get_tree().create_timer(Utils.anim_duration(Card.ABILITY_HIGHLIGHT_DURATION * 0.8)).timeout

	var run := Utils.get_active_run()
	run.signals.ability_started.emit(card, ability)
	await _process_queued_actions()  # Wait for anything that reacts to ability starting.

	if run.get_var(RunVars.Var.ABILITY_CASTS_BLOCKED) > 0:
		run.get_vars().modify_base_value(RunVars.Var.ABILITY_CASTS_BLOCKED, -1)
		return false
	else:
		ability.cast(card)
		await _process_queued_actions()  # Wait for whatever the ability queued.
		run.signals.ability_finished.emit(card, ability)
		await _process_queued_actions()  # Wait for anything that reacts to ability finishing.
		return true

func ensure_slot_visible(slot: AspectSlot) -> void:
	if mode == Mode.REGULAR:
		if (%SpotsScroller as ScrollContainer).is_ancestor_of(slot):
			(%SpotsScroller as ScrollContainer).ensure_control_visible(
				Utils.get_typed_ancestor(slot, Recipe) as Recipe)
	elif mode == Mode.HARMONIZATION:
		var duration := Utils.anim_duration(0.5)
		var run := Utils.get_active_run()
		var slot_settlement := Utils.get_typed_ancestor(slot, Settlement) as Settlement
		var slot_capital := Utils.get_typed_ancestor(slot, Capital) as Capital
		if slot_settlement:
			run.get_map().focus_location(slot_settlement.get_map_location(), ZOOM_MAP_SLOT, duration)
			await get_tree().create_timer(duration).timeout
		elif slot_capital:
			run.get_map().focus_location(slot_capital.get_map_location(), ZOOM_MAP_SLOT, duration)
			await get_tree().create_timer(duration).timeout

func is_processing_card() -> bool:
	return _processing_card != null

func get_processing_card() -> Card:
	return _processing_card

func _begin_processing(card: Card) -> void:
	_processing_card = card
	GlobalContextHighlight.enabled = false
	get_card_deck().disable_interaction()
	get_card_deck().start_processing(card)
	(%ShowAllToggle as Button).disabled = true
	(%MulliganButton as Button).disabled = true  # Permanently disabled for the stage.
	_num_actions_processed = 0

func _finish_processing(card: Card) -> void:
	GlobalContextHighlight.enabled = true
	get_card_deck().finish_processing(card)
	get_card_deck().enable_interaction()
	_processing_card = null
	(%ShowAllToggle as Button).disabled = false

	var run := Utils.get_active_run()
	if run.get_vars().get_current_value(RunVars.Var.CURRENT_INSPIRATION) <= 0:
		_finish_stage()
		return

	for event in _queued_events:
		Utils.get_active_run().queue_event(event)
	_queued_events.clear()

	if _end_button_pending:
		_end_button_pending = false
		_on_finish_button_pressed()

	# TEMP HOTFIX: Un-reproable reports of connections not fulfilling lacks.
	if mode == Mode.HARMONIZATION:
		run.get_capital().update_settlement_lacks()

func cast_card(card: Card, already_processing: bool = false) -> void:
	Utils.ensure(not card.card_type.abilities.is_empty())

	if not already_processing:
		_begin_processing(card)

	GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_DRAWSTACK_SCROLL_UP)

	var run := Utils.get_active_run()
	run.signals.card_cast_started.emit(card)
	await _process_queued_actions()  # Wait for anything that reacts to cast starting.

	var destroy := false
	var has_echo_ability := false
	for ability in card.card_type.abilities:
		var cast_succeeded := await cast_ability(card, ability)
		if cast_succeeded:
			if ability is CardAbility_Echo:
				has_echo_ability = true
			if ability.should_destroy_on_cast():
				destroy = true

	run.signals.card_cast_finished.emit(card)
	await _process_queued_actions()  # Wait for anything that reacts to cast finishing.

	if not has_echo_ability:
		get_card_deck().set_most_recently_cast_card(card.card_type)

	await get_card_deck().discard(card, CardDeck.DiscardReason.CAST, destroy)
	await _process_queued_actions()  # Wait for anything that reacts to discarding.

	# Unhighlight abilities in case discard was blocked.
	card.highlighted_ability = null

	if not already_processing:
		_finish_processing(card)

func _play_card_on_slot(card: Card, slot: AspectSlot) -> void:
	_begin_processing(card)

	await slot.animate_fill()
	Utils.get_active_run().signals.card_slotted.emit(card, slot)
	# Wait for anything that reacts to slot filling or card slotting.
	# Has to be together else the slot may be dead by then (hauntings pacified).
	await _process_queued_actions()
	if card.get_parent():  # Not discarded yet?
		await get_card_deck().discard(card, CardDeck.DiscardReason.SLOTTED)
		await _process_queued_actions()  # Wait for anything that reacts to discards.

	_finish_processing(card)

func _process_queued_actions() -> void:
	var to_process := _queued_actions.duplicate()
	_queued_actions.clear()
	while not to_process.is_empty():
		var action: Callable = to_process.pop_front()
		await action.call()
		to_process = _queued_actions + to_process  # Newly queued reactions happen first.
		_queued_actions.clear()
		# Safeguard: ensure this can never loop infinitely.
		_num_actions_processed += 1
		if _num_actions_processed > MAX_ACTIONS_BEFORE_GIVING_UP:
			push_error('Card processing led to infinite loop! Giving up.')
			breakpoint
			break

# Core Functionality

func _setup_foray() -> void:
	assert(settlement)

	var run := Utils.get_active_run()
	var map := run.get_map()

	var remaining_events := events.duplicate() as Dictionary[SpotUpgrade, Event_Stage]
	Utils.clear_node(%SpotsList)
	var added_types: Array[SpotType]
	var hauntings_roll_result := HauntingType.choose_spot_hauntings(
		settlement.state.spot_types, run.get_events_random(), run.get_run_data().haunting_leftover_roll)
	for spot_type in settlement.state.spot_types:
		var container := HBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
		container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		%SpotsList.add_child(container)

		# Setup spot.
		var spot := SPOT_SCENE.instantiate_loaded_scene() as Spot
		spot.spot_type = spot_type
		spot.filter_to_requirements = get_goal().bonus_requirements.keys()
		spot.is_first_spot_copy = spot_type not in added_types
		added_types.append(spot_type)
		# Sort events to prioritize unique, so the is_first_copy check doesn't drop them.
		var sorted_remaining_events := remaining_events.keys()
		sorted_remaining_events.sort_custom(func(a: SpotUpgrade, b: SpotUpgrade) -> bool:
			if a.unique_per_run != b.unique_per_run:
				return a.unique_per_run
			else:
				return a.spot_upgrade_id < b.spot_upgrade_id
		)
		for upgrade: SpotUpgrade in sorted_remaining_events:
			if spot_type.contains_upgrade(upgrade):
				var event := remaining_events[upgrade]
				spot.set_upgrade_event(upgrade, event)
				remaining_events.erase(upgrade)
				# Distribute between duplicate spots.
				if (not event.get_associated_landmark()
					and settlement.state.spot_types.rfind(spot_type) != _spots.size()):
					break

		# Ensure quest- and shard-requested upgrades.
		for quest_instance in GlobalSaveGame.get_all_quest_instances():
			if quest_instance.is_active():
				for ensured in quest_instance.get_quest().get_ensured_upgrades():
					if ensured.spot == spot_type:
						spot.ensure_upgrade_available(ensured)
		if GlobalSaveGame.get_pinned_shard_type():
			for ensured in GlobalSaveGame.get_pinned_shard_type().get_ensured_upgrades():
				if ensured.spot == spot_type:
					spot.ensure_upgrade_available(ensured)

		spot.upgrade_activated.connect(_on_spot_upgrade_activated.bind(spot))
		container.add_child(spot)
		_spots.append(spot)
		spot.animate_unroll()

		# Setup haunting.
		var haunting_type := hauntings_roll_result.hauntings.pop_front() as HauntingType
		if haunting_type:
			var is_standalone_haunt := haunting_type.spot_attach_mode == HauntingType.SpotAttachMode.GLOBAL
			var haunting := HAUNTING_SPOT_SCENE.instantiate_loaded_scene() as Haunting_Spot
			haunting.haunting_type = haunting_type
			haunting.attached_to_spot = null if is_standalone_haunt else spot
			if is_standalone_haunt:
				haunting.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				haunting.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				%SpotsList.add_child(haunting)
			else:
				haunting.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				haunting.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				container.add_child(haunting)
			_hauntings.append(haunting)
			haunting.pacified.connect(func() -> void: _hauntings.erase(haunting))
	run.get_run_data().haunting_leftover_roll = hauntings_roll_result.leftover_roll

	if remaining_events:
		push_warning('Events are left over after spot assignment.')

	(%SpotsScroller as Control).visible = true
	(%ShowAllToggle as Control).visible = Skill.get_skill_var(Skill.Var.NONGOAL) > 0
	run.get_stage_goal_tracker().visible = true
	run.get_stage_goal_tracker().goal = get_goal()
	run.get_harmonization_haunting_bar().visible = false
	map.view_controls_enabled = false

	_update_bonus_highlights()

	# Reveal FoW and center settlement on the map, fully zoomed in.
	var reveal_radius := settlement.get_radius() + run.scaling.settlement_reveal_radius_base
	reveal_radius = roundi(reveal_radius * run.get_var(RunVars.Var.REVEAL_RADIUS_PERCENT) / 100.0)
	map.reveal_fow_tween(settlement.get_map_location(), reveal_radius)
	map.focus_location(settlement.get_map_location(), ZOOM_STAGE)

func _setup_harmonization() -> void:
	Utils.ensure(not settlement and not events)

	var run := Utils.get_active_run()
	var map := run.get_map()

	(%SpotsScroller as Control).visible = false
	run.get_stage_goal_tracker().visible = false
	(%ShowAllToggle as Control).visible = false
	map.view_controls_enabled = true

	var settlements: Array[Settlement]
	for map_object in map.get_map_objects():
		if map_object is Settlement:
			var map_settlement := map_object as Settlement
			map_settlement.mode = Settlement.Mode.HARMONIZATION
			map_settlement.hide_completed_recipes()
			settlements.append(map_settlement)
		elif map_object is Capital:
			(map_object as Capital).mode = Capital.Mode.HARMONIZATION
	run.get_capital().update_settlement_lacks()  # In case went from single to double lacks.

	# Setup hauntings.
	run.get_events_random().shuffle(settlements)
	var hauntings_roll_result := HauntingType.choose_harmonization_hauntings(
		settlements, run.get_events_random(), run.get_run_data().haunting_leftover_roll)
	for other_settlement in settlements:
		var haunting_type := hauntings_roll_result.hauntings.pop_front() as HauntingType
		if haunting_type:
			var haunting := HAUNTING_HARMONIZATION_SCENE.instantiate_loaded_scene() as Haunting_Harmonization
			haunting.haunting_type = haunting_type
			haunting.attached_to_settlement = other_settlement
			other_settlement.set_haunting(haunting)
			_hauntings.append(haunting)
			haunting.pacified.connect(func() -> void: _hauntings.erase(haunting))
		else:
			other_settlement.set_haunting(null)
	run.get_run_data().haunting_leftover_roll = hauntings_roll_result.leftover_roll

	if _hauntings and GameSettings.Interface.show_harmonization_haunting_preview.value():
		for haunting in _hauntings:
			run.get_harmonization_haunting_bar().track_haunting(haunting as Haunting_Harmonization)
		run.get_harmonization_haunting_bar().visible = true
	else:
		run.get_harmonization_haunting_bar().visible = false

func _setup_survey() -> void:
	Utils.ensure(not settlement and not events)

	var run := Utils.get_active_run()
	var map := run.get_map()

	Utils.clear_node(%SpotsList)
	_survey = SURVEY_SCENE.instantiate_loaded_scene() as Survey
	_survey.map_location = run.get_run_data().current_survey_location
	_survey.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_survey.outcome_started.connect(func() -> void:
		(%FinishButton as Button).disabled = true
	)
	_survey.outcome_finished.connect(func() -> void:
		(%FinishButton as Button).disabled = false
	)
	_survey.seen_outcome_on_death.connect(func() -> void:
		_finish_stage()
	)
	Utils.ensure(_survey.map_location.x >= 0)
	%SpotsList.add_child(_survey)
	run.get_stage_goal_tracker().visible = false
	run.get_harmonization_haunting_bar().visible = false
	(%ShowAllToggle as Control).visible = false
	map.view_controls_enabled = false
	map.focus_location(run.get_run_data().current_survey_location, ZOOM_SURVEY)

func _setup_starter_tutorial() -> void:
	Utils.ensure(not settlement and not events)

	var run := Utils.get_active_run()
	var map := run.get_map()

	_starter_tutorial = STARTER_TUTORIAL_SCENE.instantiate_loaded_scene() as StarterTutorial
	GlobalUI.add_layer_content(_starter_tutorial, UI.Layer.GAME)
	z_index += 1  # HACK
	Utils.clear_node(%SpotsList)
	(%SpotsScroller as Control).visible = false
	(%ShowAllToggle as Control).visible = false
	get_finish_button().visible = false
	map.view_controls_enabled = false
	await _starter_tutorial.start()

func _on_card_deck_card_drag_started(card: Card) -> void:
	Utils.ensure(not _selected_card)
	card.is_selected = true
	_selected_card = card
	(%CardArrow as BrushstrokeArrow).card = _selected_card
	arrow_start_sound.post(card)

	# Need to do this every time, since slots can change (e.g. non-goal switch).
	for aspect_slot in get_all_aspect_slots(true):
		aspect_slot.card_dropped.connect(_on_card_dropped_on_slot.bind(aspect_slot))

func _on_card_deck_card_drag_ended(card: Card) -> void:
	Utils.ensure(_selected_card == card)
	_selected_card = null
	(%CardArrow as BrushstrokeArrow).card = null
	if _card_just_slotted:
		arrow_confirm_sound.post(self)
		_card_just_slotted = false
	else:
		card.is_selected = false
		var message := SlotUtils.get_slot_failure_error_message(card.card_type.aspects)
		if message:
			GlobalUI.show_error(message)
		else:
			arrow_cancel_sound.post(self)

	for aspect_slot in get_all_aspect_slots(true):
		aspect_slot.card_dropped.disconnect(_on_card_dropped_on_slot.bind(aspect_slot))

func _on_card_deck_card_right_clicked(card: Card) -> void:
	if card.card_type.abilities:
		cast_card(card)
	else:
		GlobalUI.show_error(tr('This <term_lower:glyph> has no <term_lower:card_ability>s.'))

func get_all_aspect_slots(include_companion: bool = false) -> Array[AspectSlot]:
	var result: Array[AspectSlot] = []

	if mode == Mode.REGULAR:
		# Regular stage.
		for spot in _spots:
			if not spot.is_locked:
				result.append_array(spot.get_all_aspect_slots())
		for haunting in _hauntings:
			result.append_array(haunting.get_aspect_slots())
	elif mode == Mode.HARMONIZATION:
		# Harmonization.
		for map_object in Utils.get_active_run().get_map().get_map_objects():
			if map_object is Settlement:
				result.append_array((map_object as Settlement).get_aspect_slots())
			elif map_object is Capital:
				result.append_array((map_object as Capital).get_aspect_slots())
		for haunting in _hauntings:
			result.append_array(haunting.get_aspect_slots())
	elif mode == Mode.STARTER_TUTORIAL:
		for recipe in _starter_tutorial.get_recipes():
			result.append_array(recipe.get_aspect_slots())
	elif mode == Mode.SURVEY:
		result.append_array(_survey.get_all_aspect_slots())
	else:
		Utils.ensure(false)

	# Companion.
	if include_companion and %CompanionPanel.get_child_count():
		var companion_recipe := %CompanionPanel.get_child(0) as CompanionRecipe
		if Utils.ensure(companion_recipe != null):
			result.append_array(companion_recipe.get_aspect_slots())

	return result

func get_all_recipes(include_companion: bool = false) -> Array[Recipe]:
	var result: Array[Recipe] = []

	if mode == Mode.REGULAR:
		# Regular stage.
		for spot in _spots:
			if not spot.is_locked:
				result.append_array(spot.get_all_recipes())
	elif mode == Mode.HARMONIZATION:
		# Harmonization.
		for map_object in Utils.get_active_run().get_map().get_map_objects():
			if map_object is Settlement:
				result .append_array((map_object as Settlement).get_recipes())
			elif map_object is Capital:
				result.append_array((map_object as Capital).get_recipes())
	elif mode == Mode.STARTER_TUTORIAL:
		result.append_array(_starter_tutorial.get_recipes())
	elif mode == Mode.SURVEY:
		result.append_array(_survey.get_recipes())
	else:
		Utils.ensure(false)

	result.append_array(_hauntings)

	# Companion.
	if include_companion and %CompanionPanel.get_child_count():
		var companion_recipe := %CompanionPanel.get_child(0) as CompanionRecipe
		if Utils.ensure(companion_recipe != null):
			result.append(companion_recipe)

	return result

func _on_card_dropped_on_slot(card: Card, slot: AspectSlot) -> void:
	Utils.ensure(card == _selected_card)
	if not slot.can_be_filled_by(card.card_type.aspects):
		return
	for aspect_slot in get_all_aspect_slots(true):
		aspect_slot.state = AspectSlot.State.NORMAL
	_card_just_slotted = true
	_play_card_on_slot(card, slot)

func _update_redraws() -> void:
	var finish_button := %FinishButton as Button
	if _redraws_left:
		if _redraws_left > 1 or Utils.get_active_run().get_var(RunVars.Var.REDRAWS) > 1:
			# Avoid showing this extra noise when it's always just 1 or 0.
			finish_button.text = tr('Redraw Hand (%d left)') % _redraws_left
		else:
			finish_button.text = tr('Redraw Hand')
	else:
		if mode == Mode.REGULAR:
			finish_button.text = tr('End Foray')
		elif mode == Mode.HARMONIZATION:
			finish_button.text = tr('End Convergence')
		elif mode == Mode.STARTER_TUTORIAL:
			finish_button.text = tr('Start Expedition')
		elif mode == Mode.SURVEY:
			finish_button.text = tr('End Survey')
		else:
			Utils.ensure(false)

func _on_finish_button_pressed() -> void:
	(%MulliganButton as Button).disabled = true  # Permanently disabled for the stage.
	(%FinishButton as Button).disabled = true

	# Delay if we're waiting for an animation to finish.
	if _processing_card or get_card_deck().is_redrawing():
		_end_button_pending = true
		return

	# If the relevant flag is set, cast everything.
	if Utils.get_active_run().get_var(RunVars.Var.CAST_ALL_ON_TURN_END):
		for card in get_card_deck().get_hand_cards():
			# Card could no longer exist if casting causes it to be discarded (e.g. inkstick relic)
			if card and card.card_type.abilities:
				await cast_card(card)

	# Cast any remaining negative cards.
	if not Utils.get_active_run().get_var(RunVars.Var.NEGATIVE_CARD_PROTECTION):
		for card in get_card_deck().get_hand_cards():
			# Card could no longer exist if casting causes it to be discarded (e.g. inkstick relic)
			if card and card.card_type.abilities and card.card_type.rarity == CardType.Rarity.NEGATIVE:
				await cast_card(card)

	if _redraws_left:
		_redraws_left -= 1
		_update_redraws()
		get_card_deck().disable_interaction()
		_num_actions_processed = 0
		await (%CardDeck as CardDeck).redraw()
		# Wait for anything that reacts to discards or draws.
		# HACK: It is technically inaccurate to process the actions after all the cards are drawn,
		#       as actions could be queued with each draw/discard. However, in practice this may be
		#       desired, e.g. so Butterbur Extract could exceed hand size.
		await _process_queued_actions()
		get_card_deck().enable_interaction()
		(%FinishButton as Button).disabled = false
	else:
		_finish_stage()

func _finish_stage() -> void:
	finish_button_pressed.emit()

	var run := Utils.get_active_run()
	for haunting in _hauntings:
		haunting.cleanup_and_close(0.5)
	run.get_harmonization_haunting_bar().clear()
	run.get_harmonization_haunting_bar().visible = false

	for child in get_children():
		if child is Control:
			Utils.set_input_enabled(child as Control, false)
	for spot in _spots:
		spot.animate_roll(0.5)
	await get_tree().create_timer(Utils.anim_duration(0.2)).timeout
	var tween := create_tween()
	tween.tween_property(self, 'modulate:a', 0.0, 0.5)
	tween.set_speed_scale(Utils.anim_speed())
	tween.play()
	await tween.finished

	if mode == Mode.STARTER_TUTORIAL:
		await _starter_tutorial.animate_transition()

	var map := run.get_map()
	if mode == Mode.REGULAR:
		run.signals.before_foray_finished.emit(settlement.state)
		settlement.state.settlement_name = _generate_settlement_name()
		settlement.state.bonus_amounts = _stage_bonus_amounts.duplicate()
		await settlement.reveal()
	elif mode == Mode.HARMONIZATION:
		GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_SELECT_TAIKO_LOW)
		# Unscaled speed, since it's part of the audio.
		get_tree().create_timer(0.3).timeout.connect(
			GlobalAudioSystem.play.bind(AK.EVENTS.UI_GENERIC_SELECT_TAIKO_LOW))
		await get_tree().create_timer(Utils.anim_duration(0.8)).timeout
		for map_object in map.get_map_objects():
			if map_object is Settlement:
				(map_object as Settlement).mode = Settlement.Mode.SHOPPABLE
			elif map_object is Capital:
				(map_object as Capital).mode = Capital.Mode.SHOPPABLE
	elif mode == Mode.STARTER_TUTORIAL:
		_starter_tutorial.queue_free()
		_starter_tutorial = null
	elif mode == Mode.SURVEY:
		run.get_run_data().finished_episodes[run.get_current_stage_index()] = _survey.get_finished_episodes()
		var survey_location := run.get_run_data().current_survey_location
		var reveal_radius := run.scaling.survey_reveal_radius_base
		reveal_radius += _survey.get_num_episodes_finished() * run.scaling.survey_reveal_radius_per_episode
		reveal_radius = roundi(reveal_radius * run.get_var(RunVars.Var.REVEAL_RADIUS_PERCENT) / 100.0)
		map.focus_location(survey_location, ZOOM_SURVEY_END)
		await map.reveal_fow_tween(survey_location, reveal_radius)
		_survey.queue_free()
		_survey = null
	else:
		Utils.ensure(false)

	for i in range(_num_stage_modifiers):
		run.get_vars().remove_modifier(get_stage_modifier_tag(i))

	stage_ended.emit()

# Regular stages only

func _generate_settlement_name() -> SettlementNameOption:
	var current_run_names: Array[String]
	for state in Utils.get_active_run().get_settlement_states():
		if state.settlement_name:
			current_run_names.append(state.settlement_name.name)

	var pool: Dictionary[SettlementNameOption, float]
	var settlement_name_set := SETTLEMENT_NAMES.get_loaded() as SettlementNameSet
	for spot in _spots:
		for option: SettlementNameOption in settlement_name_set.get_options_by_spot(spot.spot_type):
			if option.related_spot_upgrade and option.related_spot_upgrade not in spot.get_current_upgrades():
				continue
			if option.name in _recent_settlement_names or option.name in current_run_names:
				pool[option] = 0
			else:
				pool[option] = option.probability_weight
	for option: SettlementNameOption in settlement_name_set.get_options_by_spot(null):
		if option.name in _recent_settlement_names or option.name in current_run_names:
			pool[option] = 0
		else:
			pool[option] = option.probability_weight
	if not Utils.ensure(not pool.is_empty()):
		return SettlementNameOption.new()

	var run := Utils.get_active_run()
	var selected_option := run.get_card_deck_random().pick_weighted_dict(pool)[0] as SettlementNameOption
	assert(selected_option)
	if _recent_settlement_names.size() >= MAX_RECENT_SETTLEMENT_NAMES:
		_recent_settlement_names.remove_at(0)
	_recent_settlement_names.append(selected_option.name)

	return selected_option

func _on_spot_upgrade_activated(recipe: SpotRecipe, spot: Spot) -> void:
	var run := Utils.get_active_run()
	var grants := recipe.spot_upgrade.granted_bonuses
	for bonus_type in grants:
		run.gain_bonus(BonusGain.new(bonus_type, grants[bonus_type], recipe))

	settlement.activate_upgrade(_spots.find(spot), recipe.spot_upgrade)

	if spot.get_upgrade_event(recipe.spot_upgrade):
		var event := spot.get_upgrade_event(recipe.spot_upgrade)
		_queued_events.append(event)
		spot.set_upgrade_event(recipe.spot_upgrade, null)

func _update_bonus_highlights() -> void:
	assert(mode == Mode.REGULAR)
	# Highlight unsatisfied bonuses.
	Utils.get_active_run().get_stage_goal_tracker().update(_stage_bonus_amounts, true)
	var unsatisfied := get_remaining_requirements()
	for spot in _spots:
		for spot_recipe in spot.get_all_recipes():
			for bonus_counter in spot_recipe.get_bonus_counters():
				var bonus := bonus_counter.get_bonus()
				if bonus.bonus_type in get_goal().bonus_requirements and spot_recipe.state != SpotRecipe.State.ACTIVE:
					var bonus_amount := bonus_counter.current_value  # Future bonuses may not be guaranteed to be within a listing.
					if bonus_amount > 0:
						if unsatisfied.get(bonus.bonus_type, 0) > 0:
							# Not yet satisfied.
							bonus.highlight_type = Bonus.HighlightType.POSITIVE
						else:
							# Already satisfied.
							bonus.highlight_type = Bonus.HighlightType.NONE
					else:
						# Danger! Could affect satisfaction negatively at any point.
						bonus.highlight_type = Bonus.HighlightType.NEGATIVE
				else:
					# Irrelevant.
					bonus.highlight_type = Bonus.HighlightType.NONE
				bonus_counter.highlight_type = bonus.highlight_type

func _on_show_all_toggle_pressed() -> void:
	for spot in _spots:
		if (%ShowAllToggle as Button).button_pressed:
			spot.filter_to_requirements = []
		else:
			spot.filter_to_requirements = get_goal().bonus_requirements.keys()

func _on_mulligan_button_pressed() -> void:
	var run := Utils.get_active_run()
	assert(run.get_var(RunVars.Var.MULLIGANS) > 0)
	run.get_vars().modify_base_value(RunVars.Var.MULLIGANS, -1)
	(%MulliganButton as Button).text = tr('Replan (%d)') % run.get_var(RunVars.Var.MULLIGANS)
	(%MulliganButton as Button).disabled = true  # Permanently disabled for the stage.

	(%FinishButton as Button).disabled = true
	get_card_deck().disable_interaction()
	await get_card_deck().start(run.get_deck_cards(), run.get_card_deck_random())
	get_card_deck().enable_interaction()

	# HACK: Don't trigger effects from mulligan.
	_queued_actions.clear()

	(%FinishButton as Button).disabled = false

func _make_mulligan_tooltip_text() -> String:
	return tr('Reshuffle your <term_lower:card_deck> and draw a new starting <term_lower:hand>. Can\'t be used after a card is played.')

## Noob Booster

func _choose_helper_innate() -> Array[CardType]:
	if mode != Mode.REGULAR:
		return []  # Only applies to forays.
	if GlobalSaveGame.get_main_quest_progress() >= SaveGame.MainQuestProgress.P117_COMPLETED_SURVEY:
		return []  # You're a grown up now. Gotta fend for yourself, mate.

	# Poor newbie! Let's help them! [alt: Hey kid, want a free sample?]
	# Let's guarantee at least 2 different basic aspects, one of which
	# starts the branch that leads to the highest value of the highest goal
	# and the other leads to an event (if any).

	# Goal aspect.
	var highest_goal: BonusType
	var highest_goal_value := -1
	var reqs := get_goal().bonus_requirements
	for bonus_type in reqs:
		if reqs[bonus_type] > highest_goal_value:
			highest_goal = bonus_type
			highest_goal_value = reqs[bonus_type]

	assert(highest_goal)
	var highest_goal_yielded := -1
	var highest_goal_yielded_aspect: AspectType
	for spot in _spots:
		for upgrade in spot.spot_type.upgrades:
			var yielded := _get_highest_yielded(upgrade, highest_goal)
			if yielded > highest_goal_yielded:
				highest_goal_yielded_aspect = upgrade.required_aspects[0]  # Always 1 for roots.
				highest_goal_yielded = yielded

	# Event aspect.
	var event_aspect: AspectType
	for spot in _spots:
		for upgrade in spot.spot_type.upgrades:
			if _branch_has_event(upgrade):
				event_aspect = upgrade.required_aspects[0]
				if event_aspect != highest_goal_yielded_aspect:
					break
		if event_aspect and event_aspect != highest_goal_yielded_aspect:
			break

	var helper_cards: Array[CardType]
	var run := Utils.get_active_run()
	var deck_card_types: Array[CardType] = run.get_deck_cards().duplicate()
	run.get_card_deck_random().shuffle(deck_card_types)
	if highest_goal_yielded_aspect:
		for card_type in deck_card_types:
			if highest_goal_yielded_aspect in card_type.aspects:
				helper_cards.append(card_type)
				break
	if event_aspect:
		for card_type in deck_card_types:
			if event_aspect in card_type.aspects and card_type not in helper_cards:
				helper_cards.append(card_type)
				break

	return helper_cards

func _get_highest_yielded(spot_upgrade: SpotUpgrade, bonus_type: BonusType) -> int:
	var max_child := 0
	for child in spot_upgrade.child_upgrades:
		var child_yield := _get_highest_yielded(child, bonus_type)
		if child_yield > max_child:
			max_child = child_yield
	return spot_upgrade.granted_bonuses.get(bonus_type, 0) + max_child

func _branch_has_event(spot_upgrade: SpotUpgrade) -> bool:
	if spot_upgrade in events:
		return true
	for child in spot_upgrade.child_upgrades:
		if _branch_has_event(child):
			return true
	return false
