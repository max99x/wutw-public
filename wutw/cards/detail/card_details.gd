@tool
class_name CardDetails
extends Node2D

static var CARD_DETAILS_SCENE := AsyncLoadedResource.new('res://cards/detail/card_details.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)

static var CARD_LINK_REGEX := RegEx.create_from_string(r'<term(?:_lower)?:card\.[^>]*>')
static var CARD_LINK_REPLACEMENT := r'[color=%s]$0[/color]' % Term.LINK_COLOR.to_html()

static var _active_instance: CardDetails

@export var card_type: CardType:
	set(value):
		card_type = value
		if is_node_ready():
			_recreate()
@export var practice_mode: bool = false:
	set(value):
		practice_mode = value
		if is_node_ready():
			_recreate()

var _closing := false

func _ready() -> void:
	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)
	_recreate()
	GlobalTooltipSystem.attach(%StrokesLabel as Control, _make_strokes_tooltip_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

	(%ScrollPanel as ScrollPanel).animate_unroll()

func _update_font_size() -> void:
	Utils._scale_font_size(%MainText as RichTextLabel, false, 16)

func _enter_tree() -> void:
	if not Utils.is_in_editor():
		assert(not _active_instance)
		_active_instance = self

func _exit_tree() -> void:
	if not Utils.is_in_editor():
		assert(_active_instance)
		_active_instance = null

static func open_link(query: String) -> void:
	var pieces := query.split(':', true, 1)
	assert(pieces.size() == 2)
	assert(pieces[0] == 'term')
	assert(pieces[1].begins_with('card.'))
	var term := Term.lookup_term(pieces[1].to_lower())
	assert(term is CardType)
	open_card_entry(term as CardType)

static func open_card_entry(in_card_type: CardType, in_practice_mode: bool = false) -> CardDetails:
	if _active_instance:
		_active_instance.card_type = in_card_type
	else:
		var details := CARD_DETAILS_SCENE.instantiate_loaded_scene() as CardDetails
		details.card_type = in_card_type
		details.practice_mode = in_practice_mode
		GlobalUI.add_layer_content(details, GlobalUI.choose_dynamic_menu_layer())
	return _active_instance

func _handle_esc() -> bool:
	_close()
	return true

func _close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%ScrollPanel as Control, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		get_parent().remove_child(self)
		queue_free()

func _on_close_button_pressed() -> void:
	_close()

func _recreate() -> void:
	if not card_type:
		assert(Utils.is_in_editor())
		return

	(%Card as Card).card_type = card_type
	(%TitleLabel as Label).text = tr('Glyph: %s (%s)') % [tr(card_type.card_name), card_type.get_rarity_name()]
	(%MainText as MarkedUpLabel).set_markedup_text(_construct_details(), MarkedUpLabel.LinkMode.LINK)

	var strokes := Stroke.get_strokes_for_kanji(card_type.symbol)
	var num_strokes := 0
	for stroke in strokes:
		num_strokes += strokes[stroke]
	(%StrokesLabel as Label).text = tr_n('%d stroke', '%d strokes', num_strokes) % num_strokes

func _construct_details() -> String:
	var pieces : Array[String] = []

	if card_type.aspects:
		if card_type.aspects.size() == 7:  # All
			pieces.append(tr('Provides any <term:aspect>'))
		else:
			pieces.append(tr('Provides %s <term:aspect>') % card_type.format_aspects_list())
	else:
		pieces.append(tr('Provides no <term:aspect>s'))

	if card_type.rarity == CardType.Rarity.NEGATIVE:
		pieces.append('\n')
		pieces.append(tr('This is a <term:negative_glyph>.'))

	if CardType.Tag.NOT_RANDOMLY_SELECTED in card_type.tags:
		pieces.append('\n')
		pieces.append(tr('This <term_lower:glyph> is never offered in randomized rewards.'))

	if card_type.abilities and _is_casting_enabled():
		pieces.append('\n\n')
		pieces.append(tr('<term:card_ability>s:\n'))
		pieces.append('[ul]')
		for ability in card_type.abilities:
			var ability_description := ability.get_ability_tooltip(null)
			ability_description = CARD_LINK_REGEX.sub(ability_description, CARD_LINK_REPLACEMENT, true)
			pieces.append(' [b]%s[/b]: %s\n' % [ability.get_ability_name(true), ability_description])
			if not _should_show_all_abilities():
				break
		pieces.append('[/ul]')

	if card_type.tags and card_type.tags != [CardType.Tag.NOT_RANDOMLY_SELECTED]:
		pieces.append('\n\n')
		pieces.append(tr('Tags:\n'))
		pieces.append('[ul]')
		for tag in card_type.tags:
			if tag != CardType.Tag.NOT_RANDOMLY_SELECTED:
				pieces.append('%s\n' % CardType._get_tag_label(tag))
		pieces.append('[/ul]')

	if _should_show_learning_content():
		pieces.append('\n[hr width=100%]\n')
		pieces.append(JapaneseUtils.get_kanji_detail(card_type.symbol).get_dictionary_tooltip())

		pieces.append(tr('\n\n[b]Vocabulary:[/b]\n'))
		for vocab in card_type.vocabulary:
			pieces.append('\n<jp_font_size>%s[/font_size] (%s): %s\n' % [vocab.japanese, ', '.join(vocab.readings), ', '.join(vocab.meanings.map(tr))])

		pieces.append(tr('\n[b]Examples:[/b]\n\n'))
		for example in card_type.example_sentences:
			pieces.append('<jp_font_size>%s[/font_size]\n%s\n\n' % [example.japanese, tr(example.native)])

	return ''.join(pieces)

func _is_casting_enabled() -> bool:
	if practice_mode:
		return false
	elif Utils.is_in_editor():
		return true
	else:
		return GlobalSaveGame.get_main_quest_progress() >= SaveGame.MainQuestProgress.P101_CASTING_ENABLED

func _should_show_all_abilities() -> bool:
	if practice_mode:
		return false
	elif Utils.is_in_editor():
		return true
	else:
		return GlobalSaveGame.get_main_quest_progress() >= SaveGame.MainQuestProgress.P102_COMPLETED_STARTER_TUTORIAL

func _make_strokes_tooltip_text() -> String:
	var strokes := Stroke.get_strokes_for_kanji(card_type.symbol)

	var text := '[center]'
	var i := 0
	for stroke in strokes:
		if i and i % 3 == 0:
			text += '\n\n'
		text += '    %d [img= width=1.5em height=1.5em]%s[/img]    ' % [strokes[stroke], stroke.image.resource_path]
		i += 1
	text += '[/center]'
	if _should_show_learning_content():
		text += tr('\nGame strokes often don\'t match traditional ones.')
	return text

func _should_show_learning_content() -> bool:
	return (Utils.is_in_editor()
			or GameSettings.Japanese.dictionary_mode.value() != GameSettings.DictionaryMode.NONE
			or GameSettings.Japanese.practice_enabled.value()
			or GameSettings.Japanese.kanji_drawing_enabled.value())
