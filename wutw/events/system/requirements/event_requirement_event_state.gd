@tool
class_name EventRequirement_EventState
extends EventRequirement

enum Scope { RUN, SAVEGAME }
enum Op { EQ, NEQ, GT, GTE, LT, LTE, EXISTS, NOT_EXISTS }

@export var scope: Scope = Scope.RUN
@export var event_id: String = '<self>'
@export var var_id: String
@export var var_type: EventsState.Type = EventsState.Type.INT
@export var var_op: Op = Op.EQ
@export var value: String

func is_satisfied(run: Run, event: Event) -> bool:
	var events_state: EventsState
	if scope == Scope.RUN:
		events_state = run.get_events_state()
	else:
		events_state = GlobalSaveGame.get_events_state()

	var actual_event_id := event_id
	if event_id == '<self>':
		actual_event_id = event.event_id

	if var_op == Op.EXISTS:
		return events_state.exists(actual_event_id, var_id)
	elif var_op == Op.NOT_EXISTS:
		return not events_state.exists(actual_event_id, var_id)

	var current_value: Variant
	var target_value: Variant
	match var_type:
		EventsState.Type.INT:
			current_value = events_state.get_int_or_default(actual_event_id, var_id, 0)
			target_value = value.to_int()
		EventsState.Type.BOOL:
			current_value = events_state.get_bool_or_default(actual_event_id, var_id, false)
			Utils.ensure(value in ['true', 'false'])
			target_value = value == 'true'
		EventsState.Type.STRING:
			current_value = events_state.get_string_or_default(actual_event_id, var_id, '')
			target_value = value

	return _apply_op(current_value, target_value)

func _apply_op(current_value: Variant, target_value: Variant) -> bool:
	Utils.ensure(typeof(current_value) == typeof(target_value))
	match var_op:
		Op.EQ: return current_value == target_value
		Op.NEQ: return current_value != target_value
		Op.GT: return current_value > target_value
		Op.GTE: return current_value >= target_value
		Op.LT: return current_value < target_value
		Op.LTE: return current_value <= target_value
		_: Utils.ensure(false); return false

func to_expression() -> String:
	var result := ''
	if scope == Scope.SAVEGAME:
		result += '$'
	if event_id != '<self>':
		result += event_id
		result += ':'
	result += var_id
	match var_op:
		Op.EQ: result += ' == '
		Op.NEQ: result += ' != '
		Op.GT: result += ' > '
		Op.GTE: result += ' >= '
		Op.LT: result += ' < '
		Op.LTE: result += ' <= '
	if var_type == EventsState.Type.STRING:
		result += '"' if "'" in value else "'"
		result += value
		result += '"' if "'" in value else "'"
	else:
		result += value
	return result

func describe(_run: Run, _detailed: bool) -> String:
	push_warning('Event choice requires var; should use a custom description.')
	return ''
