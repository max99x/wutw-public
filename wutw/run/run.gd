class_name Run
extends Node2D

signal state_changed
signal run_ended
signal foray_goal_rerolled
@warning_ignore('unused_signal')  # Used in PauseMenu.
signal reload_requested

enum InspirationChangeReason { STAGE_GOAL, HARMONIZATION_GOAL, ABILITY, SHOP, RELIC, EVENT, COMPANION, HAUNTING, PASSIVE, SETTLER_QUEST }

static var RELIC_SELECTOR_SCENE := AsyncLoadedResource.new('res://relics/selector/relic_selector.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var STAGE_SELECTOR_SCENE := AsyncLoadedResource.new('res://stage/selector/stage_selector.tscn')
static var STAGE_SCENE := AsyncLoadedResource.new('res://stage/stage.tscn')
static var STAGE_END_SCENE := AsyncLoadedResource.new('res://stage/stage_end.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var CARD_REWARD_SCENE := AsyncLoadedResource.new('res://stage/card_reward_choice.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var CAPITAL_SCENE := AsyncLoadedResource.new('res://map/capital.tscn')
static var HARMONIZATION_END_SCENE := AsyncLoadedResource.new('res://harmonization/end/harmonization_end.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var SEASON_END_SCENE := AsyncLoadedResource.new('res://seasons/season_end.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var RUN_END_SCENE := AsyncLoadedResource.new('res://run/run_end/run_end.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var EVENT_SCENE := AsyncLoadedResource.new('res://events/system/scenes/event_scene.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var SETTLEMENT_SCENE := AsyncLoadedResource.new('res://map/settlement.tscn')
static var RUN_TOP_HUD_SCENE := AsyncLoadedResource.new('res://run/run_top_hud.tscn')

@export var scaling: RunScaling

# Set at instantiation.
var run_config: RunConfig

var signals: RunSignals = RunSignals.new()

# Player-relevant state updated over the course of the run.
# This is always the same as GlobalSaveGame._run_data when a run is in progress.
var _data: RunData

# Node tree state. Recreatable from _data.
var _stage_event_selector: StageEventSelector = StageEventSelector.new()
var _current_settlement: Settlement
var _current_capital: Capital
var _current_scene: Node
var _card_rewards_left: int = -1
var _queued_event_scenes: Array[EventScene]
var _current_event_scene: EventScene
var _opened_shop: ShopBase
var _transition_recurse_depth: int = 0
var _top_hud: RunTopHud
var _rerolled_goals: Array[Array]  # Array[BonusType]
var _relics_gained_this_stage: Array[Relic]  # Not persisted; used to display in stage end UIs.

## Startup

func _ready() -> void:
	if GameSettings.Audio.skip_claimed_music.value():
		GlobalAudioSystem.switch_music(AK.SWITCHES.MUSIC.SWITCH.GAMEPLAY_STREAMER)
	else:
		GlobalAudioSystem.switch_music(AK.SWITCHES.MUSIC.SWITCH.GAMEPLAY)

	if GlobalSaveGame.get_run_data():
		await _resume_from_data(GlobalSaveGame.get_run_data())
	else:
		await _start_new_data()

func _enter_tree() -> void:
	Utils.set_active_run(self)
	_top_hud = RUN_TOP_HUD_SCENE.instantiate_loaded_scene() as RunTopHud
	GlobalUI.add_layer_content(_top_hud, UI.Layer.HUD_TOP)
	GlobalTutorialSystem.run_started()

func _exit_tree() -> void:
	GlobalTutorialSystem.run_ended()
	_top_hud.queue_free()
	_top_hud = null
	# In case of reload, make sure we clear relic listeners.
	for relic in _data.current_relics:
		relic.on_removed()
	# WARNING: We can't clear current_relics here, because _data is now owned by a PastRun.
	GlobalAudioSystem.map = null
	Utils.set_active_run(null)

## Getters & Setters

func get_current_season_index() -> int:
	return _data.current_season_index

func get_current_stage() -> Stage:
	return _current_scene as Stage

func get_current_settlement() -> Settlement:
	return _current_settlement

func get_current_stage_index() -> int:
	return _data.current_stage_index

func get_var(type: RunVars.Var) -> int:
	return get_vars().get_current_value(type)

func get_run_data() -> RunData:
	return _data

func get_vars() -> RunVars:
	return _data.vars

func get_top_hud() -> RunTopHud:
	return _top_hud

func get_inspiration_display() -> InspirationDisplay:
	return _top_hud.get_inspiration_display()

func get_run_bonus_listing() -> RunBonusListing:
	return _top_hud.get_run_bonus_listing()

func get_stage_goal_tracker() -> StageGoalTracker:
	return _top_hud.get_stage_goal_tracker()

func get_harmonization_haunting_bar() -> HarmonizationHauntingBar:
	return _top_hud.get_harmonization_haunting_bar()

func get_current_relics() -> Array[Relic]:
	return _data.current_relics if _data else []

func add_relic(relic: Relic) -> void:
	if relic.must_be_unique and find_owned_relic(relic.relic_id):
		push_warning('Tried to add duplicate relic with must_be_unique: ' + relic.relic_id)
		return
	relic = relic.duplicate()  # So the active instance can store state.
	get_current_relics().append(relic)
	relic.on_added(self, true)
	relic.triggered.connect(signals.relic_triggered.emit.bind(relic))
	_relics_gained_this_stage.append(relic)
	GlobalSaveGame.mark_relic_seen(relic)
	signals.relic_added.emit(relic)

func remove_relic(relic: Relic) -> void:
	var matching_relic := find_owned_relic(relic.relic_id)
	assert(matching_relic)
	get_current_relics().erase(matching_relic)
	matching_relic.on_removed()
	matching_relic.triggered.disconnect(signals.relic_triggered.emit.bind(matching_relic))
	_relics_gained_this_stage.erase(relic)
	signals.relic_removed.emit(matching_relic)

func find_owned_relic(relic_id: String) -> Relic:
	for owned_relic in get_current_relics():
		if owned_relic.relic_id == relic_id:
			return owned_relic
	return null

func get_relics_gained_this_stage() -> Array[Relic]:
	return _relics_gained_this_stage.duplicate()

func get_deck_cards() -> Array[CardType]:
	return _data.deck_cards

func add_card_to_deck(card_type: CardType, skip_signal: bool = false) -> void:
	get_deck_cards().append(card_type)
	GlobalSaveGame.mark_card_seen(card_type)
	if not skip_signal:
		signals.card_added.emit(card_type)

func remove_card_from_deck(card_type: CardType) -> void:
	assert(card_type in get_deck_cards())
	get_deck_cards().erase(card_type)
	signals.card_removed.emit(card_type)

func modify_inspiration(delta: int, reason: InspirationChangeReason) -> int:
	signals.pre_inspiration_gained.emit(delta, reason)
	if delta < 0:
		delta = roundi(delta * get_var(RunVars.Var.INSPIRATION_LOSS_PERCENT) / 100.0)
		delta = mini(0, delta + get_var(RunVars.Var.SHIELD))
	elif delta > 0:
		delta = roundi(delta * get_var(RunVars.Var.INSPIRATION_GAIN_PERCENT) / 100.0)
		delta = maxi(0, delta)

	if delta == 0:
		return 0

	if get_var(RunVars.Var.CURRENT_INSPIRATION) <= 0:
		# Can't revive through this.
		return 0

	get_vars().modify_base_value(RunVars.Var.CURRENT_INSPIRATION, delta)
	if delta > 0:
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_INSPIRATION_GAIN)
		signals.inspiration_gained.emit(delta, reason)
	elif delta < 0:
		signals.inspiration_lost.emit(-delta, reason)
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_INSPIRATION_LOST)
		if get_var(RunVars.Var.CURRENT_INSPIRATION) <= 0:
			signals.inspiration_exhausted.emit(reason)

	return delta

func get_bonus_amounts() -> BonusAmounts:
	return _data.bonus_amounts

func gain_bonus(gain: BonusGain) -> void:
	# Apply focus bonuses.
	if not Utils.ensure(gain.amount == gain.original_amount):
		gain.amount = gain.original_amount
	if gain.amount > 0:
		var support := get_var(gain.bonus_type.focus_var)
		if support > 0:
			gain.amount *= 2
		elif support < 0:
			gain.amount /= 2
		gain.amount = roundi(gain.amount * get_var(RunVars.Var.BONUS_GAIN_PERCENT) / 100.0)
	elif gain.amount < 0:
		gain.amount = roundi(gain.amount * get_var(RunVars.Var.BONUS_LOSS_PERCENT) / 100.0)

	signals.pre_bonus_gained.emit(gain)
	if not gain.amount:  # Modified in pre_bonus_gained to eliminate the gain, e.g. by a haunting.
		return
	_data.bonus_amounts.add_amount(gain.bonus_type, gain.amount)

	var stage := get_current_stage()
	if stage:
		stage.grant_stage_bonus(gain.bonus_type, gain.amount)

	if gain.amount > 0:
		signals.bonus_gained.emit(gain.bonus_type, gain.amount, gain.get_reason())
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_NONGOALYIELD_GAIN)
	elif gain.amount < 0:
		signals.bonus_lost.emit(gain.bonus_type, -gain.amount, gain.get_reason())
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_NONGOALYIELD_LOST)

