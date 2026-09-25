@tool
class_name ShardType_MainQuest_ForestShrine
extends ShardType

@export var event: Event

func score_requirement(run_data: RunData, index: int) -> float:
	match index:
		0:
			if event.has_triggered(run_data):
				return 1
			else:
				return 0
		_: return -1

func format_history_text(index: int, past_run: PastRun, text_override: String = '') -> String:
	var forest_shrine := load('res://stage/spots/forest/upgrade_forest_1_shrine.tres')
	var text := super.format_history_text(index, past_run, text_override)
	var shrine_town: SettlementNameOption
	for settlement_state in past_run.run_data.settlement_states:
		for upgrades in settlement_state.activated_upgrades:
			for upgrade: SpotUpgrade in upgrades:
				if upgrade == forest_shrine:
					shrine_town = settlement_state.settlement_name
					break
	if not Utils.ensure(shrine_town != null):
		# Observed in the wild - the player died in the same foray where the shrine was built,
		# so the town wasn't finished. Fixed now, but this is for backward-compatibility.
		shrine_town = past_run.get_random_town_name(2)
	var random_town1 := past_run.get_random_town_name(0)
	var nonshrine_town := random_town1 if random_town1 != shrine_town else past_run.get_random_town_name(1)
	return _apply_replacements(text, {
		'$shrine_town': '[b]' + shrine_town.get_native_display_name() + '[/b]',
		'$nonshrine_town': '[b]' + nonshrine_town.get_native_display_name() + '[/b]',
	})

func describe_requirements() -> Array[String]:
	return [tr('Finish the <event:%s>.') % event.event_id]
