class_name LikelyShardTypesList
extends Node2D

static var SHARD_TYPE_ENTRY_SCENE := AsyncLoadedResource.new('res://quests/list/shard_type_entry.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

var _closing: bool

func _ready() -> void:
	var run := Utils.get_active_run()
	var potential_shard_types: Array[ShardType]
	var will_use_main_quest_shard_type := false
	var scores: Dictionary[ShardType, float]
	for shard_type: ShardType in ShardType.get_all_shard_types().values():
		if shard_type.min_main_quest_progress > GlobalSaveGame.get_main_quest_progress():
			continue  # Not possible yet, so hide it.
		if GlobalSaveGame.is_shard_type_unlocked(shard_type):
			continue
		scores[shard_type] = shard_type.score(run.get_run_data())
		if shard_type.tier == ShardType.Tier.MAIN_QUEST and scores[shard_type] >= 1.0:
			will_use_main_quest_shard_type = true
		potential_shard_types.append(shard_type)
	potential_shard_types.sort_custom(func(a: ShardType, b: ShardType) -> bool:
		var a_score := scores[a]
		var b_score := scores[b]
		if a_score == b_score:
			return a.tier < b.tier
		else:
			return a_score > b_score
	)

	Utils.clear_node(%TypesList)
	for shard_type in potential_shard_types:
		var entry := SHARD_TYPE_ENTRY_SCENE.instantiate_loaded_scene() as ShardTypeEntry
		entry.shard_type = shard_type
		entry.will_use_main_quest_shard_type = will_use_main_quest_shard_type
		entry.show_pin_button = true
		%TypesList.add_child(entry)

	(%ScrollPanel as ScrollPanel).animate_unroll()

func _handle_esc() -> bool:
	_close()
	return true

func _on_close_button_pressed() -> void:
	_close()

func _close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		queue_free()

func _on_search_input_text_changed(query_text: String) -> void:
	for entry: ShardTypeEntry in %TypesList.get_children():
		var search_text := entry.shard_type.describe_requirements().duplicate()
		search_text.append(tr(entry.shard_type.name))
		entry.visible = Utils.matches_query(search_text, query_text)