func set_state(new_state: RunData.State) -> void:
	_transition_to_state(new_state)

func get_state() -> RunData.State:
	return _data.state

func get_current_scene() -> Node:
	return _current_scene

func get_current_event_scene() -> EventScene:
	return _current_event_scene

func get_current_card_reward_weights() -> Array[float]:
	return scaling.get_card_tier_weights(get_current_stage_index())

func get_map() -> Map:
	return %Map

func get_unlocked_capital_bonuses() -> Array[BonusType]:
	return _data.unlocked_capital_bonuses

func unlock_capital_bonus(bonus_type: BonusType) -> void:
	if bonus_type not in _data.unlocked_capital_bonuses:
		_data.unlocked_capital_bonuses.append(bonus_type)
		signals.capital_bonuses_changed.emit()

func set_capital_craft_recipe_state(filled_slots: Array[int]) -> void:
	_data.capital_craft_recipe_state = filled_slots

func get_capital_craft_recipe_state() -> Array[int]:
	return _data.capital_craft_recipe_state

func get_capital() -> Capital:
	return _current_capital

func get_settlements() -> Array[Settlement]:
	var result: Array[Settlement]
	for map_object in get_map().get_map_objects():
		if map_object is Settlement:
			result.append(map_object)
	return result

func grant_insights(amount: int) -> void:
	assert(amount >= 0)
	if amount:
		var effective_amount := amount * (1.0 + get_var(RunVars.Var.INSIGHT_EXTRA_PERCENT) / 100.0)
		_data.total_insights_gained += effective_amount
		signals.insights_gained.emit(roundi(effective_amount))

