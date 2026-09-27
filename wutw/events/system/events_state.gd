class_name EventsState
extends RefCounted

enum Type { INT, BOOL, STRING }

signal changed

var _values: Dictionary[String, Variant] = {}

func clear() -> void:
	_values.clear()

func exists(event_id: String, var_id: String) -> bool:
	return _format_id(event_id, var_id) in _values

# Ints

func get_int(event_id: String, var_id: String) -> int:
	var id := _format_id(event_id, var_id)
	assert(id in _values, 'Tried to get event state int with unknown ID "%s".' % id)
	var value: Variant = _values[id]
	assert(value is int, 'Tried to get event state int with ID "%s" but value is of type %s.' %
			[id, type_string(typeof(value))])
	return value as int

func get_int_or_default(event_id: String, var_id: String, default: int) -> int:
	var id := _format_id(event_id, var_id)
	if id in _values:
		var value: Variant = _values[id]
		assert(value is int, 'Tried to get event state int with ID "%s" but value is of type %s.' %
			[id, type_string(typeof(value))])
		return value as int
	else:
		return default

func set_int(event_id: String, var_id: String, new_value: int) -> void:
	var id := _format_id(event_id, var_id)
	if id in _values:
		assert(_values[id] is int, 'Tried to set event state int with ID "%s", but existing type is %s.' %
				[id, type_string(typeof(_values[id]))])
	_values[id] = new_value
	changed.emit()

# Bools

func get_bool(event_id: String, var_id: String) -> bool:
	var id := _format_id(event_id, var_id)
	assert(id in _values, 'Tried to get event state bool with unknown ID "%s".' % id)
	var value: Variant = _values[id]
	assert(value is bool, 'Tried to get event state bool with ID "%s" but value is of type %s.' %
			[id, type_string(typeof(value))])
	return value as bool

func get_bool_or_default(event_id: String, var_id: String, default: bool) -> bool:
	var id := _format_id(event_id, var_id)
	if id in _values:
		var value: Variant = _values[id]
		assert(value is bool, 'Tried to get event state bool with ID "%s" but value is of type %s.' %
				[id, type_string(typeof(value))])
		return value as bool
	else:
		return default

func set_bool(event_id: String, var_id: String, new_value: bool) -> void:
	var id := _format_id(event_id, var_id)
	if id in _values:
		assert(_values[id] is bool, 'Tried to set event state bool with ID "%s", but existing type is %s.' %
				[id, type_string(typeof(_values[id]))])
	_values[id] = new_value
	changed.emit()

# Strings

func get_string(event_id: String, var_id: String) -> String:
	var id := _format_id(event_id, var_id)
	assert(id in _values, 'Tried to get event state string with unknown ID "%s".' % id)
	var value: Variant = _values[id]
	assert(value is String, 'Tried to get event state string with ID "%s" but value is of type %s.' %
			[id, type_string(typeof(value))])
	return value as String

func get_string_or_default(event_id: String, var_id: String, default: String) -> String:
	var id := _format_id(event_id, var_id)
	if id in _values:
		var value: Variant = _values[id]
		assert(value is String, 'Tried to get event state string with ID "%s" but value is of type %s.' %
				[id, type_string(typeof(value))])
		return value as String
	else:
		return default

func set_string(event_id: String, var_id: String, new_value: String) -> void:
	var id := _format_id(event_id, var_id)
	if id in _values:
		assert(_values[id] is String, 'Tried to set event state string with ID "%s", but existing type is %s.' %
				[id, type_string(typeof(_values[id]))])
	_values[id] = new_value
	changed.emit()

func to_flat() -> Dictionary[String, Variant]:
	return _values.duplicate()

func load_from_flat(flat_data: Dictionary) -> void:
	clear()
	for id: String in flat_data:
		assert(id is String, 'Non-string key when converting events state from flat: %s' % id)
		assert((id as String).count(':') == 1, 'Invalid key format when converting events state from flat: %s' % id)
		var value: Variant = flat_data[id]
		if value is float and abs(round(value) - value) < 0.001:
			value = value as int
		assert(value is int or value is String or value is bool,
			   'Unknown data type when converting events state from flat: %s' % value)
		_values[id] = value
	changed.emit()

static func _format_id(event_id: String, var_id: String) -> String:
	return event_id + ':' + var_id
