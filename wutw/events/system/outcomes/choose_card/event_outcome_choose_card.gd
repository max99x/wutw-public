@tool
class_name EventOutcome_ChooseCard
extends EventOutcome

static var WIDGET_SCENE := AsyncLoadedResource.new('res://events/system/outcomes/choose_card/event_outcome_widget_choose_card.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)

@export var specific_card_types: Array[CardType]
@export var card_tier_bonus: int = 0
@export var aspect: AspectType = null
@export var card_tag: CardType.Tag = CardType.Tag.NO_TAG

func apply(_event: Event) -> EventOutcomeWidget:
	var widget := WIDGET_SCENE.instantiate_loaded_scene() as EventOutcomeWidget_ChooseCard
	widget.specific_card_types = specific_card_types
	widget.card_tier_bonus = card_tier_bonus
	widget.aspect = aspect
	widget.card_tag = card_tag
	return widget

func describe(_run: Run) -> String:
	if specific_card_types:
		var card_tags: Array[String]
		for card_type in specific_card_types:
			card_tags.append(card_type.get_term_tag())
		return tr('Choose a <term_lower:glyph>s from: ') + tr(', ').join(card_tags)
	else:
		var tag_label: String
		match card_tag:
			CardType.Tag.THEME_PLANT: tag_label = tr('a plant', 'CARD_TAG')
			CardType.Tag.THEME_ANIMAL: tag_label = tr('an animal', 'CARD_TAG')
			CardType.Tag.THEME_MINERAL: tag_label = tr('a mineral', 'CARD_TAG')
			CardType.Tag.THEME_NUMBER: tag_label = tr('a number', 'CARD_TAG')
			CardType.Tag.THEME_PEOPLE: tag_label = tr('a person', 'CARD_TAG')
			CardType.Tag.THEME_EMOTIONS: tag_label = tr('an emotion', 'CARD_TAG')
			CardType.Tag.THEME_BODY: tag_label = tr('a body', 'CARD_TAG')
			CardType.Tag.THEME_ACTION: tag_label = tr('an action', 'CARD_TAG')
			CardType.Tag.THEME_TIME: tag_label = tr('a time', 'CARD_TAG')
			CardType.Tag.THEME_TOOL: tag_label = tr('a tool', 'CARD_TAG')
			CardType.Tag.THEME_ART: tag_label = tr('an art', 'CARD_TAG')
			CardType.Tag.THEME_KNOWLEDGE: tag_label = tr('a scholarship', 'CARD_TAG')
			CardType.Tag.THEME_COMMERCE: tag_label = tr('a commerce', 'CARD_TAG')
			CardType.Tag.THEME_LABOR: tag_label = tr('a labor', 'CARD_TAG')
			CardType.Tag.THEME_PLACE: tag_label = tr('a place', 'CARD_TAG')
			CardType.Tag.THEME_SPIRITUAL: tag_label = tr('a spiritual', 'CARD_TAG')
			CardType.Tag.THEME_FOOD: tag_label = tr('a food', 'CARD_TAG')
			CardType.Tag.THEME_ELEMENT: tag_label = tr('an element', 'CARD_TAG')
			CardType.Tag.THEME_COLOR: tag_label = tr('a color', 'CARD_TAG')
			CardType.Tag.THEME_SOCIAL: tag_label = tr('a social', 'CARD_TAG')
			CardType.Tag.THEME_WEATHER: tag_label = tr('a weather', 'CARD_TAG')
			CardType.Tag.THEME_LANDSCAPE: tag_label = tr('a landscape', 'CARD_TAG')
			CardType.Tag.NO_TAG: tag_label = tr('a', 'CARD_TAG')
			# WARNING: Should be kept in sync with cards tag list, but not crucial.
		var text := tr('Choose %s <term_lower:glyph>') % tag_label
		if aspect:
			text += tr(' with %s') % aspect.get_term_tag()
		return text
