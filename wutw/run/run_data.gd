class_name RunData
extends RefCounted

## WARNING: Should only be accessed through methods of Run.

var run_type: RunType
var run_seed: int = 0
var map_generation_config: MapGenerationConfig
var quests_affecting_map: Array[Quest]
var shard_type_affecting_map: ShardType

# WARNING: These are stored in savegames as int values.
enum State {
	INITIAL,
	SEASON_START,
	STAGE_SELECTOR,
	STAGE,
	STAGE_END,
	STAGE_CARD_REWARD,
	CAPITAL_PLACEMENT,
	HARMONIZATION,
	HARMONIZATION_END,
	SEASON_END,
	RUN_LOST,
	RUN_WON,
	STARTER_TUTORIAL,
	SURVEY_SELECTOR,
	SURVEY,
	SURVEY_END,
}
var state: State = State.INITIAL

var current_season_index: int = -1
var current_stage_index: int = -1
var current_settlement_state: SettlementState

var playtime: float = 0
var vars: RunVars = RunVars.new()
var deck_cards: Array[CardType] = []
var innate_cards: Array[CardType] = []
var reserved_card: CardType
var current_relics: Array[Relic] = []
var bonus_amounts: BonusAmounts = BonusAmounts.new()
var settlement_states: Array[SettlementState] = []
var capital_location: Vector2 = Vector2(-1, -1)
var current_survey_location: Vector2 = Vector2(-1, -1)
var unlocked_capital_bonuses: Array[BonusType] = []
var capital_craft_recipe_state: Array[int] = []
var shop_times_used: Dictionary[ShopType, int] = {}
var shops_used_this_round: Dictionary[ShopType, bool] = {}
var total_insights_gained: float = 0  # Float so % bonuses accumulate.
var haunting_leftover_roll: float = 0
var fow_reveals: Dictionary[Vector2i, int] = {}
var map_modifications: Array[MapModification]
var finished_episodes: Dictionary[int, Array] = {}  # key is stage index; value is one Array[SurveyEpisode]
var used_episodes: Dictionary[SurveyEpisode, bool]
var recent_hauntings: Dictionary[HauntingType, int]  # Value is stage index of most recent spawn.
var encountered_hauntings: Dictionary[HauntingType, int]
var pacified_hauntings: Dictionary[HauntingType, int]
var extra_hauntings: Array[HauntingType]  # In forays only.
## The state of events stored per-run.
var events_state: EventsState = EventsState.new()

var events_random: RandomState = RandomState.new()
var card_reward_random: RandomState = RandomState.new()
var relic_reward_random: RandomState = RandomState.new()
var card_deck_random: RandomState = RandomState.new()
var goals_random: RandomState = RandomState.new()

# Tracking things newly discovered this run.
# This is just for the end run display and bonus insights;
# metaprogression is tracked directly in SaveGame.
var newly_seen_cards: Array[CardType] = []
var newly_seen_relics: Array[Relic] = []
var newly_seen_shops: Array[ShopType] = []
var newly_seen_upgrades: Array[SpotUpgrade] = []
var newly_seen_hauntings: Array[HauntingType] = []
var newly_pacified_hauntings: Array[HauntingType] = []
var newly_seen_event_outcomes: Array[Event] = []
var newly_seen_survey_outcomes: Array[SurveyEpisode] = []
var newly_completed_settler_quests: Array[Quest_Settler] = []

