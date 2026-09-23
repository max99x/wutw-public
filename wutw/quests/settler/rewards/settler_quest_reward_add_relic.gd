class_name SettlerQuestReward_AddRelic
extends SettlerQuestReward

static var WIDGET_SCENE := AsyncLoadedResource.new('res://events/system/outcomes/add_relic/event_outcome_widget_add_relic.tscn', true, AsyncLoadedResource.LoadPhase.SPECULATIVE)

@export var relic: Relic

func grant(_quest: Quest_Settler, _run: Run) -> EventOutcomeWidget:
	assert(relic)
	var widget := WIDGET_SCENE.instantiate_loaded_scene() as EventOutcomeWidget_AddRelic
	widget.relic = relic
	return widget

func describe() -> String:
	return tr('Get <term_lower:relic>: <relic:%s>.') % relic.relic_id
