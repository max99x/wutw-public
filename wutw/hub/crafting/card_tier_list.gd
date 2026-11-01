class_name CardTierList
extends VBoxContainer

signal card_selected(card: Card)

enum StateFilter { ALL, OWNED, CRAFTABLE, NOT_CRAFTABLE_YET }

static var CARD_SCENE := AsyncLoadedResource.new('res://cards/card.tscn')
static var UNKNOWN_CARD_SCENE := AsyncLoadedResource.new('res://hub/crafting/unknown_card.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)

@export var tier: CardType.Rarity = CardType.Rarity.BASIC:
	set(value):
		tier = value
		if is_node_ready():
			_recreate()
@export var filter_text: String:
	set(value):
		filter_text = value
		if is_node_ready():
			_update_filter()
@export var filter_aspect: AspectType:
	set(value):
		filter_aspect = value
		if is_node_ready():
			_update_filter()
@export var filter_state: StateFilter:
	set(value):
		filter_state = value
		if is_node_ready():
			_update_filter()

var _recreating: bool = false
var _recreation_pending: bool = false
var _last_unlocked_cards: Dictionary[CardType, bool]
var _unknown_card: UnknownCard

func _ready() -> void:
	_recreate()
	GlobalSaveGame.card_discovered.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(self, 'modulate:a', 0.0, 0.3)
		tween.play()
		await tween.finished
		await _recreate()
		tween = create_tween()
		tween.tween_property(self, 'modulate:a', 1.0, 0.3)
		tween.play()
	)
	GlobalSaveGame.changed.connect(_on_savegame_changed)

func get_cards() -> Array[Card]:
	var result: Array[Card]
	for child in %List.get_children():
		var other_card := child as Card
		if other_card:
			result.append(other_card)
	return result

func _recreate() -> void:
	if _recreating:
		_recreation_pending = true
		return
	_recreating = true

	_last_unlocked_cards.clear()
	for card_type in GlobalSaveGame.get_unlocked_cards():
		_last_unlocked_cards[card_type] = true
	Utils.clear_node(%List)
	var card_types := CardType.get_all_card_types_by_tier(tier)
	card_types.sort_custom(CardType.compare)
	var unknown_count := 0
	for card_type in card_types:
		if GlobalSaveGame.has_seen_card(card_type):
			var new_card := CARD_SCENE.instantiate_loaded_scene() as Card
			new_card.card_type = card_type
			new_card.playable = false
			new_card.allow_unselect = false
			if card_type in _last_unlocked_cards:
				new_card.display_state = Card.DisplayState.UNLOCKED
			elif _can_unlock(card_type):
				new_card.display_state = Card.DisplayState.NORMAL
			else:
				new_card.display_state = Card.DisplayState.DISABLED
			new_card.selected.connect(_on_card_selected.bind(new_card))
			%List.add_child(new_card)
			await get_tree().process_frame
			if _recreation_pending:
				_recreation_pending = false
				_recreate()
				return
		else:
			unknown_count += 1
	if unknown_count:
		var unknown_card := UNKNOWN_CARD_SCENE.instantiate_loaded_scene() as UnknownCard
		unknown_card.rarity = tier as CardType.Rarity
		unknown_card.count = unknown_count
		unknown_card.selected.connect(func() -> void: unknown_card.is_selected = false)
		%List.add_child(unknown_card)
		_unknown_card = unknown_card

	_update_filter()

	_recreating = false

func _on_card_selected(card: Card) -> void:
	card_selected.emit(card)

func _on_savegame_changed() -> void:
	_last_unlocked_cards.clear()
	for card_type in GlobalSaveGame.get_unlocked_cards():
		_last_unlocked_cards[card_type] = true
	for child in %List.get_children():
		var card := child as Card
		if card:  # Assume card types can't become "seen" while this UI is up.
			if card.card_type in _last_unlocked_cards:
				card.display_state = Card.DisplayState.UNLOCKED
			elif _can_unlock(card.card_type):
				card.display_state = Card.DisplayState.NORMAL
			else:
				card.display_state = Card.DisplayState.DISABLED
	_update_filter()

func _can_unlock(card_type: CardType) -> bool:
	var strokes := Stroke.get_strokes_for_kanji(card_type.symbol)
	for stroke in strokes:
		if GlobalSaveGame.get_stroke_count(stroke) < strokes[stroke]:
			return false

	if card_type.rarity >= CardType.Rarity.LEGENDARY:
		return false
	elif card_type.rarity >= CardType.Rarity.EPIC:
		return Skill.get_skill_var(Skill.Var.INSCRIBE_EPIC)
	elif card_type.rarity >= CardType.Rarity.RARE:
		return Skill.get_skill_var(Skill.Var.INSCRIBE_RARE)
	elif card_type.rarity >= CardType.Rarity.UNCOMMON:
		return Skill.get_skill_var(Skill.Var.INSCRIBE_UNCOMMON)
	else:
		return Skill.get_skill_var(Skill.Var.INSCRIBE_COMMON)

func _update_filter() -> void:
	for child in %List.get_children():
		var card := child as Card
		if not card:
			continue
		var passes_filter := Utils.matches_query(card.card_type.get_search_text(), filter_text)
		if passes_filter and filter_aspect:
			if filter_aspect not in card.card_type.aspects:
				passes_filter = false
		if passes_filter:
			match filter_state:
				StateFilter.ALL: pass
				StateFilter.OWNED:
					if card.card_type not in _last_unlocked_cards:
						passes_filter = false
				StateFilter.CRAFTABLE:
					if not _can_unlock(card.card_type) or card.card_type in _last_unlocked_cards:
						passes_filter = false
				StateFilter.NOT_CRAFTABLE_YET:
					if (card.card_type.rarity >= CardType.Rarity.LEGENDARY or
						_can_unlock(card.card_type) or card.card_type in _last_unlocked_cards):
						passes_filter = false
		card.visible = passes_filter

	if _unknown_card:
		_unknown_card.visible = not (filter_text or filter_aspect or filter_state != StateFilter.ALL)
