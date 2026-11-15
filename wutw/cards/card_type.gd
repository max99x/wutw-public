@tool
class_name CardType
extends Term

enum Rarity {
	## One simple essence.
	##  Abilities: no/minimal
	BASIC = 0,

	## One advanced essence.
	## Abilities: <= bonus +5
	COMMON = 1,

	## Two essences.
	## Abilities: <= bonus +10, inspire 5+cost, draw 1
	UNCOMMON = 2,

	## Three essences.
	## Abilities: <= bonus +15, inspire 5, draw 2
	RARE = 3,

	## Four essences.
	## Abilities: <= bonus +25, inspire 10, draw 2+extra
	EPIC = 4,

	## Four essences.
	## Abilities: <= bonus +50, inspire 12+extra, draw 3
	LEGENDARY = 5,

	## Not available in normal card selection.
	NEGATIVE = 6
}

# WARNING: These are stored as ints in the card resources.
enum Tag {
	# Used for filters, etc.
	NO_TAG = 0,

	NOT_RANDOMLY_SELECTED = 1,
	THEME_PLANT,
	THEME_ANIMAL,
	THEME_MINERAL,
	THEME_NUMBER,
	THEME_PEOPLE,
	THEME_EMOTIONS,
	THEME_BODY,
	THEME_ACTION,
	THEME_TIME,
	THEME_TOOL,
	THEME_ART,
	THEME_KNOWLEDGE,
	THEME_COMMERCE,
	THEME_LABOR,
	THEME_PLACE,
	THEME_SPIRITUAL,
	THEME_FOOD,
	THEME_ELEMENT,
	THEME_COLOR,
	THEME_SOCIAL,
	THEME_WEATHER,
	THEME_LANDSCAPE,
}

static var _card_group_loader := AsyncLoadedGroup.new('res://cards/resourcegroup_card_types.tres')
static var _all_card_types: Array[CardType] = []
static var _card_type_lookup: Dictionary[String, CardType] = {}

@export var symbol: String
@export var card_name: String
@export var rarity: Rarity
@export var abilities: Array[CardAbility]
@export var tags: Array[Tag]
@export var vocabulary: Array[Vocab]
@export var example_sentences: Array[ExampleSentence]
@export var kanji_shape: KanjiShape
@export var debug_power_adjustment: int = 0

var _debug_cached_power: float = NAN  # To avoid recursion.

## A helper to set aspects conveniently in the editor.
@export_flags('Change', 'Life', 'Stability', 'Craft', 'Connection', 'Illumination', 'Spirit')
var init_aspects := 0:
	set(value):
		init_aspects = value
		if init_aspects:  # 0 == using explicit old system.
			aspects.clear()
			if init_aspects & 1:
				aspects.append(load('res://aspects/types/change/aspect_change.tres'))
			if init_aspects & 2:
				aspects.append(load('res://aspects/types/life/aspect_life.tres'))
			if init_aspects & 4:
				aspects.append(load('res://aspects/types/stability/aspect_stability.tres'))
			if init_aspects & 8:
				aspects.append(load('res://aspects/types/craft/aspect_craft.tres'))
			if init_aspects & 16:
				aspects.append(load('res://aspects/types/connection/aspect_connection.tres'))
			if init_aspects & 32:
				aspects.append(load('res://aspects/types/illumination/aspect_illumination.tres'))
			if init_aspects & 64:
				aspects.append(load('res://aspects/types/spirit/aspect_spirit.tres'))

var aspects: Array[AspectType]

static func get_all_card_types() -> Array[CardType]:
	if not _all_card_types:
		for card_type: CardType in _card_group_loader.get_loaded():
			assert(card_type.card_name not in _card_type_lookup)
			assert(card_type.symbol not in _card_type_lookup)
			_all_card_types.append(card_type)
			_card_type_lookup[card_type.card_name.to_lower()] = card_type
			_card_type_lookup[card_type.symbol] = card_type
	return _all_card_types

static func get_all_card_types_by_tier(min_tier: int, max_tier: int = -1) -> Array[CardType]:
	if max_tier == -1:
		max_tier = min_tier
	var result: Array[CardType] = []
	for card_type in get_all_card_types():
		if card_type.rarity >= min_tier and card_type.rarity <= max_tier:
			result.append(card_type)
	return result

static func get_card_type_by_name_or_symbol(name_or_symbol: String) -> CardType:
	if not _card_type_lookup:
		get_all_card_types()  # Ensure initialized.
	return _card_type_lookup.get(name_or_symbol.to_lower(), null)