static func create(run_config: RunConfig) -> RunData:
	if not Utils.ensure(run_config.run_seed > 0):
		run_config.run_seed = randi_range(0, 10000)

	var result := RunData.new()

	result.run_type = run_config.run_type
	result.run_seed = run_config.run_seed
	result.map_generation_config = run_config.map_generation_config
	result.quests_affecting_map = []
	for quest_instance in GlobalSaveGame.get_all_quest_instances():
		if quest_instance.is_active():
			result.quests_affecting_map.append(quest_instance.get_quest())
	result.shard_type_affecting_map = GlobalSaveGame.get_pinned_shard_type()
	result.events_random = RandomState.new(run_config.run_seed)
	result.card_reward_random = RandomState.new(run_config.run_seed)
	result.relic_reward_random = RandomState.new(run_config.run_seed)
	result.card_deck_random = RandomState.new(run_config.run_seed)
	result.goals_random = RandomState.new(run_config.run_seed)
	result.vars.modify_base_value(RunVars.Var.CARD_REWARD_REROLLS, Skill.get_skill_var(Skill.Var.CARD_REWARD_REROLLS))
	result.vars.modify_base_value(RunVars.Var.RELIC_REWARD_REROLLS, Skill.get_skill_var(Skill.Var.RELIC_REWARD_REROLLS))
	result.vars.modify_base_value(RunVars.Var.CARD_TIER_BONUS_PERCENT, Skill.get_skill_var(Skill.Var.CARD_TIER_BONUS_PERCENT))
	result.vars.modify_base_value(RunVars.Var.MAX_INSPIRATION, Skill.get_skill_var(Skill.Var.MAX_INSPIRATION))
	result.vars.set_base_value(RunVars.Var.CURRENT_INSPIRATION, result.vars.get_base_value(RunVars.Var.MAX_INSPIRATION))
	result.vars.modify_base_value(RunVars.Var.MAX_EVENTS_PER_STAGE, Skill.get_skill_var(Skill.Var.EVENTS_PER_STAGE))
	result.vars.modify_base_value(RunVars.Var.HEAL_PER_STAGE, Skill.get_skill_var(Skill.Var.HEAL_PER_STAGE))
	result.vars.modify_base_value(RunVars.Var.GOAL_REROLLS, Skill.get_skill_var(Skill.Var.GOAL_REROLLS))
	result.vars.modify_base_value(RunVars.Var.MIN_DECK_SIZE, -Skill.get_skill_var(Skill.Var.MIN_DECK_SIZE_REDUCTION))
	result.vars.modify_base_value(RunVars.Var.HAUNTING_PACIFIES, Skill.get_skill_var(Skill.Var.HAUNTING_PACIFIES))
	result.vars.modify_base_value(RunVars.Var.PLACE_SMALL_BUILDING_COUNT, Skill.get_skill_var(Skill.Var.CREATE_SMALL_BUILDING))
	result.vars.modify_base_value(RunVars.Var.PLACE_LARGE_BUILDING_COUNT, Skill.get_skill_var(Skill.Var.CREATE_LARGE_BUILDING))
	result.vars.modify_base_value(RunVars.Var.PLACE_SQUARE_COUNT, Skill.get_skill_var(Skill.Var.CREATE_SQUARE))
	result.vars.modify_base_value(RunVars.Var.PLACE_LAKE_COUNT, Skill.get_skill_var(Skill.Var.CREATE_LAKE))
	result.vars.modify_base_value(RunVars.Var.CARD_TIER_BONUS_PERCENT, GlobalSaveGame.get_num_shard_types_unlocked())
	result.vars.modify_base_value(RunVars.Var.MULLIGANS, Skill.get_skill_var(Skill.Var.MULLIGANS))
	result.vars.modify_base_value(RunVars.Var.REVEAL_RADIUS_PERCENT, Skill.get_skill_var(Skill.Var.REVEAL_SIZE_BONUS))
	result.vars.modify_base_value(RunVars.Var.EXTRA_SPOTS, Skill.get_skill_var(Skill.Var.EXTRA_SPOTS))
	result.deck_cards = run_config.starting_cards.duplicate()
	result.current_season_index = 0
	result.current_stage_index = 0

	return result

