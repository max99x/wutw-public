class_name Crafting
extends Node2D

signal closed

static var STROKE_DISPLAY_SCENE := AsyncLoadedResource.new('res://hub/crafting/stroke_display.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var KANJI_DRAWING_SCENE := AsyncLoadedResource.new('res://japanese/drawing/kanji_drawing_challenge.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)
static var PURCHASE_SCENE := AsyncLoadedResource.new('res://hub/crafting/crafting_purchase.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)

var preview_mode: bool = false
var _selected_card_type: CardType
var _closing := false

func _ready() -> void:
	_update_available_resources()
	GlobalSaveGame.changed.connect(_update_available_resources)

	if preview_mode:
		(%TitleLabel as Label).text = tr('Glyph Catalog')

	(%CraftingCard as Control).visible = false
	(%CraftButton as Control).visible = false
	(%RequirementsBox as Control).visible = false
	if not preview_mode and (Skill.get_skill_var(Skill.Var.BUY_STROKES) > 0 or Skill.get_skill_var(Skill.Var.BUY_CARDS) > 0):
		(%PurchaseButton as Button).visible = true
		(%CloseButton as Button).size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	else:
		(%PurchaseButton as Button).visible = false
		(%CloseButton as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND

	for tier_list: CardTierList in %CardsList.get_children():
		tier_list.card_selected.connect(_on_card_selected)

	for aspect in AspectType.get_all_types():
		(%AspectFilterDropdown as Dropdown).add_item(aspect.get_term_tag(), aspect)

	GlobalTooltipSystem.attach(%CraftButton as Control, _make_crafted_button_tooltip_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

	(%ScrollPanel as ScrollPanel).animate_unroll()

func _handle_esc() -> bool:
	_close()
	return true

func _on_close_button_pressed() -> void:
	_close()

func _close() -> void:
	if not _closing:
		_closing = true
		(%OwnedFilterDropdown as Dropdown).close()
		(%AspectFilterDropdown as Dropdown).close()
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		closed.emit()
		queue_free()

func _update_available_resources() -> void:
	for child in %StrokesInventory.get_children():
		var stroke_display := child as StrokeDisplay
		stroke_display.count = GlobalSaveGame.get_stroke_count(stroke_display.stroke)
	_update_selected_card_type()

func _on_card_selected(card: Card) -> void:
	for tier_list: CardTierList in %CardsList.get_children():
		for other_card in tier_list.get_cards():
			if card != other_card:
				other_card.is_selected = false
	_selected_card_type = card.card_type if card else null
	_update_selected_card_type()

func _update_selected_card_type() -> void:
	var craft_button := %CraftButton as Button
	craft_button.modulate.a = 1.0
	if not _selected_card_type:
		(%CraftingCard as Card).visible = false
		(%RequirementsBox as Control).visible = false
		craft_button.visible = false
		(%OwnedLabel as Label).visible = false
		(%PracticeButton as Control).visible = false
	else:
		(%CraftingCard as Card).visible = true
		var is_unlocked := _selected_card_type in GlobalSaveGame.get_unlocked_cards()
		(%RequirementsBox as Control).visible = true
		(%OwnedLabel as Label).visible = is_unlocked
		craft_button.visible = not preview_mode and not (%OwnedLabel as Label).visible
		(%PracticeButton as Control).visible = GlobalGameSettings.Japanese.kanji_drawing_enabled.value() and not craft_button.visible

		(%CraftingCard as Card).card_type = _selected_card_type
		(%CraftingCard.get_node('%Symbol') as Control).modulate.a = 1.0 if is_unlocked else 0.5
		for child: Control in %CraftingCard.get_node('%AspectsList').get_children():
			(child as Control).modulate.a = 1.0 if is_unlocked else 0.5
		(%CraftingCard.get_node('%LabelContainer') as Control).modulate.a = 1.0 if is_unlocked else 0.5

		Utils.clear_node(%RequirementsBox)
		var strokes := Stroke.get_strokes_for_kanji(_selected_card_type.symbol)
		var any_missing_strokes := false
		for stroke in strokes:
			var stroke_display := STROKE_DISPLAY_SCENE.instantiate_loaded_scene() as StrokeDisplay
			stroke_display.stroke = stroke
			if is_unlocked:
				stroke_display.count = strokes[stroke]
				stroke_display.count_required = -1
			else:
				stroke_display.count = GlobalSaveGame.get_stroke_count(stroke)
				stroke_display.count_required = strokes[stroke]
			stroke_display.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			if stroke_display.count < stroke_display.count_required:
				any_missing_strokes = true
			%RequirementsBox.add_child(stroke_display)

		if preview_mode:
			return

		if any_missing_strokes:
			craft_button.disabled = true
		elif _selected_card_type.rarity >= CardType.Rarity.NEGATIVE:
			craft_button.disabled = true
		elif _selected_card_type.rarity >= CardType.Rarity.LEGENDARY:
			craft_button.disabled = true
		elif _selected_card_type.rarity >= CardType.Rarity.EPIC:
			craft_button.disabled = not Skill.get_skill_var(Skill.Var.INSCRIBE_EPIC)
		elif _selected_card_type.rarity >= CardType.Rarity.RARE:
			craft_button.disabled = not Skill.get_skill_var(Skill.Var.INSCRIBE_RARE)
		elif _selected_card_type.rarity >= CardType.Rarity.UNCOMMON:
			craft_button.disabled = not Skill.get_skill_var(Skill.Var.INSCRIBE_UNCOMMON)
		else:
			craft_button.disabled = false

		if craft_button.disabled:
			craft_button.visible = false
		(%MissingReqsLabel as MarkedUpLabel).set_markedup_text(
			_make_crafted_button_tooltip_text(), MarkedUpLabel.LinkMode.LINK)
		(%MissingReqsLabel as Control).visible = craft_button.disabled and not is_unlocked

func _on_craft_button_pressed() -> void:
	if not _selected_card_type:
		assert(false)
		return

	if GlobalGameSettings.Japanese.kanji_drawing_enabled.value():
		var challenge := KANJI_DRAWING_SCENE.instantiate_loaded_scene() as KanjiDrawingChallenge
		challenge.card_type = _selected_card_type
		GlobalUI.add_layer_content(challenge, UI.Layer.GAME_MENU_SUBMENU)
		var succeeded := [false]
		challenge.succeeded.connect(func(shape: KanjiShape) -> void:
			GlobalSaveGame.set_drawn_kanji_shape(challenge.card_type.symbol, shape)
			succeeded[0] = true
		)
		challenge.reset.connect(func() -> void:
			succeeded[0] = false
		)
		await challenge.closed
		if not succeeded[0]:
			return

	await _play_craft_animation()

	GlobalSaveGame.unlock_card(_selected_card_type)
	var strokes := Stroke.get_strokes_for_kanji(_selected_card_type.symbol)
	for stroke in strokes:
		GlobalSaveGame.add_stroke(stroke, -strokes[stroke])

	GlobalSaveGame.save_game()

func _play_craft_animation() -> void:
	Utils.set_input_enabled(%ScrollPanel as Control, false)
	var tween := create_tween()
	tween.tween_property(%CraftButton, 'modulate:a', 0.0, Utils.anim_duration(0.5))
	tween.parallel()
	var draw_sfx_id := GlobalAudioSystem.start_loop(AK.EVENTS.UI_MENU_SLIDER_LOOP, self)
	for child: Control in %RequirementsBox.get_children():
		tween.tween_property(child, 'modulate:a', 0, Utils.anim_duration(1.0))
		tween.parallel()
	tween.tween_property(%CraftingCard.get_node('%Symbol'), 'modulate:a', 1.0, Utils.anim_duration(1.0))
	tween.tween_callback(GlobalAudioSystem.stop_loop.bind(draw_sfx_id))
	for child: Control in %CraftingCard.get_node('%AspectsList').get_children():
		tween.tween_property(child, 'scale', Vector2(1.2, 1.2), Utils.anim_duration(0.2))
		tween.tween_property(child, 'modulate:a', 1, Utils.anim_duration(0.5))
		tween.parallel().tween_property(child, 'scale', Vector2.ONE, Utils.anim_duration(0.5))
	tween.tween_property(%CraftingCard.get_node('%LabelContainer'), 'modulate:a', 1.0, Utils.anim_duration(0.5))
	tween.tween_callback(GlobalAudioSystem.play.bind(AK.EVENTS.UI_GENERIC_SELECT_TAIKO_LOW))
	tween.play()
	await tween.finished
	Utils.set_input_enabled(%ScrollPanel as Control, true)

func _make_crafted_button_tooltip_text() -> String:
	if not _selected_card_type:
		return ''

	if _selected_card_type.rarity >= CardType.Rarity.NEGATIVE:
		return tr('<term:negative_glyph>s cannot be <term:craft>d.')
	elif _selected_card_type.rarity >= CardType.Rarity.LEGENDARY:
		return tr('<related_term:card_rarity_tier>Legendary <term:glyph>s cannot be <term:craft>d.')
	elif _selected_card_type.rarity >= CardType.Rarity.EPIC and not Skill.get_skill_var(Skill.Var.INSCRIBE_EPIC):
		return tr('Required skill: ') + (load('res://skills/craft/skill_craft_4_epic.tres') as Skill).get_term_tag()
	elif _selected_card_type.rarity >= CardType.Rarity.RARE and not Skill.get_skill_var(Skill.Var.INSCRIBE_RARE):
		return tr('Required skill: ') + (load('res://skills/craft/skill_craft_3_rare.tres') as Skill).get_term_tag()
	elif _selected_card_type.rarity >= CardType.Rarity.UNCOMMON and not Skill.get_skill_var(Skill.Var.INSCRIBE_UNCOMMON):
		return tr('Required skill: ') + (load('res://skills/craft/skill_craft_2_uncommon.tres') as Skill).get_term_tag()
	else:
		var strokes := Stroke.get_strokes_for_kanji(_selected_card_type.symbol)
		for stroke in strokes:
			if GlobalSaveGame.get_stroke_count(stroke) < strokes[stroke]:
				return tr('Insufficient <term_lower:stroke>s.')
		return tr('Ready to <term:craft>!')

func _on_search_input_text_changed(query_text: String) -> void:
	for tier_list: CardTierList in %CardsList.get_children():
		tier_list.filter_text = query_text

func _on_owned_filter_dropdown_selected(item: DropdownItem) -> void:
	for tier_list: CardTierList in %CardsList.get_children():
		match item.value:
			null: tier_list.filter_state = CardTierList.StateFilter.ALL
			'owned': tier_list.filter_state = CardTierList.StateFilter.OWNED
			'ready': tier_list.filter_state = CardTierList.StateFilter.CRAFTABLE
			'notyet': tier_list.filter_state = CardTierList.StateFilter.NOT_CRAFTABLE_YET

func _on_aspect_filter_dropdown_selected(item: DropdownItem) -> void:
	for tier_list: CardTierList in %CardsList.get_children():
		tier_list.filter_aspect = item.value as AspectType

func _on_purchase_button_pressed() -> void:
	var purchase := PURCHASE_SCENE.instantiate_loaded_scene() as CraftingPurchase
	GlobalUI.add_layer_content(purchase, UI.Layer.GAME_MENU_SUBMENU)

func _on_practice_button_pressed() -> void:
	assert(_selected_card_type)
	Utils.ensure(GlobalGameSettings.Japanese.kanji_drawing_enabled.value())

	var challenge := KANJI_DRAWING_SCENE.instantiate_loaded_scene() as KanjiDrawingChallenge
	challenge.card_type = _selected_card_type
	GlobalUI.add_layer_content(challenge, UI.Layer.GAME_MENU_SUBMENU)
	challenge.succeeded.connect(func(shape: KanjiShape) -> void:
		GlobalSaveGame.set_drawn_kanji_shape(challenge.card_type.symbol, shape)
	)
	await challenge.closed
	_update_selected_card_type()