static func compare(a: CardType, b: CardType, prioritize_negative: bool = false) -> bool:
	if a.rarity != b.rarity:
		if prioritize_negative and (a.rarity == Rarity.NEGATIVE or b.rarity == Rarity.NEGATIVE):
			return a.rarity == Rarity.NEGATIVE
		return a.rarity < b.rarity
	if a.aspects.size() != b.aspects.size():
		return a.aspects.size() < b.aspects.size()

	var sorted_aspects_a := a.aspects.duplicate()
	sorted_aspects_a.sort_custom(AspectType.compare)
	var sorted_aspects_b := b.aspects.duplicate()
	sorted_aspects_b.sort_custom(AspectType.compare)
	for i in range(sorted_aspects_a.size()):
		if sorted_aspects_a[i].sort_order != sorted_aspects_b[i].sort_order:
			return sorted_aspects_a[i].sort_order < sorted_aspects_b[i].sort_order
	return a.abilities.size() < b.abilities.size()

static func _get_tag_label(tag: Tag) -> String:
	match tag:
		Tag.NOT_RANDOMLY_SELECTED: return Utils.TRANSLATION_DUMMY.tr('Not offered in random rewards.')
		Tag.THEME_PLANT: return Utils.TRANSLATION_DUMMY.tr('Plant', 'CARD_TAG')
		Tag.THEME_ANIMAL: return Utils.TRANSLATION_DUMMY.tr('Animal', 'CARD_TAG')
		Tag.THEME_MINERAL: return Utils.TRANSLATION_DUMMY.tr('Mineral', 'CARD_TAG')
		Tag.THEME_NUMBER: return Utils.TRANSLATION_DUMMY.tr('Number', 'CARD_TAG')
		Tag.THEME_PEOPLE: return Utils.TRANSLATION_DUMMY.tr('Person', 'CARD_TAG')
		Tag.THEME_EMOTIONS: return Utils.TRANSLATION_DUMMY.tr('Emotion', 'CARD_TAG')
		Tag.THEME_BODY: return Utils.TRANSLATION_DUMMY.tr('Body Part', 'CARD_TAG')
		Tag.THEME_ACTION: return Utils.TRANSLATION_DUMMY.tr('Action', 'CARD_TAG')
		Tag.THEME_TIME: return Utils.TRANSLATION_DUMMY.tr('Time', 'CARD_TAG')
		Tag.THEME_TOOL: return Utils.TRANSLATION_DUMMY.tr('Tool', 'CARD_TAG')
		Tag.THEME_ART: return Utils.TRANSLATION_DUMMY.tr('Art', 'CARD_TAG')
		Tag.THEME_KNOWLEDGE: return Utils.TRANSLATION_DUMMY.tr('Knowledge', 'CARD_TAG')
		Tag.THEME_COMMERCE: return Utils.TRANSLATION_DUMMY.tr('Commerce', 'CARD_TAG')
		Tag.THEME_LABOR: return Utils.TRANSLATION_DUMMY.tr('Labor', 'CARD_TAG')
		Tag.THEME_PLACE: return Utils.TRANSLATION_DUMMY.tr('Place', 'CARD_TAG')
		Tag.THEME_SPIRITUAL: return Utils.TRANSLATION_DUMMY.tr('Spiritual', 'CARD_TAG')
		Tag.THEME_FOOD: return Utils.TRANSLATION_DUMMY.tr('Food', 'CARD_TAG')
		Tag.THEME_ELEMENT: return Utils.TRANSLATION_DUMMY.tr('Element', 'CARD_TAG')
		Tag.THEME_COLOR: return Utils.TRANSLATION_DUMMY.tr('Color', 'CARD_TAG')
		Tag.THEME_SOCIAL: return Utils.TRANSLATION_DUMMY.tr('Social', 'CARD_TAG')
		Tag.THEME_WEATHER: return Utils.TRANSLATION_DUMMY.tr('Weather', 'CARD_TAG')
		Tag.THEME_LANDSCAPE: return Utils.TRANSLATION_DUMMY.tr('Landscape', 'CARD_TAG')
		_:
			Utils.ensure(false)
			return ''

func _init() -> void:
	term_categories.append(load('res://glossary/categories/termcategory_card.tres'))

func get_rarity_name() -> String:
	return get_rarity_name_static(rarity)

