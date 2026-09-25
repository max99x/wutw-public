@tool
class_name ShardType_AccordMonument
extends ShardType

func score_requirement(run_data: RunData, index: int) -> float:
	match index:
		0:
			if run_data.events_state.get_bool_or_default('_accord_monument', 'ceremony', false):
				return 1
			else:
				return 0
		_: return -1

func describe_requirements() -> Array[String]:
	return [tr('A fully established <shop:accord_monument>.')]