func encode() -> Dictionary:
	var result := {} as Dictionary[String, Variant]

	result['playtime'] = playtime
	result['run_type'] = run_type.resource_path
	result['run_seed'] = run_seed
	if map_generation_config:
		result['map_generation_config'] = map_generation_config.resource_path
	result['quests_affecting_map'] = []
	for quest in quests_affecting_map:
		(result['quests_affecting_map'] as Array).append(quest.quest_id)
	if shard_type_affecting_map:
		result['shard_type_affecting_map'] = shard_type_affecting_map.shard_type_id

	result['state'] = state as int
	result['current_season_index'] = current_season_index
	result['current_stage_index'] = current_stage_index
	if current_settlement_state:
		result['current_settlement'] = current_settlement_state.encode()
	result['vars'] = vars.encode()

	var deck_symbols := PackedStringArray()
	for card_type in deck_cards:
		deck_symbols.append(card_type.symbol)
	result['deck_cards'] = ''.join(deck_symbols)

	var innate_symbols := PackedStringArray()
	for card_type in innate_cards:
		innate_symbols.append(card_type.symbol)
	result['innate_cards'] = ''.join(innate_symbols)

	if reserved_card:
		result['reserved_card'] = reserved_card.symbol

	var encoded_relics := []
	for relic in current_relics:
		encoded_relics.append({
			'id': relic.relic_id,
			'data': relic.save_data(),
		})
	result['relics'] = encoded_relics

	result['bonus_amounts'] = bonus_amounts.encode()

	result['settlements'] = []
	for settlement_state in settlement_states:
		(result['settlements'] as Array).append(settlement_state.encode())

	result['capital_location'] = [capital_location.x, capital_location.y]
	var encoded_capital_bonuses: Array[String] = []
	for bonus_type in unlocked_capital_bonuses:
		encoded_capital_bonuses.append(bonus_type.bonus_type_id)
	result['capital_bonuses'] = encoded_capital_bonuses
	result['capital_craft_recipe_state'] = capital_craft_recipe_state

	result['current_survey_location'] = [current_survey_location.x, current_survey_location.y]

	var encoded_shop_times_used := {}
	for shop_type in shop_times_used:
		encoded_shop_times_used[shop_type.shop_id] = shop_times_used[shop_type]
	result['shop_times_used'] = encoded_shop_times_used

	var encoded_shop_used_this_round := {}
	for shop_type in shops_used_this_round:
		encoded_shop_used_this_round[shop_type.shop_id] = shops_used_this_round[shop_type]
	result['shops_used_this_round'] = encoded_shop_used_this_round

	var encoded_reveals := []
	for fow_point in fow_reveals:
		var radius := fow_reveals[fow_point]
		encoded_reveals.append([fow_point.x, fow_point.y, radius])
	result['fow_reveals'] = encoded_reveals

	result['total_insights_gained'] = total_insights_gained
	result['haunting_leftover_roll'] = haunting_leftover_roll

	var encoded_map_modifications := []
	for map_modification in map_modifications:
		encoded_map_modifications.append(map_modification.encode())
	result['map_modifications'] = encoded_map_modifications

	var encoded_finished_episodes := {}
	for stage_index in finished_episodes:
		var episodes := finished_episodes[stage_index]
		var encoded_list: Array[String]
		for episode: SurveyEpisode in episodes:
			encoded_list.append(episode.episode_id)
		encoded_finished_episodes[stage_index] = encoded_list
	result['finished_episodes'] = encoded_finished_episodes

	var encoded_used_episodes := []
	for episode in used_episodes:
		encoded_used_episodes.append(episode.episode_id)
	result['used_episodes'] = encoded_used_episodes

	var encoded_recent_hauntings := {}
	for haunting_type in recent_hauntings:
		encoded_recent_hauntings[haunting_type.haunting_id] = recent_hauntings[haunting_type]
	result['recent_hauntings'] = encoded_recent_hauntings

	var encoded_encountered_hauntings := {}
	for haunting_type in encountered_hauntings:
		encoded_encountered_hauntings[haunting_type.haunting_id] = encountered_hauntings[haunting_type]
	result['encountered_hauntings'] = encoded_encountered_hauntings

	var encoded_pacified_hauntings := {}
	for haunting_type in pacified_hauntings:
		encoded_pacified_hauntings[haunting_type.haunting_id] = pacified_hauntings[haunting_type]
	result['pacified_hauntings'] = encoded_pacified_hauntings

	var encoded_extra_hauntings: Array[String]
	for haunting_type in extra_hauntings:
		encoded_extra_hauntings.append(haunting_type.haunting_id)
	result['extra_hauntings'] = encoded_extra_hauntings

	result['events_state'] = events_state.to_flat()

	result['events_random'] = events_random.encode()
	result['card_reward_random'] = card_reward_random.encode()
	result['relic_reward_random'] = relic_reward_random.encode()
	result['card_deck_random'] = card_deck_random.encode()
	result['goals_random'] = goals_random.encode()

	result['newly_seen_cards'] = ''.join(newly_seen_cards.map(func(c: CardType) -> String: return c.symbol))
	result['newly_seen_relics'] = newly_seen_relics.map(func(r: Relic) -> String: return r.relic_id)
	result['newly_seen_shops'] = newly_seen_shops.map(func(s: ShopType) -> String: return s.shop_id)
	result['newly_seen_upgrades'] = newly_seen_upgrades.map(func(u: SpotUpgrade) -> String: return u.spot_upgrade_id)
	result['newly_seen_hauntings'] = newly_seen_hauntings.map(func(h: HauntingType) -> String: return h.haunting_id)
	result['newly_pacified_hauntings'] = newly_pacified_hauntings.map(func(h: HauntingType) -> String: return h.haunting_id)
	result['newly_seen_event_outcomes'] = newly_seen_event_outcomes.map(func(e: Event) -> String: return e.event_id)
	result['newly_seen_survey_outcomes'] = newly_seen_survey_outcomes.map(func(e: SurveyEpisode) -> String: return e.episode_id)
	result['newly_completed_settler_quests'] = newly_completed_settler_quests.map(func(q: Quest_Settler) -> String: return q.quest_id)

	return result