static func get_rarity_name_static(given_rarity: Rarity) -> String:
	match given_rarity:
		0: return Utils.TRANSLATION_DUMMY.tr('Basic', 'CARD_RARITY')
		1: return Utils.TRANSLATION_DUMMY.tr('Common', 'CARD_RARITY')
		2: return Utils.TRANSLATION_DUMMY.tr('Uncommon', 'CARD_RARITY')
		3: return Utils.TRANSLATION_DUMMY.tr('Rare', 'CARD_RARITY')
		4: return Utils.TRANSLATION_DUMMY.tr('Epic', 'CARD_RARITY')
		5: return Utils.TRANSLATION_DUMMY.tr('Legendary', 'CARD_RARITY')
		6: return Utils.TRANSLATION_DUMMY.tr('Negative', 'CARD_RARITY')
		_: return '?'

func get_term_id() -> String:
	return 'card.' + card_name.to_lower().replace(' ', '_')

func get_term_name(long: bool) -> String:
	if long:
		return symbol + tr(' Glyph (%s)') % tr(card_name)
	else:
		return symbol + tr(' (%s)') % tr(card_name)

func get_markedup_description() -> String:
	var pieces: Array[String] = []
	pieces.append('<related_term:glyph>')

	if rarity == CardType.Rarity.NEGATIVE:
		pieces.append('\n')
		pieces.append('<term:negative_glyph>')

	if aspects:
		pieces.append('\n')
		pieces.append(tr('Provides '))
		pieces.append(format_aspects_list())
		pieces.append(' <term:aspect>')
	if abilities:
		pieces.append('\n')
		pieces.append(tr('<term:card_ability>s: '))
		var ability_count := abilities.size()
		for i in range(ability_count):
			if i > 0:
				pieces.append(tr(', '))
			pieces.append('<related_term:%s>%s' %
					[abilities[i].get_term().get_term_id(), abilities[i].get_ability_name(true)])
	return ''.join(pieces)

func get_term_priority() -> int:
	return 10  # Very specific, so probably important.

func estimate_power() -> int:
	if is_nan(_debug_cached_power):
		_debug_cached_power = max(estimate_aspect_power(), estimate_ability_power())
		if rarity == Rarity.NEGATIVE:
			_debug_cached_power -= 5
	return roundi(_debug_cached_power)

func estimate_aspect_power() -> int:
	return estimate_aspect_list_power(aspects)

func estimate_ability_power() -> int:
	var result := 0
	for ability in abilities:
		result += ability.estimate_power(self)
	return result + debug_power_adjustment

static func estimate_aspect_list_power(aspect_types: Array[AspectType]) -> int:
	var total := 0
	var basic_aspects := 0
	for aspect in aspect_types:
		if aspect.is_advanced:
			total += 8
		else:
			total += 10 + basic_aspects * 3
			basic_aspects += 1
	return total

func get_search_text() -> Array[String]:
	var result: Array[String] = [tr(card_name), symbol]
	for aspect in aspects:
		result.append(tr(aspect.name))
	for ability in abilities:
		result.append(ability.get_search_text())
	for tag in tags:
		result.append(_get_tag_label(tag))
	return result

func format_aspects_list() -> String:
	if aspects.size() == 7:  # All
		return tr('any')
	else:
		var term_tags: Array[String]
		term_tags.assign(aspects.map(func(a: AspectType) -> String:
			return a.get_term_tag()
		))
		return Utils.format_conjunction(term_tags, true)

## Dev/Debug Tools

@export_custom(PROPERTY_HINT_NONE, '', PropertyUsageFlags.PROPERTY_USAGE_EDITOR)
var _vocab_fetch_offset: int = 0

@warning_ignore('unused_private_class_variable')
@export_tool_button('Fetch Vocab')
var _fetch_vocab_tool := _fetch_vocab
func _fetch_vocab() -> void:
	var fetched := JapaneseUtils.dev_fetch_vocab(symbol, _vocab_fetch_offset + 5)
	vocabulary += fetched.slice(_vocab_fetch_offset).duplicate(true)
	_vocab_fetch_offset += 5

@export_custom(PROPERTY_HINT_NONE, '', PropertyUsageFlags.PROPERTY_USAGE_EDITOR)
var _sentence_fetch_offset: int = 0

@warning_ignore('unused_private_class_variable')
@export_tool_button('Fetch Sentences')
var _fetch_sentences_tool := _fetch_sentences
func _fetch_sentences() -> void:
	var fetched := JapaneseUtils.dev_fetch_example_sentences(symbol, _sentence_fetch_offset, 5)
	example_sentences += fetched.duplicate(true)
	_sentence_fetch_offset += 5
