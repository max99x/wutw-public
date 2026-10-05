@tool
class_name EventRequirement_NumSettlements
extends EventRequirement

@export var min_count: int = 1
@export var max_count: int = -1

func is_satisfied(run: Run, _event: Event) -> bool:
	var count := run.get_settlements().size()
	if run.get_current_settlement():
		count -= 1
	if min_count >= 0 and count < min_count:
		return false
	if max_count >= 0 and count > max_count:
		return false
	return true

func to_expression() -> String:
	var result := 'num_settlements('
	result += str(min_count)
	result += ', '
	result += str(max_count)
	result += ')'
	return result

func describe(_run: Run, detailed: bool) -> String:
	if max_count < 0:
		if detailed:
			return tr('At least %d settlements') % min_count
		else:
			return tr('%d settlements') % min_count
	elif min_count < 0:
		if detailed:
			return tr('At most %d settlements') % max_count
		else:
			return tr('≤%d settlements') % max_count
	else:
		if detailed:
			return tr('Between %d and %d settlements') % [min_count, max_count]
		else:
			return tr('%d-%d settlements') % [min_count, max_count]
