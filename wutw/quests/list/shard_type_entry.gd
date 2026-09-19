class_name ShardTypeEntry
extends VBoxContainer

static var QUEST_GOAL_ENTRY_SCENE := AsyncLoadedResource.new('res://quests/list/quest_goal_entry.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

var shard_type: ShardType:
	set(value):
		shard_type = value
		if is_node_ready():
			_update()
var will_use_main_quest_shard_type: bool:
	set(value):
		will_use_main_quest_shard_type = value
		if is_node_ready():
			_update()
var show_pin_button: bool = false:
	set(value):
		show_pin_button = value
		if is_node_ready():
			_update()

func _ready() -> void:
	_update()
	GlobalTooltipSystem.attach(%PinButton as Control, _make_pin_tooltip_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.BEGIN])
	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)

func _update_font_size() -> void:
	var font_size := roundi(16 * GameSettings.Interface.tooltip_font_scale.value())
	(%NameLabel as Label).add_theme_font_size_override('font_size', font_size)

func _enter_tree() -> void:
	GlobalSaveGame.changed.connect(_on_savegame_changed)

func _exit_tree() -> void:
	GlobalSaveGame.changed.disconnect(_on_savegame_changed)

func _update() -> void:
	if not shard_type or not is_node_ready():
		return
	(%NameLabel as Label).text = tr('Shard Culture: ') + tr(shard_type.name)

	Utils.clear_node(%EntriesList, 1)
	var reqs := shard_type.describe_requirements()
	var run := Utils.get_active_run()
	var run_data := run.get_run_data() if run else null
	var all_completed := true
	for i in reqs.size():
		var quest_goal_entry := QUEST_GOAL_ENTRY_SCENE.instantiate_loaded_scene() as QuestGoalEntry
		quest_goal_entry.text = reqs[i]  # Already translated.
		var score := shard_type.score_requirement(run_data, i) if run else 0.0
		quest_goal_entry.completed = score >= 1
		quest_goal_entry.failed = score < 0
		all_completed = all_completed and quest_goal_entry.completed
		quest_goal_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%EntriesList.add_child(quest_goal_entry)
	if shard_type.tier == ShardType.Tier.MAIN_QUEST:
		var quest_goal_entry := QUEST_GOAL_ENTRY_SCENE.instantiate_loaded_scene() as QuestGoalEntry
		quest_goal_entry.text = tr('[b]Revealed as part of the main story and takes precedence over other cultures.[/b]')
		quest_goal_entry.completed = all_completed
		quest_goal_entry.failed = false
		quest_goal_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%EntriesList.add_child(quest_goal_entry)
	elif will_use_main_quest_shard_type:
		var quest_goal_entry := QUEST_GOAL_ENTRY_SCENE.instantiate_loaded_scene() as QuestGoalEntry
		quest_goal_entry.text = tr('[b]The requirements for a main story shard culture have been met, which takes precedence over this culture.[/b]')
		quest_goal_entry.completed = false
		quest_goal_entry.failed = true
		quest_goal_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%EntriesList.add_child(quest_goal_entry)

	(%PinButton as Button).set_pressed_no_signal(GlobalSaveGame.get_pinned_shard_type() == shard_type)
	(%PinButton as Button).visible = show_pin_button

func _on_savegame_changed() -> void:
	if is_node_ready():
		(%PinButton as Button).set_pressed_no_signal(GlobalSaveGame.get_pinned_shard_type() == shard_type)

func _on_pin_button_toggled(toggled_on: bool) -> void:
	GlobalSaveGame.pin_shard_type(shard_type if toggled_on else null)

func _make_pin_tooltip_text() -> String:
	return tr('When toggled on, these requirements will appear in the quests list during <term_lower:run>s.\n\n'
			+ 'If you start an <term_lower:run> with a culture pinned,'
			+ ' settlers will try to pick a shard appropriate for fulfilling the requirements.\n\n'
			+ 'Only one <term_lower:shard_type> can be pinned at a time, and unpinned cultures can still be achieved.')
