class_name CardRewardChoice
extends Node2D

signal card_added(card_type: CardType)
signal canceled
signal selection_finished

static var CARD_SCENE := AsyncLoadedResource.new('res://cards/card.tscn')
static var DECK_VIEWER_SCENE := AsyncLoadedResource.new('res://cards/viewer/card_deck_viewer.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

var allow_removal: bool = true
var specific_card_types: Array[CardType]

var _reserve_buttons: Array[Button]
var _cards_to_reveal: Array[Card]

func _ready() -> void:
	_refill_card_list()

	var run := Utils.get_active_run()
	run.signals.card_choice_offered.emit()

	(%AspectCountersPanel as AspectCountersPanel).card_types = run.get_deck_cards()
	(%ViewDeckButton as Button).text = tr('View Glyph Deck (%d)') % run.get_deck_cards().size()

	_refresh_reroll_button()

	var min_deck_size := run.get_var(RunVars.Var.MIN_DECK_SIZE)
	(%RemoveButton as Button).visible = allow_removal and run.get_deck_cards().size() > min_deck_size

	GlobalTooltipSystem.attach(%RemoveButton as Control, _make_remove_tooltip_text,
			[Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.RIGHT],
			[Tooltip.Alignment.BEGIN, Tooltip.Alignment.END])
	GlobalTooltipSystem.attach(%RerollButton as Control, _make_reroll_tooltip_text,
			[Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.RIGHT],
			[Tooltip.Alignment.BEGIN, Tooltip.Alignment.END])
	GlobalTooltipSystem.attach(%ViewDeckButton as Control, _make_view_deck_tooltip_text,
			[Tooltip.RelativeDirection.RIGHT, Tooltip.RelativeDirection.LEFT],
			[Tooltip.Alignment.BEGIN, Tooltip.Alignment.END])

	# Show card tooltips above the top bar.
	GlobalTooltipSystem.pre_tooltip_shown.connect(func(attached_to: Control, tooltip: Tooltip) -> void:
		if attached_to is Card and %Choices.is_ancestor_of(attached_to):
			tooltip.z_index = UI.Layer.HUD_TOP + UI.LAYER_SPACING
	)

	(%ScrollPanel as ScrollPanel).animate_unroll()

	(%RerollButton as Button).disabled = true
	(%RemoveButton as Button).disabled = true
	(%RemoveButton as Button).modulate.a = 0
	await (%ScrollPanel as ScrollPanel).animate_unroll()
	await _reveal_cards()
	if (%RemoveButton as Button).visible:
		var tween := create_tween()
		tween.tween_property(%RemoveButton, 'modulate:a', 1.0, Utils.anim_duration(1.0))
		tween.play()
		await tween.finished
	(%RerollButton as Button).disabled = false
	(%RemoveButton as Button).disabled = false

func close() -> void:
	Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
	(%BG as FadedBackground).fade_out()
	await (%ScrollPanel as ScrollPanel).animate_roll()
	queue_free()

func _make_remove_tooltip_text() -> String:
	var term_remove := load('res://glossary/terms/standalone/term_remove_card.tres') as Term
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[term_remove.get_term_name(true), term_remove.get_markedup_description()])

func _make_reroll_tooltip_text() -> String:
	var term_reroll := load('res://glossary/terms/standalone/term_reroll.tres') as Term
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[term_reroll.get_term_name(true), term_reroll.get_markedup_description()])

func _make_view_deck_tooltip_text() -> String:
	var term_deck := load('res://glossary/terms/standalone/term_card_deck.tres') as Term
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[term_deck.get_term_name(true), term_deck.get_markedup_description()])

func _on_card_selected(card: Card) -> void:
	var run := Utils.get_active_run()
	run.add_card_to_deck(card.card_type)
	card_added.emit(card.card_type)
	if card.card_type == run.get_reserved_card():
		run.set_reserved_card(null)
	selection_finished.emit()
	run.signals.card_choice_finished.emit()

func _refresh_reroll_button() -> void:
	var run := Utils.get_active_run()
	var rerolls_left := run.get_var(RunVars.Var.CARD_REWARD_REROLLS)
	if rerolls_left and not specific_card_types:
		(%RerollButton as Button).text = tr('Reroll (%d)') % rerolls_left
		(%RerollButton as Button).visible = true
	else:
		(%RerollButton as Button).visible = false

