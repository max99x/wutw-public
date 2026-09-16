class_name RunTopHud
extends Node2D

func _ready() -> void:
	_update_pause_button_visibility()
	GlobalGameSettings.changed.connect(_update_pause_button_visibility)

func get_inspiration_display() -> InspirationDisplay:
	return %InspirationDisplay

func get_relic_status_bar() -> RelicStatusBar:
	return %RelicStatusBar

func get_stage_goal_tracker() -> StageGoalTracker:
	return %StageGoalTracker

func get_harmonization_haunting_bar() -> HarmonizationHauntingBar:
	return %HarmonizationHauntingBar

func get_quest_hud() -> QuestHud:
	return %QuestHud

func get_run_bonus_listing() -> RunBonusListing:
	return %RunBonusListing

func get_pause_button() -> PauseButton:
	return %PauseButton

func _update_pause_button_visibility() -> void:
	get_pause_button().visible = GameSettings.Interface.show_pause_button.value()