func get_total_insights_gained() -> int:
	return roundi(_data.total_insights_gained)

func get_events_random() -> RandomState:
	return _data.events_random

func get_card_reward_random() -> RandomState:
	return _data.card_reward_random

func get_relic_reward_random() -> RandomState:
	return _data.relic_reward_random

func get_card_deck_random() -> RandomState:
	return _data.card_deck_random

func get_goals_random() -> RandomState:
	return _data.goals_random

func get_innate_cards() -> Array[CardType]:
	return _data.innate_cards.duplicate()  # Wasteful but protects against accidantal writes.

func make_card_innate(card_type: CardType) -> void:
	_data.innate_cards.append(card_type)

func get_reserved_card() -> CardType:
	return _data.reserved_card

func set_reserved_card(card_type: CardType) -> void:
	_data.reserved_card = card_type

func get_settlement_states() -> Array[SettlementState]:
	return _data.settlement_states

func get_events_state() -> EventsState:
	return _data.events_state

func get_current_stage_goal() -> StageGoal:
	if _data.current_settlement_state:
		return _data.current_settlement_state.goal
	else:
		return null

func reroll_stage_goal() -> void:
	assert(get_var(RunVars.Var.GOAL_REROLLS) > 0)
	assert(get_state() == RunData.State.STAGE_SELECTOR)
	var current_goal := _data.current_settlement_state.goal.bonus_requirements.keys()
	current_goal.sort_custom(func(a: BonusType, b: BonusType) -> bool: return a.sort_order < b.sort_order)
	_rerolled_goals.append(current_goal)
	_data.current_settlement_state.goal = _create_stage_goal()
	get_vars().modify_base_value(RunVars.Var.GOAL_REROLLS, -1)
	foray_goal_rerolled.emit()

func record_fow_reveal(point: Vector2i, radius: int) -> void:  # If point = [-1, -1], reveal all.
	_data.fow_reveals[point] = max(_data.fow_reveals.get(point, 0), radius)

func run_or_queue_action(f: Callable) -> void:
	var stage := get_current_stage()
	if stage and stage.is_processing_card():
		stage.queue_action(f)
	else:
		f.call()

func get_insights_from_discoveries() -> int:
	var insights := 0
	if Skill.get_skill_var(Skill.Var.INSIGHTS_FROM_DISCOVERY):
		insights += _data.newly_seen_cards.size()
		insights += _data.newly_seen_relics.size()
		insights += _data.newly_seen_shops.size()
		insights += _data.newly_seen_upgrades.size()
		insights += _data.newly_seen_hauntings.size()
		insights += _data.newly_pacified_hauntings.size()
		insights += _data.newly_seen_event_outcomes.size()
		insights += _data.newly_seen_survey_outcomes.size()
	return insights

## Events

func queue_event(event: Event) -> EventScene:
	var event_scene := EVENT_SCENE.instantiate_loaded_scene() as EventScene
	event_scene.event = event
	_queued_event_scenes.append(event_scene)
	if not _current_event_scene:
		_start_next_event()
	return event_scene

