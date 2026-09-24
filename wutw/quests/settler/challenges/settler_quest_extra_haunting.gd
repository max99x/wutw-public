class_name SettlerQuestChallenge_ExtraHaunting
extends SettlerQuestChallenge

@export var haunting_type: HauntingType

func apply_starting_modifiers(_quest: Quest_Settler, run: Run) -> void:
	Utils.ensure(haunting_type != null)
	run.get_run_data().extra_hauntings.append(haunting_type)

func describe() -> String:
	return tr('Add a <haunting:%s> <term_lower:haunting> to every <term_lower:foray>.') % haunting_type.haunting_id
