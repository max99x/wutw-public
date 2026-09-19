class_name QuestList
extends PanelContainer

static var QUEST_ENTRY_SCENE := AsyncLoadedResource.new('res://quests/list/quest_entry.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

@export var max_size: float = 400

@onready var _shard_type_entry := %ShardTypeEntry as ShardTypeEntry

func _ready() -> void:
	Utils.clear_node(%List)
	var quest_instances: Array[QuestInstance]
	for instance: QuestInstance in GlobalSaveGame.get_all_quest_instances():
		if instance.is_active():
			quest_instances.append(instance)
	quest_instances.sort_custom(func(a: QuestInstance, b: QuestInstance) -> bool:
		return a.get_quest().category < b.get_quest().category
	)
	for instance in quest_instances:
		var quest_entry := QUEST_ENTRY_SCENE.instantiate_loaded_scene() as QuestEntry
		quest_entry.quest_instance = instance
		%List.add_child(quest_entry)

	_update_pinned_shard()

func _enter_tree() -> void:
	GlobalSaveGame.changed.connect(_update_pinned_shard)

func _exit_tree() -> void:
	GlobalSaveGame.changed.disconnect(_update_pinned_shard)

func _update_pinned_shard() -> void:
	if is_node_ready():
		_shard_type_entry.shard_type = GlobalSaveGame.get_pinned_shard_type()
		_shard_type_entry.visible = _shard_type_entry.shard_type != null
		if _shard_type_entry.shard_type:
			var run := Utils.get_active_run()
			_shard_type_entry.will_use_main_quest_shard_type = false
			if _shard_type_entry.shard_type.tier != ShardType.Tier.MAIN_QUEST:
				for shard_type: ShardType in ShardType.get_all_shard_types().values():
					if shard_type.tier != ShardType.Tier.MAIN_QUEST:
						continue
					if shard_type.min_main_quest_progress > GlobalSaveGame.get_main_quest_progress():
						continue  # Not possible yet.
					if GlobalSaveGame.is_shard_type_unlocked(shard_type):
						continue
					if shard_type.score(run.get_run_data()) >= 1.0:
						_shard_type_entry.will_use_main_quest_shard_type = true
						break
		(%ScrollPanel as Control).visible = %List.get_child_count() > 0 or _shard_type_entry.shard_type
	await get_tree().process_frame  # Wait for size to update.
	(%Scroller as ScrollContainer).custom_minimum_size.y = min(max_size, (%ScrollerContents as Control).size.y)
