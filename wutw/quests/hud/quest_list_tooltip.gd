@tool
class_name QuestListTooltip
extends Tooltip

static var QUEST_ENTRY_SCENE := AsyncLoadedResource.new('res://quests/list/quest_entry.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var SHARD_TYPE_ENTRY_SCENE := AsyncLoadedResource.new('res://quests/list/shard_type_entry.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

signal close_requested

@export var max_size: float = 400

var interactive: bool = false:
	set(value):
		interactive = value
		if is_node_ready():
			if interactive:
				_setup_interactive()
			else:
				_setup_static()

func _ready() -> void:
	super._ready()

	if not Utils.is_in_editor():
		Utils.clear_node(%QuestList)
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
			%QuestList.add_child(quest_entry)
		if GlobalSaveGame.get_pinned_shard_type():
			var run := Utils.get_active_run()
			var shard_type_entry := SHARD_TYPE_ENTRY_SCENE.instantiate_loaded_scene() as ShardTypeEntry
			shard_type_entry.shard_type = GlobalSaveGame.get_pinned_shard_type()
			if shard_type_entry.shard_type.tier != ShardType.Tier.MAIN_QUEST:
				for shard_type: ShardType in ShardType.get_all_shard_types().values():
					if shard_type.tier != ShardType.Tier.MAIN_QUEST:
						continue
					if shard_type.min_main_quest_progress > GlobalSaveGame.get_main_quest_progress():
						continue  # Not possible yet.
					if GlobalSaveGame.is_shard_type_unlocked(shard_type):
						continue
					if shard_type.score(run.get_run_data()) >= 1.0:
						shard_type_entry.will_use_main_quest_shard_type = true
						break
			%QuestList.add_child(shard_type_entry)
		if not %QuestList.get_child_count():
			var message := Label.new()
			message.text = tr('No quests are currently active.')
			message.add_theme_font_size_override('font_size', roundi(16 * GameSettings.Interface.tooltip_font_scale.value()))
			%QuestList.add_child(message)
		await get_tree().process_frame  # Wait for size to update.
		(%Scroller as ScrollContainer).custom_minimum_size.y = min(max_size, (%QuestList as Control).size.y)

		interactive = interactive  # Trigger setup.

func _process(_delta: float) -> void:
	if not Utils.is_in_editor():
		if GlobalUI.is_higher_level_active(self):
			mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		else:
			mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED

func _clear_extras() -> void:
	# No extras to setup, so skip parent's method.
	pass

func _ensure_extras_created() -> void:
	# No extras to setup, so skip parent's method.
	pass

func _place_extras(_direction: RelativeDirection) -> void:
	# No extras to setup, so skip parent's method.
	pass

func _setup_static() -> void:
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	(%CloseButton as Control).visible = false

func _setup_interactive() -> void:
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
	(%CloseButton as Control).visible = true

func _on_close_button_pressed() -> void:
	close_requested.emit()