func _start_next_event() -> void:
	assert(not _current_event_scene)
	_current_event_scene = _queued_event_scenes.pop_front()
	_current_event_scene.finished.connect(func() -> void:
		signals.event_finished.emit((_current_event_scene as EventScene).event)
		_current_event_scene.queue_free()
		_current_event_scene = null
		if _queued_event_scenes:
			_start_next_event()
	)
	GlobalUI.add_layer_content(_current_event_scene, UI.Layer.GAME_MENU)
	signals.event_started.emit((_current_event_scene as EventScene).event)

## Shops / Landmark

func open_shop(shop_type: ShopType) -> void:
	Utils.ensure(not _opened_shop)
	_opened_shop = shop_type.scene.instantiate() as ShopBase
	_opened_shop.shop_type = shop_type
	_opened_shop.finished.connect(func() -> void:
		_opened_shop.queue_free()
		_opened_shop = null
	)
	GlobalUI.add_layer_content(_opened_shop, UI.Layer.GAME_MENU)

func notify_shop_transaction(shop_type: ShopType) -> void:
	_data.shop_times_used[shop_type] = _data.shop_times_used.get(shop_type, 0) + 1
	_data.shops_used_this_round[shop_type] = true  # Once a foray/convergence.
	signals.shop_transacted.emit()
	GlobalSaveGame.save_game()

func get_times_used_shop(shop_type: ShopType) -> int:
	return _data.shop_times_used.get(shop_type, 0)

func has_shop_been_used_this_round(shop_type: ShopType) -> bool:
	return _data.shops_used_this_round.get(shop_type, false)

## Internals

func _show_loading() -> void:
	(%LoadingPanel as Control).visible = true
	(%LoadingTimer as Timer).timeout.connect(func() -> void:
		var loading_label := %LoadingLabel as Label
		var total := loading_label.get_total_character_count()
		if loading_label.visible_characters in [-1, total]:
			loading_label.visible_characters = total - 3
		else:
			loading_label.visible_characters += 1
	)
	(%LoadingTimer as Timer).start()

	_top_hud.visible = false
	Utils.set_input_enabled(get_map(), false)
	get_map().view_controls_enabled = false

func _hide_loading() -> void:
	(%LoadingTimer as Timer).stop()
	(%LoadingPanel as Control).visible = false

	_top_hud.visible = true
	Utils.set_input_enabled(get_map(), true)
	get_map().view_controls_enabled = true

func _generate_map() -> void:
	if run_config.map_generation_config:
		get_map().generation_config = run_config.map_generation_config
	_apply_map_overrides()

	await get_map().regenerate(RandomState.new(
		run_config.debug_map_seed if run_config.debug_map_seed else run_config.run_seed,
		_data.card_deck_random.is_legacy() or run_config.force_legacy_random))

	GlobalAudioSystem.map = get_map()

func _apply_map_overrides() -> void:
	var config: MapGenerationConfig = get_map().generation_config

	# Shard first, so quests take precedence.
	if _data.shard_type_affecting_map:
		config = _data.shard_type_affecting_map.apply_map_generation_override(config)

	for quest in _data.quests_affecting_map:
		config = quest.apply_map_generation_override(config)

	get_map().generation_config = config

func _start_new_data() -> void:
	_data = GlobalSaveGame.start_run(run_config)

	if run_config.run_type.scaling_override:
		scaling = run_config.run_type.scaling_override

	_show_loading()
	await _generate_map()
	_hide_loading()

	if GlobalSaveGame.get_main_quest_progress() <= SaveGame.MainQuestProgress.P100_STARTED_RELIGION:
		set_state(RunData.State.STARTER_TUTORIAL)
	else:
		set_state(RunData.State.SEASON_START)

