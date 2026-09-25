@tool
class_name ShardType_MainQuest_TeoAbode
extends ShardType

@export var quest: Quest_Main140_Dedication

func score_requirement(_run_data: RunData, index: int) -> float:
	match index:
		0:
			var instance := GlobalSaveGame.get_quest_instance(quest)
			if instance and instance.get_state() >= Quest_Main140_Dedication.STATE_PROMPT_SHOWN:
				return 1
			else:
				return 0
		_: return -1

func format_history_text(index: int, past_run: PastRun, text_override: String = '') -> String:
	var text := super.format_history_text(index, past_run, text_override)
	var monastery_town_name: SettlementNameOption
	for settlement_state in past_run.run_data.settlement_states:
		for upgrades in settlement_state.activated_upgrades:
			for upgrade: SpotUpgrade in upgrades:
				if upgrade in quest.monasteries:
					monastery_town_name = settlement_state.settlement_name
					break
	if not Utils.ensure(monastery_town_name != null):
		return text
	return _apply_replacements(text, {
		'$monastery_town': '[b]' + monastery_town_name.get_native_display_name() + '[/b]'
	})

func describe_requirements() -> Array[String]:
	return [tr('Dedicate the Enlightened One\'s statue on this shard.')]