static func decode(encoded_data: Dictionary) -> RunData:
	var result := RunData.new()

	result.playtime = encoded_data.get('playtime', 0.0) as float
	result.run_type = load(encoded_data['run_type'] as String) as RunType
	result.run_seed = encoded_data['run_seed'] as int

	if encoded_data.get('map_generation_config', []):
		result.map_generation_config = load(encoded_data['map_generation_config'] as String) as MapGenerationConfig
	for quest_id: String in encoded_data.get('quests_affecting_map', []) as Array:
		var quest := Quest.get_quest_by_id(quest_id)
		if Utils.ensure(quest != null):
			result.quests_affecting_map.append(quest)
	var shard_type_affecting_map_id := encoded_data.get('shard_type_affecting_map', '') as String
	if shard_type_affecting_map_id:
		result.shard_type_affecting_map = ShardType.get_shard_type_by_id(shard_type_affecting_map_id)

	result.state = encoded_data['state'] as State
	result.current_season_index = encoded_data['current_season_index'] as int
	result.current_stage_index = encoded_data['current_stage_index'] as int
	if encoded_data.has('current_settlement'):
		result.current_settlement_state = SettlementState.new()
		result.current_settlement_state.decode(encoded_data['current_settlement'] as Dictionary)
	result.vars.decode(encoded_data['vars'] as Dictionary)

	for card_symbol: String in encoded_data['deck_cards']:
		var card_type := CardType.get_card_type_by_name_or_symbol(card_symbol)
		if not card_type:
			push_warning('Savegame contains unrecognized deck card (%s). Skipping.' % card_symbol)
			continue
		result.deck_cards.append(card_type)

	for card_symbol: String in encoded_data['innate_cards']:
		var card_type := CardType.get_card_type_by_name_or_symbol(card_symbol)
		if not card_type:
			push_warning('Savegame contains unrecognized innate card (%s). Skipping.' % card_symbol)
			continue
		result.innate_cards.append(card_type)

	if encoded_data.has('reserved_card'):
		result.reserved_card = CardType.get_card_type_by_name_or_symbol(encoded_data['reserved_card'] as String)
		if not result.reserved_card:
			push_warning('Savegame contains unrecognized reserved card (%s). Skipping.' % encoded_data['reserved_card'])

	var encoded_relics: Variant = encoded_data['relics']
	if encoded_relics is Dictionary:  # Backward-compatibility
		var converted := []
		for relic_id: String in encoded_data['relics']:
			converted.append({'id': relic_id, 'data': encoded_data['relics'][relic_id]})
		encoded_relics = converted
	for encoded_relic: Dictionary in encoded_relics:
		var relic_id := encoded_relic['id'] as String
		var relic_data := encoded_relic['data'] as Dictionary
		var relic := Relic.get_relic_by_id(relic_id)
		if not relic:
			push_warning('Savegame contains unrecognized relic (%s). Skipping.' % relic_id)
			continue
		relic = relic.duplicate()
		relic.load_data(relic_data as Dictionary)
		result.current_relics.append(relic)

	result.bonus_amounts.decode(encoded_data['bonus_amounts'] as Dictionary)

	for encoded_settlement_state: Dictionary in encoded_data['settlements']:
		var settlement_state := SettlementState.new()
		settlement_state.decode(encoded_settlement_state)
		result.settlement_states.append(settlement_state)

	result.capital_location.x = encoded_data['capital_location'][0] as float
	result.capital_location.y = encoded_data['capital_location'][1] as float
	for bonus_type_id: String in encoded_data['capital_bonuses']:
		result.unlocked_capital_bonuses.append(BonusType.get_bonus_type_by_id(bonus_type_id))
	result.capital_craft_recipe_state.assign(
		encoded_data.get('capital_craft_recipe_state', []) as Array)

	if 'current_survey_location' in encoded_data:
		result.current_survey_location.x = encoded_data['current_survey_location'][0] as float
		result.current_survey_location.y = encoded_data['current_survey_location'][1] as float

	for shop_type_id: String in encoded_data['shop_times_used']:
		result.shop_times_used[ShopType.get_shop_type_by_id(shop_type_id)] = encoded_data['shop_times_used'][shop_type_id] as int

	for shop_type_id: String in encoded_data['shops_used_this_round']:
		result.shops_used_this_round[ShopType.get_shop_type_by_id(shop_type_id)] = encoded_data['shops_used_this_round'][shop_type_id] as bool

	result.total_insights_gained = encoded_data['total_insights_gained'] as float
	result.haunting_leftover_roll = encoded_data.get('haunting_leftover_roll', 0.0) as float

	for encoded_fow_reveal: Array in encoded_data['fow_reveals']:
		var fow_point := Vector2i(encoded_fow_reveal[0] as int, encoded_fow_reveal[1] as int)
		result.fow_reveals[fow_point] = encoded_fow_reveal[2] as int

	for encoded_modification: Dictionary in encoded_data.get('map_modifications', []):
		result.map_modifications.append(MapModification.decode(encoded_modification))

	var encoded_finished_episodes := encoded_data.get('finished_episodes', {}) as Dictionary
	for stage_index_str: String in encoded_finished_episodes:
		var episode_ids := encoded_finished_episodes[stage_index_str] as Array
		var stage_index := stage_index_str.to_int()
		var episodes: Array[SurveyEpisode]
		for episode_id: String in episode_ids:
			episodes.append(SurveyEpisode.get_episode_by_id(episode_id))
		result.finished_episodes[stage_index] = episodes

	for episode_id: String in encoded_data.get('used_episodes', []):
		result.used_episodes[SurveyEpisode.get_episode_by_id(episode_id)] = true

	var encoded_recent_hauntings := encoded_data.get('recent_hauntings', {}) as Dictionary
	for haunting_id: String in encoded_recent_hauntings:
		result.recent_hauntings[HauntingType.get_haunting_type_by_id(haunting_id)] = encoded_recent_hauntings[haunting_id]

	var encoded_encountered_hauntings := encoded_data.get('encountered_hauntings', {}) as Dictionary
	for haunting_id: String in encoded_encountered_hauntings:
		result.encountered_hauntings[HauntingType.get_haunting_type_by_id(haunting_id)] = encoded_encountered_hauntings[haunting_id]

	var encoded_pacified_hauntings := encoded_data.get('pacified_hauntings', {}) as Dictionary
	for haunting_id: String in encoded_pacified_hauntings:
		result.pacified_hauntings[HauntingType.get_haunting_type_by_id(haunting_id)] = encoded_pacified_hauntings[haunting_id]

	var encoded_extra_hauntings := encoded_data.get('extra_hauntings', []) as Array
	for haunting_id: String in encoded_extra_hauntings:
		result.extra_hauntings.append(HauntingType.get_haunting_type_by_id(haunting_id))

	result.events_state.load_from_flat(encoded_data['events_state'] as Dictionary)

	result.events_random.decode(encoded_data['events_random'] as String)
	result.card_reward_random.decode(encoded_data['card_reward_random'] as String)
	result.relic_reward_random.decode(encoded_data['relic_reward_random'] as String)
	result.card_deck_random.decode(encoded_data['card_deck_random'] as String)
	result.goals_random.decode(encoded_data['goals_random'] as String)

	result.newly_seen_cards.assign(Array((encoded_data.get('newly_seen_cards', '') as String).split('', false))
		.map(CardType.get_card_type_by_name_or_symbol))
	result.newly_seen_relics.assign((encoded_data.get('newly_seen_relics', []) as Array)
		.map(Relic.get_relic_by_id))
	result.newly_seen_shops.assign((encoded_data.get('newly_seen_shops', []) as Array)
		.map(ShopType.get_shop_type_by_id))
	result.newly_seen_upgrades.assign((encoded_data.get('newly_seen_upgrades', []) as Array)
		.map(SpotUpgrade.get_spot_upgrade_by_id))
	result.newly_seen_hauntings.assign((encoded_data.get('newly_seen_hauntings', []) as Array)
		.map(HauntingType.get_haunting_type_by_id))
	result.newly_pacified_hauntings.assign((encoded_data.get('newly_pacified_hauntings', []) as Array)
		.map(HauntingType.get_haunting_type_by_id))
	result.newly_seen_event_outcomes.assign((encoded_data.get('newly_seen_event_outcomes', []) as Array)
		.map(Event.get_event_by_id))
	result.newly_seen_survey_outcomes.assign((encoded_data.get('newly_seen_survey_outcomes', []) as Array)
		.map(SurveyEpisode.get_episode_by_id))
	result.newly_completed_settler_quests.assign((encoded_data.get('newly_completed_settler_quests', []) as Array)
		.map(Quest.get_quest_by_id))

	return result
