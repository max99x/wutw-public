@tool
class_name ShardType_MainQuest_LakeShrine
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

func describe_requirements() -> Array[String]:
	return [tr('Finish the <event:%s>.') % event.event_id]
