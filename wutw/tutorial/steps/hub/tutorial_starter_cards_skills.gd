class_name Tutorial_StarterCardsSkills
extends TutorialBase

func get_tutorial_type() -> Type:
	return Type.HUB

func start_listening() -> void:
	Utils.get_active_hub().menu_opened.connect(_on_hub_menu_opened)

func stop_listening() -> void:
	Utils.get_active_hub().menu_opened.disconnect(_on_hub_menu_opened)

func _on_hub_menu_opened(menu: Node) -> void:
	if menu is not SkillManagement:
		return
	if GlobalSaveGame.get_main_quest_progress() < SaveGame.MainQuestProgress.P220_HAUNTINGS_STUDIED:
		return
	if Skill.get_skill_var(Skill.Var.REPLACE_STARTER_CARDS):
		mark_skipped()
		return
	ready_to_trigger.emit()

func get_tutorial_order() -> int:
	return 20

func trigger() -> void:
	var hub := Utils.get_active_hub()
	var skill_management := hub.get_opened_menu() as SkillManagement

	await hub.get_tree().create_timer(1.5).timeout  # Let unroll animation finish.

	var start_cards_skill_node: SkillNode
	for tree in skill_management.get_node('%TreesList').get_children():
		for child in tree.get_children():
			if child is SkillNode:
				var skill_node := child as SkillNode
				if skill_node.skill == load('res://skills/craft/skill_craft_replace.tres'):
					start_cards_skill_node = skill_node
					break

	var text := tr('''
Consider unlocking the [b]%s[/b] to customize your starter deck.
''').strip_edges() % tr(start_cards_skill_node.skill.skill_name)
	_outline_controls([start_cards_skill_node])
	_show_tooltip(start_cards_skill_node, text, [Tooltip.RelativeDirection.BELOW])

func get_skip_id() -> String:
	return 'starter_cards_skills'