func _resume_from_data(resumed_data: RunData) -> void:
	Utils.ensure(not run_config)
	_data = resumed_data

	run_config = RunConfig.new()
	run_config.companion = GlobalSaveGame.get_current_companion()
	run_config.starting_cards = GlobalSaveGame.get_run_starting_deck()
	run_config.run_type = resumed_data.run_type
	run_config.run_seed = resumed_data.run_seed
	run_config.map_generation_config = resumed_data.map_generation_config

	if run_config.run_type.scaling_override:
		scaling = run_config.run_type.scaling_override

	var starting_state := _data.state
	_data.state = RunData.State.INITIAL

	_show_loading()
	await _generate_map()

	(%LoadingLabel as Label).text = tr('Loading Settlements...')

	for point in _data.fow_reveals:
		if point.x < 0:
			get_map().clear_all_fow()
			break
		else:
			get_map().reveal_fow(point, _data.fow_reveals[point])

	var map_sprite_anim_duration := get_map().get_sprite_renderer().animation_duration
	get_map().get_sprite_renderer().animation_duration = -1  # Skip animations.
	for mod in _data.map_modifications:
		if not await mod.apply(get_map(), false):
			push_warning('Could not replay loaded map modification.')
	get_map().get_sprite_renderer().animation_duration = map_sprite_anim_duration

	for settlement_state in _data.settlement_states:
		var settlement := SETTLEMENT_SCENE.instantiate_loaded_scene() as Settlement
		settlement.state = settlement_state
		settlement.mode = Settlement.Mode.SHOPPABLE
		get_map().add_map_object(settlement)
		get_map().set_map_object_location(settlement, settlement.state.map_location)
	if _data.current_settlement_state and _data.current_settlement_state.map_location.x >= 0:
		var settlement := SETTLEMENT_SCENE.instantiate_loaded_scene() as Settlement
		settlement.state = _data.current_settlement_state
		get_map().add_map_object(settlement)
		get_map().set_map_object_location(settlement, settlement.state.map_location)
		_current_settlement = settlement

	if _data.capital_location.x >= 0:
		_current_capital = CAPITAL_SCENE.instantiate_loaded_scene() as Capital
		_current_capital.map_location = _data.capital_location
		get_map().add_map_object(_current_capital)
		get_map().set_map_object_location(_current_capital, _current_capital.map_location)

	# Rebind relic listeners.
	for relic in _data.current_relics:
		relic.on_added(self, false)
		relic.triggered.connect(signals.relic_triggered.emit.bind(relic))

	_hide_loading()

	_transition_to_state(starting_state)

	if starting_state == RunData.State.STAGE_SELECTOR:
		get_map().focus_location(get_map().get_current_target_position(), 2.4)
	elif starting_state == RunData.State.HARMONIZATION:
		get_map().focus_location(get_capital().map_location, 4)

## Transitions

func _transition_to_state(new_state: RunData.State) -> void:
	if get_state() == new_state:
		return

	if get_var(RunVars.Var.CURRENT_INSPIRATION) <= 0:
		new_state = RunData.State.RUN_LOST

	_data.state = new_state
	_clear_current_scene()
	_transition_recurse_depth += 1
	match _data.state:
		RunData.State.INITIAL:
			assert(false)
		RunData.State.STARTER_TUTORIAL:
			_transition_starter_tutorial()
		RunData.State.SEASON_START:
			_transition_season_start()
		RunData.State.STAGE_SELECTOR:
			_transition_stage_selector()
		RunData.State.STAGE:
			_transition_stage()
		RunData.State.STAGE_END:
			_transition_stage_end()
		RunData.State.STAGE_CARD_REWARD:
			_transition_stage_card_reward()
		RunData.State.SURVEY_SELECTOR:
			_transition_survey_selector()
		RunData.State.SURVEY:
			_transition_survey()
		RunData.State.SURVEY_END:
			_transition_survey_end()
		RunData.State.CAPITAL_PLACEMENT:
			_transition_capital_placement()
		RunData.State.HARMONIZATION:
			_transition_harmonization()
		RunData.State.HARMONIZATION_END:
			_transition_harmonization_end()
		RunData.State.SEASON_END:
			_transition_season_end()
		RunData.State.RUN_LOST:
			_transition_run_lost()
		RunData.State.RUN_WON:
			_transition_run_won()
	_transition_recurse_depth -= 1
	if _transition_recurse_depth == 0:
		state_changed.emit()

func _transition_starter_tutorial() -> void:
	var stage := STAGE_SCENE.instantiate_loaded_scene() as Stage
	stage.mode = Stage.Mode.STARTER_TUTORIAL
	stage.stage_ended.connect(func() -> void:
		set_state(RunData.State.STAGE_SELECTOR)
	)
	_set_current_scene(stage, UI.Layer.GAME)

