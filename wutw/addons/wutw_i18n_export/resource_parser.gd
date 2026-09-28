@tool
extends EditorTranslationParserPlugin

var untranslatable_regex := RegEx.create_from_string('^[\\x{3040}-\\x{309F}\\x{30A0}-\\x{30FF}\\x{4E00}-\\x{9FAF}\\x{3000}-\\x{303F}\\x{FF00}-\\x{FFEF}\\s\\p{P}\\d]+$')

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(['tres', 'res', 'tscn', 'scn'])

func _parse_file(path: String) -> Array[PackedStringArray]:
	var extracted: Array[PackedStringArray]
	var resource := ResourceLoader.load(path, '', ResourceLoader.CACHE_MODE_REUSE)

	if not resource:
		return extracted

	var seen: Dictionary[String, bool]

	if resource is PackedScene:
		_extract_from_scene(resource as PackedScene, extracted, seen)
	else:
		_extract_strings_from_resource(resource, extracted, seen)

	if resource is CardType:
		for meaning in JapaneseUtils.get_kanji_detail((resource as CardType).symbol).meanings:
			extracted.append(PackedStringArray([meaning, '', '', 'Property: meanings[]']))

	return extracted

func _extract_from_scene(scene: PackedScene, extracted: Array[PackedStringArray], seen: Dictionary[String, bool]) -> void:
	var state := scene.get_state()
	if not state:
		return

	for node_idx in range(state.get_node_count()):
		for prop_idx in range(state.get_node_property_count(node_idx)):
			var prop_name := state.get_node_property_name(node_idx, prop_idx)
			var prop_value: Variant = state.get_node_property_value(node_idx, prop_idx)

			if prop_value is Resource and _is_embedded(prop_value):
				# Embedded resources
				_extract_strings_from_resource(prop_value, extracted, seen)
			elif prop_value is Array:
				# Arrays of strings or resources
				for item in prop_value:
					if item is String:
						extracted.append(PackedStringArray([item, '', '', 'Property: ' + prop_name + '[]']))
					elif item is Resource and _is_embedded(item):
						_extract_strings_from_resource(item, extracted, seen)
			elif prop_value is String and not prop_value.is_empty():
				# Standard UI string extraction
				if _is_translatable_node_property(prop_name):
					if not _is_internal_string(prop_value) and prop_value not in seen:
						seen[prop_value] = true
						extracted.append(PackedStringArray([prop_value, '', '', 'Property: ' + prop_name]))

func _extract_strings_from_resource(resource: Resource, extracted: Array[PackedStringArray], seen: Dictionary[String, bool]) -> void:
	var properties := resource.get_property_list()

	for prop in properties:
		var prop_name: String = prop['name']
		if not _is_translatable_node_property(prop_name):
			continue

		var value: Variant = resource.get(prop_name)

		if prop['type'] == TYPE_STRING:
			# Strings
			if value is String and not value.is_empty():
				if value not in seen:
					if prop_name != 'script_class' and not _is_internal_string(value):
						seen[value] = true
						extracted.append(PackedStringArray([value, '', '', 'Property: ' + prop_name]))
		elif prop['type'] == TYPE_PACKED_STRING_ARRAY and value is PackedStringArray:
			# Array of strings
			for s in value:
				if value not in seen:
					if not s.is_empty() and not _is_internal_string(s):
						seen[s] = true
						extracted.append(PackedStringArray([s, '', '', 'Property: ' + prop_name]))
		elif prop['type'] == TYPE_OBJECT and value is Resource:
			# Subresources
			if _is_embedded(value):
				_extract_strings_from_resource(value, extracted, seen)
		elif prop['type'] == TYPE_ARRAY and value is Array:
			# Arrays of strings or subresources
			for item in value:
				if item is String:
					if item not in seen and not _is_internal_string(item):
						extracted.append(PackedStringArray([item, '', '', 'Property: ' + prop_name + '[]']))
				elif item is Resource and _is_embedded(item):
					_extract_strings_from_resource(item, extracted, seen)

func _is_embedded(resource: Resource) -> bool:
	return resource.resource_path.is_empty() or resource.resource_path.find('::') != -1

func _is_translatable_node_property(prop_name: String) -> bool:
	if prop_name.match('*_id'):
		return false
	elif prop_name == 'japanese' or prop_name == '_used_kanji':  # ExampleSentence
		return false
	elif prop_name == 'raw_text' or prop_name == 'reading':  # JapaneseToken
		return false
	elif prop_name == 'readings':  # Vocab
		return false
	elif prop_name == 'symbol':  # CardType
		return false
	elif prop_name == 'link' or prop_name == 'custom_link':  # Art link URLs
		return false
	elif prop_name.match('*_jp') or prop_name.match('*_japanese'):
		return false
	else:
		return true

func _is_internal_string(val: String) -> bool:
	if val.begins_with('res://') or val.begins_with('uid://'):
		return true
	if val.begins_with('Resource_') and val.length() == 14:
		return true
	if val.begins_with('SubResource(') or val.begins_with('ExtResource('):
		return true
	# Too slow...
	#if untranslatable_regex.search(val):
	#	return true
	return false