func _refill_card_list(rerolled: bool = false) -> void:
	if not Utils.ensure(_cards_to_reveal.is_empty()):
		_cards_to_reveal.clear()

	var run := Utils.get_active_run()
	var reroll_bonus_guid := Utils.generate_guid()
	if rerolled:
		run.get_vars().add_modifier(
			RunVars.Var.CARD_TIER_BONUS_PERCENT,
			Skill.get_skill_var(Skill.Var.CARD_REWARD_REROLL_QUALITY),
			reroll_bonus_guid)

	var rarity_bonus := run.get_var(RunVars.Var.CARD_TIER_BONUS_PERCENT)
	if rarity_bonus:
		(%RarityBonusLabel as Label).visible = true
		(%RarityBonusLabel as Label).text = tr('(+%d%% Rarity)') % rarity_bonus
	else:
		(%RarityBonusLabel as Label).visible = false

	var card_types: Array[CardType]
	if specific_card_types:
		card_types = specific_card_types
	else:
		var tier_weights := run.get_current_card_reward_weights()
		var num_card_choices := run.get_var(RunVars.Var.CARD_REWARD_CHOICES)
		if run.get_reserved_card():
			card_types = [run.get_reserved_card()]
			num_card_choices -= 1
		card_types += Utils.choose_card_rewards(run, tier_weights, num_card_choices, true)

	Utils.clear_node(%Choices)
	_reserve_buttons.clear()
	for card_type in card_types:
		var new_card := CARD_SCENE.instantiate_loaded_scene() as Card
		new_card.card_type = card_type
		new_card.selected.connect(_on_card_selected.bind(new_card))
		new_card.modulate.a = 0
		new_card.tooltip_directions = [Tooltip.RelativeDirection.ABOVE]
		if card_types.find(card_type) == 0:
			new_card.tooltip_directions.append(Tooltip.RelativeDirection.LEFT)
		elif card_types.find(card_type) == card_types.size() - 1:
			new_card.tooltip_directions.append(Tooltip.RelativeDirection.RIGHT)
		new_card.tooltip_alignments = [Tooltip.Alignment.CENTERED]
		new_card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		if Skill.get_skill_var(Skill.Var.RESERVE_CARD_UNLOCKED):
			var reserve_button := UkiyoeButton.new()
			reserve_button.text = tr('Reserve')
			reserve_button.scale_font_size = true
			reserve_button.toggle_mode = true
			reserve_button.button_pressed = card_type == run.get_reserved_card()
			reserve_button.toggled.connect(_on_reserve_button_toggled.bind(
				reserve_button, card_type))
			_reserve_buttons.append(reserve_button)
			var vbox := VBoxContainer.new()
			vbox.add_child(new_card)
			vbox.add_child(reserve_button)
			%Choices.add_child(vbox)
		else:
			%Choices.add_child(new_card)
		new_card.new_icon_visible = not GlobalSaveGame.has_seen_card(card_type)
		_cards_to_reveal.append(new_card)

	if rerolled:
		run.get_vars().remove_modifier(reroll_bonus_guid)

func _reveal_cards() -> void:
	(%RerollButton as Button).disabled = true
	for card in _cards_to_reveal:
		await card.animate_appear(2.0)
		card.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	_cards_to_reveal.clear()
	(%RerollButton as Button).disabled = false

func _on_skipped() -> void:
	var run := Utils.get_active_run()
	run.signals.card_reward_skipped.emit()
	canceled.emit()
	selection_finished.emit()
	run.signals.card_choice_finished.emit()

func _on_reserve_button_toggled(toggled_on: bool, button: Button, card_type: CardType) -> void:
	for other_button in _reserve_buttons:
		if button != other_button:
			other_button.set_pressed_no_signal(false)
	var run := Utils.get_active_run()
	run.set_reserved_card(card_type if toggled_on else null)

func _on_view_deck_button_pressed() -> void:
	var viewer := DECK_VIEWER_SCENE.instantiate_loaded_scene() as CardDeckViewer
	viewer.cards = Utils.get_active_run().get_deck_cards().duplicate()
	viewer.cards.sort_custom(CardType.compare)
	GlobalUI.add_layer_content(viewer, UI.Layer.STATE_MENU_SUBMENU)

func _on_remove_button_pressed() -> void:
	var remove_selector := DECK_VIEWER_SCENE.instantiate_loaded_scene() as CardDeckViewer
	remove_selector.cards = Utils.get_active_run().get_deck_cards().duplicate()
	remove_selector.cards.sort_custom(func(a: CardType, b: CardType) -> bool:
		return CardType.compare(a, b, true)
	)
	remove_selector.title = tr('Choose Glyph to Remove')
	remove_selector.close_button_label = tr('Cancel')
	remove_selector.allow_card_selection = true
	remove_selector.card_selected.connect(func(card: Card) -> void:
		Utils.get_active_run().remove_card_from_deck(card.card_type)
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
		Utils.set_input_enabled(remove_selector.get_main_control(), false)
		remove_selector.allow_quick_dismiss = false
		await card.tear_up()
		await get_tree().create_timer(Utils.anim_duration(0.5)).timeout
		await remove_selector.close()
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, true)  # Probably pointless, but technically more correct.
		selection_finished.emit()
		Utils.get_active_run().signals.card_choice_finished.emit()
	)
	GlobalUI.add_layer_content(remove_selector, UI.Layer.STATE_MENU_SUBMENU)

func _on_reroll_button_pressed() -> void:
	var run := Utils.get_active_run()
	assert(run.get_var(RunVars.Var.CARD_REWARD_REROLLS) > 0)
	_refill_card_list(true)
	run.get_vars().modify_base_value(RunVars.Var.CARD_REWARD_REROLLS, -1)
	await _reveal_cards()
	_refresh_reroll_button()
