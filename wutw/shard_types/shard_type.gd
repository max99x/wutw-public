@tool
@abstract
class_name ShardType
extends Resource

enum Tier { COMMON, UNCOMMON, RARE, MAIN_QUEST }

@export var shard_type_id: String
@export var name: String
@export var shard_name_override: String
@export var shard_name_override_jp: String
@export var shard_name_override_meaning: String
@export var tier: Tier
@export var illustration: Texture2D
@export var illustration_credit: ArtPiece
@export var history: Array[ShardTypeHistory]
@export var trip_reward: TripReward
@export var trip_reward_overrides: Array[TripRewardOverride]
@export var min_main_quest_progress: SaveGame.MainQuestProgress = SaveGame.MainQuestProgress.P000_INTRO

static var _shard_type_group_loader := AsyncLoadedGroup.new('res://shard_types/resourcegroup_shard_types.tres')
static var _all_shard_types: Dictionary[String, ShardType] = {}

## <0: impossible to achieve from current state
## (0, 1): progress made, not achieved yet
## >= 1: achieved, higher values prioritize vs other shard types
@abstract func score_requirement(run_data: RunData, index: int) -> float
@abstract func describe_requirements() -> Array[String]

static func get_all_shard_types() -> Dictionary[String, ShardType]:
	if not _all_shard_types:
		for shard_type: ShardType in _shard_type_group_loader.get_loaded():
			_all_shard_types[shard_type.shard_type_id] = shard_type
	return _all_shard_types

static func get_shard_type_by_id(id: String) -> ShardType:
	return get_all_shard_types().get(id, null)

static func choose_shard_type(run_data: RunData) -> ShardType:
	var best_shard_type: ShardType
	var best_shard_type_score: float = -1
	for shard_type: ShardType in ShardType.get_all_shard_types().values():
		if GlobalSaveGame.is_shard_type_unlocked(shard_type):
			continue  # Already assigned.
		elif shard_type.min_main_quest_progress > GlobalSaveGame.get_main_quest_progress():
			continue  # Not yet accessible.
		var current_score := shard_type.score(run_data)
		if current_score >= 1:
			if shard_type.tier == ShardType.Tier.MAIN_QUEST:
				current_score *= 1_000_000.0
			elif GlobalSaveGame.get_pinned_shard_type() == shard_type:
				current_score *= 100.0
		if current_score > best_shard_type_score:
			best_shard_type = shard_type
			best_shard_type_score = current_score
	if best_shard_type_score >= 1:
		return best_shard_type
	else:
		return null

func score(run_data: RunData) -> float:
	var reqs := describe_requirements()
	var result := 0.0
	var all_satisfied := true
	for i in reqs.size():
		var req_score := score_requirement(run_data, i)
		if req_score < 0:
			return -1
		if req_score < 1:
			all_satisfied = false
		result += req_score
	var final_score := result / reqs.size()
	if all_satisfied:
		return max(1.0, final_score)
	else:
		return min(0.99, final_score)

func apply_map_generation_override(config: MapGenerationConfig) -> MapGenerationConfig:
	return config

func format_history_text(index: int, past_run: PastRun, text_override: String = '') -> String:
	var text: String
	if text_override:
		text = text_override
	else:
		text = history[index].text
		var overridden := false
		for override in history[index].overrides:
			if override.requirement.is_satisfied(null, null):
				text = override.text
				if overridden:
					push_warning('Multiple shard history overrides apply. Taking the last one. ID: ', shard_type_id)
				overridden = true

	var replacements: Dictionary[String, String] = {
		'$shard_name': '[b]' + past_run.get_native_shard_display_name() + '[/b]',
		'$town1': '[b]' + past_run.get_random_town_name(0).get_native_display_name() + '[/b]',
	}
	if past_run.run_data.settlement_states.size() > 1:
		replacements['$town2'] = '[b]' + past_run.get_random_town_name(1).get_native_display_name() + '[/b]'
	if past_run.run_data.settlement_states.size() > 2:
		replacements['$town3'] = '[b]' + past_run.get_random_town_name(2).get_native_display_name() + '[/b]'
	if past_run.run_data.settlement_states.size() > 3:
		replacements['$town4'] = '[b]' + past_run.get_random_town_name(3).get_native_display_name() + '[/b]'
	return _apply_replacements(text, replacements)

func _apply_replacements(raw_text: String, replacements: Dictionary[String, String]) -> String:
	var result := raw_text
	for pattern in replacements:
		result = result.replace(pattern, replacements[pattern])
	return result

func _has_finished_event(run_data: RunData, event: Event) -> bool:
	if event.has_triggered(run_data):
		if Utils.get_active_run():
			if Utils.get_active_run().get_current_event_scene():
				if Utils.get_active_run().get_current_event_scene().event == event:
					return false
		return true
	else:
		return false

func get_ensured_upgrades() -> Array[SpotUpgrade]:
	return []
