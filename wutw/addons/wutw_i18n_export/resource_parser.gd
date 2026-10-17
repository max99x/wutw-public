@tool
extends EditorTranslationParserPlugin

static var untranslatable_regex := RegEx.create_from_string('^[\\x{3040}-\\x{309F}\\x{30A0}-\\x{30FF}\\x{4E00}-\\x{9FAF}\\x{3000}-\\x{303F}\\x{FF00}-\\x{FFEF}\\s\\p{P}\\d]+$')

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(['tres', 'res', 'tscn', 'scn'])

func _parse_file(path: String) -> Array[PackedStringArray]:
	var extracted: Array[PackedStringArray] # Format: [english, context, plurals, comment]
	var resource := ResourceLoader.load(path, '', ResourceLoader.CACHE_MODE_REUSE)

	if not resource:
		return extracted
	elif resource is ResourceGroup:
		return extracted
	elif resource is MapGenerationConfig:
		return extracted
	elif resource is RunType:
		return extracted

	if resource is PackedScene:
		_extract_from_scene(resource as PackedScene, extracted)
	else:
		_extract_strings_from_resource(resource, extracted)

	if resource is CardType:
		for meaning in JapaneseUtils.get_kanji_detail((resource as CardType).symbol).meanings:
			_export(extracted, meaning, resource.resource_path, resource.get_script(), 'meanings[]')

	return extracted

func _extract_from_scene(scene: PackedScene, extracted: Array[PackedStringArray]) -> void:
	var state := scene.get_state()
	if not state:
		return

	for node_idx in range(state.get_node_count()):
		for prop_idx in range(state.get_node_property_count(node_idx)):
			var prop_name := state.get_node_property_name(node_idx, prop_idx)
			var prop_value: Variant = state.get_node_property_value(node_idx, prop_idx)

			if prop_value is Resource and _is_embedded(prop_value):
				# Embedded resources
				_extract_strings_from_resource(prop_value, extracted)
			elif prop_value is Array:
				# Arrays of strings or resources
				for item in prop_value:
					if item is String:
						if _is_translatable_node_property(prop_name):
							_export(extracted, item, scene.resource_path, null, prop_name + '[]')
					elif item is Resource and _is_embedded(item):
						_extract_strings_from_resource(item, extracted)
			elif prop_value is String and not prop_value.is_empty():
				# Standard UI string extraction
				if _is_translatable_node_property(prop_name):
					if not _is_internal_string(prop_value):
						_export(extracted, prop_value, scene.resource_path, null, prop_name + '[]')

func _extract_strings_from_resource(resource: Resource, extracted: Array[PackedStringArray]) -> void:
	var properties := resource.get_property_list()

	for prop in properties:
		var prop_name: String = prop['name']
		if not _is_translatable_node_property(prop_name):
			continue

		var value: Variant = resource.get(prop_name)

		if prop['type'] == TYPE_STRING:
			# Strings
			if value is String and not value.is_empty():
				if prop_name != 'script_class':
					_export(extracted, value, resource.resource_path, resource.get_script(), prop_name)
		elif prop['type'] == TYPE_PACKED_STRING_ARRAY and value is PackedStringArray:
			# Array of strings
			for s in value:
				_export(extracted, s, resource.resource_path, resource.get_script(), prop_name)
		elif prop['type'] == TYPE_OBJECT and value is Resource:
			# Subresources
			if _is_embedded(value):
				_extract_strings_from_resource(value, extracted)
		elif prop['type'] == TYPE_ARRAY and value is Array:
			# Arrays of strings or subresources
			for item in value:
				if item is String:
					_export(extracted, item, resource.resource_path, resource.get_script(), prop_name + '[]')
				elif item is Resource and _is_embedded(item):
					_extract_strings_from_resource(item, extracted)

func _is_embedded(resource: Resource) -> bool:
	return resource.resource_path.is_empty() or resource.resource_path.find('::') != -1

func _export(extracted: Array[PackedStringArray], value: String, filename: String,
			 resource_type: Script, property_name: String) -> void:
	if not value or _is_internal_string(value):
		return
	var category := _categorize(filename, resource_type, property_name)
	extracted.append(PackedStringArray([
		value,
		'',
		'',
		'Category: ' + category + '; Property: ' + property_name
	]))

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
	elif prop_name == 'bones':
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

func _categorize(filename: String, resource_type: Script, property_name: String) -> String:
	filename = filename.get_slice('::', 0)
	if filename.match('res://cards/tier*'):
		if property_name == 'card_name':
			return 'GAMEPLAY'
		else:
			return 'LANGUAGE_LEARNING'

	if filename.match('res://japanese/*'):
		return 'LANGUAGE_LEARNING'

	if filename.match('res://art/*'):
		return 'ART_WIKI'

	if filename.match('res://events/*/event_*.tres'):
		return 'EVENTS'
	if filename.match('res://stage/survey/episodes/episode_*.tres'):
		return 'EVENTS'

	if filename.match('res://shard_types/*/*.tres'):
		return 'NARRATIVE'
	if filename.match('res://cutscenes/*'):
		return 'NARRATIVE'
	if filename.match('res://debate/*.tres'):
		return 'NARRATIVE'
	if filename.match('*/dlg_*.tres'):
		return 'NARRATIVE'
	if filename.match('res://dialogue/barks/bark_db.tres'):
		return 'NARRATIVE'
	if filename.match('res://hub/museum/*.tres'):
		return 'NARRATIVE'

	if filename.match('res://shard_types/shard_names.tres'):
		return 'GAMEPLAY'
	if filename.match('res://stage/settlement_names.tres'):
		return 'GAMEPLAY'
	if filename.match('res://relics/*.tres'):
		return 'GAMEPLAY'
	if filename.match('res://glossary/*'):
		return 'GAMEPLAY'
	if filename.match('res://shops/*'):
		return 'GAMEPLAY'
	if filename.match('res://companions/*'):
		return 'GAMEPLAY'
	if filename.match('res://aspects/*'):
		return 'GAMEPLAY'
	if filename.match('res://bonuses/*'):
		return 'GAMEPLAY'
	if filename.match('res://characters/*.tres'):
		return 'GAMEPLAY'
	if filename.match('res://quests/*.tres'):  # Dialogues filtered earlier.
		return 'GAMEPLAY'
	if filename.match('res://skills/*.tres'):
		return 'GAMEPLAY'
	if filename.match('res://cards/abilities/terms/*.tres'):
		return 'GAMEPLAY'

	if filename.match('res://stage/spots/*.tres'):
		if property_name == 'description':
			return 'NARRATIVE'
		else:
			return 'GAMEPLAY'

	if filename.match('res://stage/hauntings/types/*'):
		if property_name == 'description_long':
			return 'NARRATIVE'
		else:
			return 'GAMEPLAY'

	if filename.match('*.tscn'):
		return 'GAMEPLAY'
	if filename.match('*.scn'):
		return 'GAMEPLAY'

	return 'UNKNOWN'
