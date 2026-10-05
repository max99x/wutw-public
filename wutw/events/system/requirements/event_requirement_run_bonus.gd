@tool
class_name EventRequirement_RunBonus
extends EventRequirement

@export var bonus_type: BonusType
@export var min_count: int
@export var max_count: int
@export var extra_per_season: int = 0

func is_satisfied(run: Run, _event: Event) -> bool:
	if not Utils.ensure(min_count >= 0 or max_count >= 0):
		return true  # Don't lock people out if it's out fault.
	if min_count >= 0 and max_count >= 0:
		if not Utils.ensure(min_count <= max_count):
			return true  # Don't lock people out if it's out fault.
	var bounds := _get_effective_bounds(run)
	var count := run.get_bonus_amounts().get_amount(bonus_type)
	if bounds[0] >= 0 and count < bounds[0]:
		return false
	if bounds[1] >= 0 and count > bounds[1]:
		return false
	return true

func to_expression() -> String:
	return 'bonus(%s, %d, %d, %d)' % [bonus_type.bonus_type_id, min_count, max_count, extra_per_season]

func describe(run: Run, detailed: bool) -> String:
	var bounds := _get_effective_bounds(run)
	if detailed:
		if bounds[0] == -1:
			return tr('No more than %d %s') % [bounds[1], bonus_type.get_term_tag()]
		elif bounds[1] == -1:
			return tr('At least %d %s') % [bounds[0], bonus_type.get_term_tag()]
		else:
			return tr('Between %d and %d %s') % [bounds[0], bounds[1], bonus_type.get_term_tag()]
	else:
		if bounds[0] == -1:
			return tr('≤%d %s') % [bounds[1], bonus_type.get_term_tag()]
		elif bounds[1] == -1:
			return tr('%d %s') % [bounds[0], bonus_type.get_term_tag()]
		else:
			return tr('%d-%d %s') % [bounds[0], bounds[1], bonus_type.get_term_tag()]

func _get_effective_bounds(run: Run) -> Array[int]:
	var effective_min_count := min_count
	var effective_max_count := max_count
	if run:  # Not in museum/editor.
		var season_index := run.get_current_season_index() if run else 0
		var season_factor := maxi(0, season_index * 3 - 2)
		if min_count >= 0:
			effective_min_count += extra_per_season * season_factor
			effective_min_count = roundi(effective_min_count * run.get_var(RunVars.Var.EVENT_REQS_BONUS_PERCENT) / 100.0)
		if max_count >= 0:
			effective_max_count += extra_per_season * season_factor
			effective_max_count = roundi(effective_max_count * run.get_var(RunVars.Var.EVENT_REQS_BONUS_PERCENT) / 100.0)
	return [effective_min_count, effective_max_count]