func _transition_season_start() -> void:
	if _data.current_season_index == 0 and GlobalSaveGame.get_starting_relic():
		add_relic(GlobalSaveGame.get_starting_relic())
		_relics_gained_this_stage.clear()
		set_state(RunData.State.STAGE_SELECTOR)
	elif _data.current_season_index == 0 and Skill.get_skill_var(Skill.Var.RANDOM_STARTING_RELIC):
		var relic_selector := RELIC_SELECTOR_SCENE.instantiate_loaded_scene() as RelicSelector
		var allow_uncommon := Skill.get_skill_var(Skill.Var.UNCOMMON_STARTING_RELIC) > 0
		for relic in GlobalSaveGame.get_seen_relics():
			if relic.rarity == Relic.Rarity.COMMON or (allow_uncommon and relic.rarity == Relic.Rarity.UNCOMMON):
				relic_selector.relic_reward_pool.append(relic)
		if Skill.get_skill_var(Skill.Var.SELECTED_STARTING_RELIC) > 0:
			relic_selector.manual_select = true
		else:
			relic_selector.manual_select = false
			var bead: Relic = load('res://relics/common/talisman_charcoal_bead/relic_talisman_charcoal_bead.tres')
			if GlobalSaveGame.has_seen_relic(bead):
				relic_selector.extra_choices.append(bead)
			var ring: Relic = load('res://relics/common/talisman_copper_ring/relic_talisman_copper_ring.tres')
			if GlobalSaveGame.has_seen_relic(ring):
				relic_selector.extra_choices.append(ring)
			var herbal_bag: Relic = load('res://relics/common/talisman_herbal_scent_bag/relic_talisman_herbal_scent_bag.tres')
			if GlobalSaveGame.has_seen_relic(herbal_bag):
				relic_selector.extra_choices.append(herbal_bag)
			var seed_pouch: Relic = load('res://relics/common/talisman_seed_pouch/relic_talisman_seed_pouch.tres')
			if GlobalSaveGame.has_seen_relic(seed_pouch):
				relic_selector.extra_choices.append(seed_pouch)
		relic_selector.finished.connect(func() -> void:
			_relics_gained_this_stage.clear()
			set_state(RunData.State.STAGE_SELECTOR)
		)
		_set_current_scene(relic_selector, UI.Layer.GAME)
	else:
		set_state(RunData.State.STAGE_SELECTOR)

func _transition_stage_selector() -> void:
	if _data.current_settlement_state:  # If loaded from savegame.
		if not Utils.ensure(_data.current_settlement_state.goal != null):
			_data.current_settlement_state.goal = _create_stage_goal()
		Utils.ensure(_data.current_settlement_state.spot_types.is_empty())
	else:
		_rerolled_goals.clear()
		_data.current_settlement_state = SettlementState.new()
		_data.current_settlement_state.goal = _create_stage_goal()
	GlobalSaveGame.save_game()
	var stage_selector := STAGE_SELECTOR_SCENE.instantiate_loaded_scene() as StageSelector
	stage_selector.mode = StageSelector.Mode.SETTLEMENT
	stage_selector.goal = _data.current_settlement_state.goal
	stage_selector.location_radius = scaling.get_settlement_radius(get_current_stage_index())
	stage_selector.num_spots = scaling.get_num_stage_spots(get_current_stage_index()) + get_var(RunVars.Var.EXTRA_SPOTS)
	stage_selector.location_selected.connect(func(map_location: Vector2) -> void:
		await stage_selector.fade_out()
		_data.current_settlement_state.map_location = map_location
		_data.current_settlement_state.radius = stage_selector.location_radius
		_data.current_settlement_state.spot_types = get_map().get_spot_types_at_position(
			map_location, stage_selector.location_radius, stage_selector.num_spots)
		_current_settlement = SETTLEMENT_SCENE.instantiate_loaded_scene() as Settlement
		_current_settlement.state = _data.current_settlement_state
		get_map().add_map_object(_current_settlement)
		get_map().set_map_object_location(_current_settlement, map_location)
		set_state(RunData.State.STAGE)
	)
	_set_current_scene(stage_selector, UI.Layer.GAME)

func _transition_stage() -> void:
	GlobalSaveGame.save_game()
	var stage := STAGE_SCENE.instantiate_loaded_scene() as Stage
	stage.mode = Stage.Mode.REGULAR
	stage.settlement = _current_settlement
	stage.events = _stage_event_selector.select_events(
			get_events_random(), self, _current_settlement.state.spot_types,
			_current_settlement.state.goal.bonus_requirements.keys())
	for event: Event in stage.events.values():
		event.start_loading_texture()
	stage.stage_ended.connect(func() -> void:
		set_state(RunData.State.STAGE_END)
	)
	_set_current_scene(stage, UI.Layer.GAME)
	signals.stage_started.emit()
	signals.foray_started.emit()

func _transition_stage_end() -> void:
	# No need for bonus change events; already emitted when the bonuses were added to the stage.
	var stage_end := STAGE_END_SCENE.instantiate_loaded_scene() as StageEnd
	stage_end.settlement_state = _current_settlement.state
	stage_end.finished.connect(func() -> void:
		await stage_end.close()
		_current_scene = null  # close() removes the node, so don't try to double-remove it.
		get_settlement_states().append(_current_settlement.state)
		_current_settlement = null
		_data.current_settlement_state = null
		_card_rewards_left = get_var(RunVars.Var.CARD_REWARDS_PER_STAGE)
		_relics_gained_this_stage.clear()
		set_state(RunData.State.STAGE_CARD_REWARD)
	)
	_set_current_scene(stage_end, UI.Layer.STATE_MENU)
	signals.foray_finished.emit(_current_settlement.state)
	signals.stage_finished.emit()

