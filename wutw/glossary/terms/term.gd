@tool
class_name Term
extends Resource

const LINK_COLOR := Color(0.0, 0.225, 0.411, 1.0)
static var _group_loader := AsyncLoadedGroup.new('res://glossary/terms/resourcegroup_terms.tres')
static var PIECE_REGEX := RegEx.create_from_string('<[^a-zA-Z]|<[a-zA-Z][^>]*?>|[^<]+')  # Effectively const.
static var _all_terms: Dictionary[String, Term] = {}

@export var term_categories: Array[TermCategory] = []

static func get_all_terms() -> Dictionary[String, Term]:
	if not _all_terms:
		for term: Term in _group_loader.get_loaded():
			assert(term is Term)
			var term_id := term.get_term_id()
			assert(term_id)
			assert(term_id.to_lower() == term_id)
			if term_id in _all_terms:
				push_error('Duplicate term ID "%s":\n- %s\n- %s' %
						[term_id, term.resource_path, _all_terms[term_id].resource_path])
			assert(term_id not in _all_terms)
			_all_terms[term_id] = term
		if Utils.is_dev():  # Do an extra verification.
			for term: Term in _all_terms.values():
				parse(term.get_markedup_description())
	return _all_terms

static func parse(markedup_text: String, create_links: bool = false) -> ParseResult:
	var result := ParseResult.new()

	for piece_match in PIECE_REGEX.search_all(markedup_text):
		var piece := piece_match.get_string()
		if piece.begins_with('<') and piece.length() > 2:
			if piece == '<header_font_size>':
				# HACK: Use the tooltip scaling since we have no context on whether this is paragraph or tooltip.
				var scaled_font_size := roundi(18 * GameSettings.Interface.tooltip_font_scale.value())
				result.bbcode_text += '[font_size=%d]' % scaled_font_size
				continue
			elif piece == '<jp_font_size>':
				# HACK: Use the tooltip scaling since we have no context on whether this is paragraph or tooltip.
				var scaled_font_size := roundi(24 * GameSettings.Interface.tooltip_font_scale.value())
				result.bbcode_text += '[font_size=%d]' % scaled_font_size
				continue
			var tag_and_arg := piece.substr(1, piece.length() - 2).split(':')
			if tag_and_arg.size() != 2:
				Utils.ensure(false, 'Invalid term markup format: ' + piece)
				result.bbcode_text += piece
				continue
			var item_id := tag_and_arg[1].to_lower()
			match tag_and_arg[0]:
				'term':
					var term := lookup_term(item_id)
					if term:
						result.append_term(term, false, create_links)
					else:
						result.bbcode_text += piece
				'term_lower':
					var term := lookup_term(item_id)
					if term:
						result.append_term(term, true, create_links)
					else:
						result.bbcode_text += piece
				'related_term':
					var term := lookup_term(item_id)
					if term:
						result.linked_terms[term] = true
				'shard':
					var shard_type := ShardType.get_shard_type_by_id(item_id)
					if not Utils.ensure(shard_type != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('shard_type', item_id, Utils.TRANSLATION_DUMMY.tr(shard_type.name), create_links)
				'companion':
					var companion := Companion.get_companion_by_id(item_id)
					if not Utils.ensure(companion != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_companion', item_id, Utils.TRANSLATION_DUMMY.tr(companion.companion_name), create_links)
				'spot':
					var spot_type := SpotType.get_spot_type_by_id(item_id)
					if not Utils.ensure(spot_type != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_spot', item_id, Utils.TRANSLATION_DUMMY.tr(spot_type.name), create_links)
				'spot_upgrade':
					var spot_upgrade := SpotUpgrade.get_spot_upgrade_by_id(item_id)
					if not Utils.ensure(spot_upgrade != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_spot_upgrade', item_id, Utils.TRANSLATION_DUMMY.tr(spot_upgrade.name), create_links)
				'relic':
					var relic := Relic.get_relic_by_id(item_id)
					if not Utils.ensure(relic != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_relic', item_id, relic.get_term_name(false), create_links)
				'event':
					var event := Event.get_event_by_id(item_id)
					if not Utils.ensure(event != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_event', item_id, Utils.TRANSLATION_DUMMY.tr(event.event_name), create_links)
				'encounter':
					var episode := SurveyEpisode.get_episode_by_id(item_id)
					if not Utils.ensure(episode != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_encounter', item_id, Utils.TRANSLATION_DUMMY.tr(episode.title), create_links)
				'quest':
					var quest := Quest.get_quest_by_id(item_id)
					if not Utils.ensure(quest != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					if quest is Quest_Settler and Utils.is_settler_questing_unlocked():
						result.append_link('museum_settler_quest', item_id, Utils.TRANSLATION_DUMMY.tr(quest.name), create_links)
					else:
						result.bbcode_text += quest.name
				'haunting':
					var haunting := HauntingType.get_haunting_type_by_id(item_id)
					if not Utils.ensure(haunting != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_haunting', item_id, haunting.get_effective_name(), create_links)
				'shop':
					var shop := ShopType.get_shop_type_by_id(item_id)
					if not Utils.ensure(shop != null, 'Unknown %s: %s' % [tag_and_arg[0], item_id]):
						continue
					result.append_link('museum_shop', item_id, Utils.TRANSLATION_DUMMY.tr(shop.title), create_links)
				_:
					Utils.ensure(false, 'Unknown term markup tag: ' + tag_and_arg[0])
		else:
			result.bbcode_text += piece

	return result

func get_term_id() -> String:
	Utils.ensure(false, 'Subclasses must override.')
	return 'undefined'

@warning_ignore('unused_parameter')
func get_term_name(long: bool) -> String:
	Utils.ensure(false, 'Subclasses must override.')
	return 'Undefined Term'

func get_markedup_description() -> String:
	Utils.ensure(false, 'Subclasses must override.')
	return 'No description specified.'

func get_term_priority() -> int:
	return 0  # Higher values will be prioritized, when deciding which to keep.

func get_term_tag(lower: bool = false) -> String:
	return '<' + ('term_lower' if lower else 'term') + ':' + get_term_id() + '>'

static func lookup_term(term_id: String) -> Term:
	var term_lookup := get_all_terms()
	if term_id not in term_lookup:
		Utils.ensure(false, 'Unknown markup term: ' + term_id)
		return null
	return term_lookup[term_id]

class ParseResult extends RefCounted:
	var bbcode_text: String
	var linked_terms: Dictionary[Term, bool]

	func append_term(term: Term, lowercase: bool, create_links: bool) -> void:
		if create_links:
			bbcode_text += '[url=term:'
			bbcode_text += term.get_term_id()
			bbcode_text += ']'
		var term_name := term.get_term_name(false)
		bbcode_text += term_name.to_lower() if lowercase else term_name
		if create_links:
			bbcode_text +='[/url]'
		linked_terms[term] = true

	func append_link(item_type: String, item_id: String, item_name: String, create_links: bool) -> void:
		if not Utils.is_in_editor() and not Utils.is_museum_unlocked():
			create_links = false
		if create_links:
			bbcode_text += '[color=%s][url=%s:%s]' % [LINK_COLOR.to_html(), item_type, item_id]
		bbcode_text += item_name
		if create_links:
			bbcode_text +='[/url][/color]'