func _transition_stage_card_reward() -> void:
	if not Utils.ensure(_card_rewards_left > 0):
		_card_rewards_left = 1
	_card_rewards_left -= 1
	var card_reward := CARD_REWARD_SCENE.instantiate_loaded_scene() as CardRewardChoice
	card_reward.selection_finished.connect(func() -> void:
		await card_reward.close()
		_current_scene = null  # close() removes the node, so don't try to double-remove it.
		if _card_rewards_left > 0:
			_clear_current_scene()
			_transition_stage_card_reward()
		else:
			_data.current_stage_index += 1
			_data.shops_used_this_round.clear()
			if _data.current_stage_index == scaling.stages_per_season * (1 + _data.current_season_index):
				set_state(RunData.State.CAPITAL_PLACEMENT)
			elif Skill.get_skill_var(Skill.Var.SURVEYS) and _data.current_stage_index % scaling.stages_before_survey == 0:
				set_state(RunData.State.SURVEY_SELECTOR)
			else:
				set_state(RunData.State.STAGE_SELECTOR)
	)
	_set_current_scene(card_reward, UI.Layer.STATE_MENU)

func _transition_survey_selector() -> void:
	GlobalSaveGame.save_game()
	var stage_selector := STAGE_SELECTOR_SCENE.instantiate_loaded_scene() as StageSelector
	stage_selector.mode = StageSelector.Mode.SURVEY
	stage_selector.goal = null
	stage_selector.location_radius = scaling.survey_targeting_radius
	stage_selector.num_spots = 0
	stage_selector.location_selected.connect(func(map_location: Vector2) -> void:
		await stage_selector.fade_out()
		_data.current_survey_location = map_location
		set_state(RunData.State.SURVEY)
	)
	_set_current_scene(stage_selector, UI.Layer.GAME)
	stage_selector._state = StageSelector.State.SELECTING

func _transition_survey() -> void:
	GlobalSaveGame.save_game()
	var stage := STAGE_SCENE.instantiate_loaded_scene() as Stage
	stage.mode = Stage.Mode.SURVEY
	stage.stage_ended.connect(func() -> void:
		set_state(RunData.State.SURVEY_END)
	)
	_set_current_scene(stage, UI.Layer.GAME)
	signals.stage_started.emit()
	signals.survey_started.emit()

func _transition_survey_end() -> void:
	signals.survey_finished.emit()
	signals.stage_finished.emit()
	_data.current_survey_location = Vector2(-1, -1)
	_relics_gained_this_stage.clear()
	_data.shops_used_this_round.clear()  # Arguable, but feels better.
	await get_tree().process_frame  # Make sure state_changed emits SURVEY_END before we change it.
	set_state(RunData.State.STAGE_SELECTOR)

func _transition_capital_placement() -> void:
	GlobalSaveGame.save_game()
	var stage_selector := STAGE_SELECTOR_SCENE.instantiate_loaded_scene() as StageSelector
	stage_selector.mode = StageSelector.Mode.EXISTING_CAPITAL if _current_capital else StageSelector.Mode.CAPITAL
	stage_selector.goal = null
	stage_selector.location_radius = Capital.RADIUS
	stage_selector.num_spots = 0 if _current_capital else 1
	stage_selector.location_selected.connect(func(map_location: Vector2) -> void:
		await stage_selector.fade_out()
		if not _current_capital:
			_data.capital_location = map_location
			_current_capital = CAPITAL_SCENE.instantiate_loaded_scene() as Capital
			_current_capital.map_location = map_location
			_current_capital.mode = Capital.Mode.SETUP
			get_map().add_map_object(_current_capital)
			get_map().set_map_object_location(_current_capital, map_location)
			await _current_capital.reveal()
			var spot_types := get_map().get_spot_types_at_position(map_location, Capital.RADIUS, 1)
			if Skill.get_skill_var(Skill.Var.CAPITAL_INITIAL_PROVISION):
				_data.unlocked_capital_bonuses.append(spot_types[0].granted_capital_bonus)
		set_state(RunData.State.HARMONIZATION)
	)
	_set_current_scene(stage_selector, UI.Layer.GAME)

func _transition_harmonization() -> void:
	GlobalSaveGame.save_game()
	var stage := STAGE_SCENE.instantiate_loaded_scene() as Stage
	stage.mode = Stage.Mode.HARMONIZATION
	stage.stage_ended.connect(func() -> void: set_state(RunData.State.HARMONIZATION_END))
	_set_current_scene(stage, UI.Layer.GAME)
	signals.stage_started.emit()
	signals.harmonization_started.emit()

func _transition_harmonization_end() -> void:
	var harmonization_end: HarmonizationEnd = HARMONIZATION_END_SCENE.instantiate_loaded_scene()
	harmonization_end.finished.connect(func() -> void: set_state(RunData.State.SEASON_END))
	_set_current_scene(harmonization_end, UI.Layer.STATE_MENU)
	signals.harmonization_finished.emit()
	signals.stage_finished.emit()

func _transition_season_end() -> void:
	var season_end: SeasonEnd = SEASON_END_SCENE.instantiate_loaded_scene()
	season_end.finished.connect(func() -> void:
		_data.current_season_index += 1
		_relics_gained_this_stage.clear()
		GlobalSaveGame.increment_date()
		set_state(RunData.State.SEASON_START)
	)
	_set_current_scene(season_end, UI.Layer.STATE_MENU)

func _transition_run_lost() -> void:
	_data.current_settlement_state = null
	GlobalSaveGame.save_game()
	var run_loss := RUN_END_SCENE.instantiate_loaded_scene() as RunEnd
	run_loss.won = false
	run_loss.finished.connect(run_ended.emit)
	_set_current_scene(run_loss, UI.Layer.STATE_MENU)

func _transition_run_won() -> void:
	_data.current_settlement_state = null
	GlobalSaveGame.save_game()
	var run_win := RUN_END_SCENE.instantiate_loaded_scene() as RunEnd
	run_win.won = true
	run_win.finished.connect(run_ended.emit)
	_set_current_scene(run_win, UI.Layer.STATE_MENU)

## Utils

func _create_stage_goal() -> StageGoal:
	var result := StageGoal.new()
	var stage_index := get_current_stage_index()
	var num_types := scaling.get_num_stage_goals(stage_index, get_goals_random())
	if GlobalSaveGame.get_main_quest_progress() < SaveGame.MainQuestProgress.P115_GATHERED_RELICS and stage_index < 5:
		# Special case: avoid 3-type requirements before the player has learned the game.
		num_types = mini(num_types, 2)
	var bonus_types: Array[BonusType]
	if get_current_season_index() == 0 and stage_index == 0 and not _rerolled_goals:
		# Special case: guarantee that the initial goal is satisfiable.
		var starting_spot_type := get_map().get_spot_types_at_position(
				get_map().generated_map.starting_point,
				scaling.get_settlement_radius(stage_index), 1)[0]
		bonus_types.append(StageSatisfiability.get_sorted_spot_bonuses(self, starting_spot_type, true)[0])
	else:
		var candidate_types := get_goals_random().pick_n(BonusType.get_all_types(), num_types)
		if _rerolled_goals:
			candidate_types.sort_custom(func(a: BonusType, b: BonusType) -> bool: return a.sort_order < b.sort_order)
			var tries := 50
			while candidate_types in _rerolled_goals:
				candidate_types = get_goals_random().pick_n(BonusType.get_all_types(), num_types)
				candidate_types.sort_custom(func(a: BonusType, b: BonusType) -> bool: return a.sort_order < b.sort_order)
				tries -= 1
				if not tries:
					break
		bonus_types.assign(candidate_types)

	var total_amount := scaling.get_stage_goal_amount(stage_index)
	var amount_multiplier := get_var(RunVars.Var.STAGE_REQUIREMENTS_PERCENTAGE) / 100.0
	total_amount = roundi(total_amount * amount_multiplier)

	var weights: Array[float]
	var total_weight: float = 0
	for _i in bonus_types.size():
		weights.append(get_goals_random().rand_int(1, 3))
		total_weight += weights[-1]
	for i in bonus_types.size():
		result.bonus_requirements[bonus_types[i]] = roundi(weights[i] / total_weight * total_amount)

	return result

func _clear_current_scene() -> void:
	if _current_scene:
		# WARNING: Some code relies on _exit_tree() being called between run state transitions.
		#          E.g. StageSelector.
		_current_scene.get_parent().remove_child(_current_scene)
		_current_scene.queue_free()
		_current_scene = null

func _set_current_scene(scene: Node, layer: UI.Layer) -> void:
	_current_scene = scene
	GlobalUI.add_layer_content(_current_scene, layer)

# Debug Tools

func debug_create_settlement(map_location: Vector2, radius: int = 20, num_spots: int = 2, set_current: bool = true) -> Settlement:
	var settlement_state := SettlementState.new()
	settlement_state.goal = _create_stage_goal()
	settlement_state.map_location = map_location
	settlement_state.radius = radius
	settlement_state.spot_types = get_map().get_spot_types_at_position(map_location, radius, num_spots)
	var settlement := SETTLEMENT_SCENE.instantiate_loaded_scene() as Settlement
	settlement.state = settlement_state
	get_map().add_map_object(settlement)
	get_map().set_map_object_location(settlement, map_location)
	if set_current:
		_data.current_settlement_state = settlement_state
		_current_settlement = settlement
	return settlement
