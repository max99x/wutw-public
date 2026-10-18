@tool
class_name Card
extends Control

signal hovered
signal unhovered
signal selected
signal unselected
signal right_clicked
signal drag_started
signal drag_ended

enum DisplayState { NORMAL, UNLOCKED, DISABLED, INNATE }

static var ASPECT_SCENE := AsyncLoadedResource.new('res://aspects/aspect.tscn')
static var DRAWN_KANJI_SCENE := AsyncLoadedResource.new('res://cards/drawn_kanji.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)

const RARITY_COLORS: Array[Color] = [
	Color(0.55, 0.55, 0.55),    # Black
	Color(0.93, 0.93, 0.93),    # Pale grey
	Color(0.552, 0.92, 0.552),  # Warm green
	Color(0.47, 0.742, 0.98),   # Saturated blue
	Color(0.592, 0.49, 1.0),    # Warm purple
	Color(0.98, 0.661, 0.363),  # Bright orange
	Color(1.0, 0.63, 0.901),    # Hot pink
]
const POSITIVE_ABILITY_COLOR := Color.BLACK
const NEGATIVE_ABILITY_COLOR := Color(0.42, 0.0, 0.0)
const HOVER_BOOST := 50
const HOVER_EFFECT_DURATION := 0.2
const SELECT_BRIGHTNESS := 3
const SELECT_EFFECT_DURATION := 0.3
const PLAY_STATE_EFFECT_DURATION := 1.0
const ABILITY_HIGHLIGHT_DURATION := 1.0

@export var card_type: CardType:
	set(value):
		card_type = value
		if is_node_ready():
			_recreate()
@export var playable: bool = false
@export var allow_select: bool = true
@export var allow_unselect: bool = true
@export var play_selection_loop: bool = false
@export var display_state: DisplayState = DisplayState.NORMAL:
	set(value):
		display_state = value
		if is_node_ready():
			_recreate()
@export var force_show_signature: bool = false
@export var tooltip_directions: Array[Tooltip.RelativeDirection] = [Tooltip.RelativeDirection.RIGHT, Tooltip.RelativeDirection.LEFT]
@export var tooltip_alignments: Array[Tooltip.Alignment] = [Tooltip.Alignment.BEGIN]
@export var practice_mode: bool = false:
	set(value):
		practice_mode = value
		if is_node_ready():
			_recreate()

var is_selected: bool = false:
	set(value):
		if is_selected == value:
			return
		is_selected = value
		if is_node_ready():
			if is_selected:
				selected.emit()
			else:
				unselected.emit()
			_update_select_effect()
			_update_highlight()
var is_being_played: bool = false:
	set(value):
		if is_being_played == value:
			return
		is_being_played = value
		if is_node_ready():
			_update_playing_state()
var highlighted_ability: CardAbility = null:
	set(value):
		if highlighted_ability == value:
			return
		highlighted_ability = value
		if is_node_ready():
			_update_highlighted_ability()
var new_icon_visible: bool = false:
	set(value):
		new_icon_visible = value
		if is_node_ready():
			(%NewIcon as Control).visible = new_icon_visible

var _is_click_dragging: bool = false
var _is_hovered: bool = false
var _is_context_highlighted: bool = false
var _selection_sfx_id: int = 0
var _highlight_tween: Tween
var _play_state_tween: Tween
var _select_tween: Tween
var _highlighted_ability_tween: Tween

func _ready() -> void:
	if not Utils.is_in_editor():
		if Utils.is_compatibility_renderer():
			(%Dowel as Control).material = load('res://cards/art/card_dowel_mat_compatibility.tres')
			(%RarityOverlay as Control).material = load('res://cards/art/card_rarity_material_compatibility.tres')
			(%RarityOverlay2 as Control).material = (%RarityOverlay as Control).material
		else:
			(%Dowel as Control).material = load('res://cards/art/card_dowel_mat.tres')
			(%RarityOverlay as Control).material = load('res://cards/art/card_rarity_material.tres')
			(%RarityOverlay2 as Control).material = (%RarityOverlay as Control).material
	_recreate()
	set_process(false)
	if not Utils.is_in_editor():
		GlobalGameSettings.changed.connect(_recreate)
	if not practice_mode:
		GlobalTooltipSystem.attach(self, _make_tooltip_text,
				tooltip_directions, tooltip_alignments, %MainContainer as Control)
	GlobalContextHighlight.request_changed.connect(func(requested: ContextHighlight.Context) -> void:
		_is_context_highlighted = false
		if card_type and requested:
			if requested.aspect_types:
				if practice_mode and not card_type.aspects and requested.aspect_types.size() == AspectType.get_all_types().size():
					_is_context_highlighted = true
				else:
					for requested_aspect in requested.aspect_types:
						if requested_aspect in card_type.aspects:
							_is_context_highlighted = true
							break
			# DISABLED: Only important in starter tutorial, which uses custom arrows instead.
			#elif load('res://glossary/terms/standalone/term_glyph.tres') in requested.terms:
			#	_is_context_highlighted = true
		_update_highlight()
	)

func _exit_tree() -> void:
	GlobalContextHighlight.retract_offer(self)
	_stop_sfx()

func _get_drag_data(_pos: Vector2) -> Variant:
	if not playable or is_being_played:
		return null

	# Detect when drag is finished.
	var c := Control.new()
	c.tree_exited.connect(func() -> void:
		drag_ended.emit()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	)
	set_drag_preview(c)

	# Hide the "can't drop" cursor.
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	drag_started.emit()

	return self

func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not mouse_event:
		return

	# Click-drag support.
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		if not get_viewport().gui_is_dragging() and not _is_click_dragging:
			if playable and not is_being_played:
				_start_click_drag()
				return

	if not mouse_event.pressed:
		return
	if playable:
		if Utils.is_mac_os() and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.alt_pressed:
			_open_card_details()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if _is_casting_enabled():
				right_clicked.emit()
	else:
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if allow_select and not is_selected:
				is_selected = true
			elif allow_unselect and is_selected:
				is_selected = false

	if playable:
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_open_card_details()
	else:
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_open_card_details()

func animate_appear(duration_multiplier: float = 1.0) -> void:
	modulate.a = 0
	(%AnimationPlayer as AnimationPlayer).play(
		_decorate_anim_name('appear'), -1, Utils.anim_speed(1 / duration_multiplier))
	GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_DRAWSTACK_SCROLL_FAST)
	await get_tree().process_frame  # HACK: Avoid a flash of the card being visible.
	modulate.a = 1
	var duration := Utils.anim_duration(duration_multiplier *
		(%AnimationPlayer as AnimationPlayer).get_animation(
			_decorate_anim_name('appear')).length)
	const ANIM_WAIT_RATIO: float = 0.4
	await get_tree().create_timer(duration * ANIM_WAIT_RATIO).timeout

func animate_disappear() -> void:
	assert((%AnimationPlayer as AnimationPlayer).current_animation != 'disappear')

	if _play_state_tween:
		_play_state_tween.kill()

	modulate.a = 1
	Utils.set_input_enabled(self, false)
	(%AnimationPlayer as AnimationPlayer).play(
		_decorate_anim_name('disappear'), -1, Utils.anim_speed(1))
	GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_CARD_REMOVE)
	await (%AnimationPlayer as AnimationPlayer).animation_finished

func animate_roll() -> void:
	if _highlight_tween:
		_highlight_tween.kill()
	(%AnimationPlayer as AnimationPlayer).play(_decorate_anim_name('rollup'))
	await (%AnimationPlayer as AnimationPlayer).animation_finished

func animate_unroll() -> void:
	if _highlight_tween:
		_highlight_tween.kill()
	(%NameLabel as Label).modulate.a = 0
	(%AnimationPlayer as AnimationPlayer).play(_decorate_anim_name('rollup'), -1, -1, true)
	await (%AnimationPlayer as AnimationPlayer).animation_finished

func is_animating() -> bool:
	return modulate.a < 0.1 or (%AnimationPlayer as AnimationPlayer).is_playing()

func tear_up() -> void:
	is_selected = false

	var subviewport := SubViewport.new()
	subviewport.size = Vector2(256, 256)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subviewport.disable_3d = true
	subviewport.transparent_bg = true
	subviewport.handle_input_locally = false
	var vp_container := SubViewportContainer.new()
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp_container.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	vp_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vp_container.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	vp_container.material = load('res://cards/art/removed_card.tres')
	vp_container.add_child(subviewport)
	var margin := MarginContainer.new()
	# HACK: Ideally these wouldn't be magic numbers, but they really are
	#       just selected manually, and the context here is clear...
	margin.add_theme_constant_override('margin_left', -29)
	margin.add_theme_constant_override('margin_right', -15)
	margin.add_theme_constant_override('margin_top', 0)
	margin.add_theme_constant_override('margin_bottom', -63)
	margin.z_index = 1
	margin.add_child(vp_container)
	add_sibling(margin)
	get_parent().remove_child(self)
	subviewport.add_child(self)
	_recreate()  # _ready() is not called on re-adding.
	self.position.x = 29
	self.position.y = 0
	var tear_material := vp_container.material as ShaderMaterial
	tear_material.set_shader_parameter('progress', 0)

	GlobalAudioSystem.play(AK.EVENTS.UI_GAMECARD_TEAR_ONESHOT)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		tear_material.set_shader_parameter('progress', value)
	, 0.0, 1.0, Utils.anim_duration(1.0))
	tween.parallel().tween_property(%NameLabel, 'self_modulate:a', 0.0, Utils.anim_duration(1.0))
	tween.play()
	await tween.finished

func _recreate() -> void:
	if not card_type:
		return

	match GameSettings.Japanese.card_names.value():
		GameSettings.CardNameDisplayType.MEANING:
			(%NameLabel as Label).text = tr(card_type.card_name)
		GameSettings.CardNameDisplayType.KUNYOMI, GameSettings.CardNameDisplayType.KUNYOMI_ROMAJI:
			var detail := JapaneseUtils.get_kanji_detail(card_type.symbol)
			var kunyomi := detail.get_preferred_kunyomi()
			(%NameLabel as Label).text = JapaneseUtils.decorate_kunyomi(kunyomi) if kunyomi else detail.get_preferred_onyomi()
			if GameSettings.Japanese.card_names.value() == GameSettings.CardNameDisplayType.KUNYOMI_ROMAJI:
				(%NameLabel as Label).text = JapaneseUtils.hiragana_to_romaji((%NameLabel as Label).text)
		GameSettings.CardNameDisplayType.ONYOMI, GameSettings.CardNameDisplayType.ONYOMI_ROMAJI:
			var detail := JapaneseUtils.get_kanji_detail(card_type.symbol)
			var onyomi := detail.get_preferred_onyomi()
			# decorate_onyomi became the same decorate_kunyomi at some point.
			(%NameLabel as Label).text = onyomi if onyomi else JapaneseUtils.decorate_kunyomi(detail.get_preferred_kunyomi())
			if GameSettings.Japanese.card_names.value() == GameSettings.CardNameDisplayType.ONYOMI_ROMAJI:
				(%NameLabel as Label).text = JapaneseUtils.katakana_to_romaji((%NameLabel as Label).text)
	(%NameLabel as Label).modulate.a = float(false if practice_mode else GameSettings.Interface.show_card_names.value())

	(%Symbol as Label).text = card_type.symbol
	(%Symbol as Label).self_modulate.a = 1
	Utils.clear_node(%Symbol)
	if GameSettings.Japanese.use_drawn_kanji.value() and not Utils.is_in_editor():
		var drawn_shape := GlobalSaveGame.get_drawn_kanji_shape(card_type.symbol)
		if drawn_shape:
			(%Symbol as Label).self_modulate.a = 0
			var drawn_kanji := DRAWN_KANJI_SCENE.instantiate_loaded_scene() as DrawnKanji
			drawn_kanji.shape = drawn_shape
			(%Symbol as Label).add_child(drawn_kanji)
			drawn_kanji.position = Vector2(33, 7)

	(%RarityOverlay as Control).self_modulate = RARITY_COLORS[card_type.rarity]
	(%RarityOverlay2 as Control).self_modulate = RARITY_COLORS[card_type.rarity]
	(%NewIcon as Control).visible = new_icon_visible

	Utils.clear_node(%AspectsList)
	if card_type.aspects.size() == 7:  # All
		var wildcard_label := Label.new()
		wildcard_label.text = tr('Any Essence')
		%AspectsList.add_child(wildcard_label)
	else:
		var sorted_aspects: Array[AspectType] = card_type.aspects.duplicate()
		sorted_aspects.sort_custom(AspectType.compare)
		for aspect_type in sorted_aspects:
			var aspect := ASPECT_SCENE.instantiate_loaded_scene() as Aspect
			aspect.aspect_type = aspect_type
			%AspectsList.add_child(aspect)

	if card_type.abilities:
		(%AbilityLabel1 as MarkedUpLabel).set_markedup_text(card_type.abilities[0].get_ability_name(true, true))
		(%AbilityLabel1 as MarkedUpLabel).add_theme_color_override(
			'default_color', POSITIVE_ABILITY_COLOR if card_type.abilities[0].estimate_power(card_type) >= 0 else NEGATIVE_ABILITY_COLOR)
		if card_type.abilities.size() > 1:
			(%AbilityLabel2 as MarkedUpLabel).set_markedup_text(card_type.abilities[1].get_ability_name(true, true))
			(%AbilityLabel2 as MarkedUpLabel).add_theme_color_override(
				'default_color', POSITIVE_ABILITY_COLOR if card_type.abilities[1].estimate_power(card_type) >= 0 else NEGATIVE_ABILITY_COLOR)
			Utils.ensure(card_type.abilities.size() == 2)
		else:
			(%AbilityLabel2 as MarkedUpLabel).set_markedup_text('')
	else:
		(%AbilityLabel1 as MarkedUpLabel).set_markedup_text('')
		(%AbilityLabel2 as MarkedUpLabel).set_markedup_text('')

	(%AbilityLabel1 as MarkedUpLabel).visible = _is_casting_enabled()
	(%AbilityLabel2 as MarkedUpLabel).visible = _should_show_all_abilities()

	var unlocked_icon := %UnlockedIcon as Control
	var innnate_icon := %InnateIcon as Control
	var main_container := %MainContainer as Control
	match display_state:
		DisplayState.NORMAL:
			unlocked_icon.visible = false
			innnate_icon.visible = false
			main_container.modulate = Color.WHITE
		DisplayState.UNLOCKED:
			unlocked_icon.visible = true
			innnate_icon.visible = false
			main_container.modulate = Color.WHITE
		DisplayState.DISABLED:
			unlocked_icon.visible = false
			innnate_icon.visible = false
			main_container.modulate = Color(0.67, 0.67, 0.67, 1.0)
		DisplayState.INNATE:
			unlocked_icon.visible = false
			innnate_icon.visible = true
			main_container.modulate = Color.WHITE
		_:
			Utils.ensure(false)
	(%SignatureIcon as Control).visible = force_show_signature or (not Utils.is_in_editor() and card_type in GlobalSaveGame.get_signature_cards())

	_update_highlight()

func _make_tooltip_text() -> String:
	if not card_type or Utils.is_in_editor():
		return ''

	var pieces : Array[String] = []
	pieces.append(tr('<header_font_size>[b]<term:glyph>: %s (%s)[/b][/font_size]') %
			[tr(card_type.card_name), card_type.get_rarity_name()])
	if display_state == DisplayState.UNLOCKED:
		pieces.append(tr(' - Already Inscribed'))
	elif display_state == DisplayState.DISABLED:
		pieces.append(tr(' - Unavailable'))
	elif display_state == DisplayState.INNATE:
		pieces.append(tr(' - <term:innate>'))

	pieces.append('\n')
	if card_type.aspects.size() == 7:  # All
		pieces.append(tr('Provides any <term:aspect>'))
	if card_type.aspects:
		pieces.append(tr('Provides %s <term:aspect>') % card_type.format_aspects_list())
	else:
		pieces.append(tr('Provides no <term_lower:aspect>s'))

	if card_type.rarity == CardType.Rarity.NEGATIVE:
		pieces.append('\n')
		pieces.append('<term:negative_glyph>')

	if card_type.abilities and _is_casting_enabled():
		pieces.append('\n\n')
		pieces.append(tr('<term:card_ability>s:\n'))
		pieces.append('[ul]')
		for ability in card_type.abilities:
			pieces.append(' [b]%s[/b]: %s\n' % [ability.get_ability_name(true), ability.get_ability_tooltip(self)])
			if not _should_show_all_abilities():
				break
		pieces.append('[/ul]')
		if Utils.get_typed_ancestor(self, CardDeck) and not practice_mode:
			pieces.append(tr('\n[i]%s to cast all the invocations.[/i]') %
					InputPrompts.get_input_markup(InputPrompts.InputType.RIGHT_CLICK))

	if GameSettings.Japanese.dictionary_mode.value() != GameSettings.DictionaryMode.NONE:
		pieces.append('\n[hr width=100%]\n')
		pieces.append(JapaneseUtils.get_kanji_detail(card_type.symbol).get_dictionary_tooltip())
		pieces.append('\n[hr width=100%]')

	var result := ''.join(pieces)
	if playable:
		if '<term:card.' in result:
			result += '\n\n' + tr('[i]%s to open glyph viewer.[/i]') % InputPrompts.get_input_markup(
				InputPrompts.InputType.MIDDLE_CLICK)
	else:
		result += '\n\n' + tr('[i]%s to open glyph viewer.[/i]') % InputPrompts.get_input_markup(
				InputPrompts.InputType.RIGHT_CLICK)

	return result

func _update_highlight() -> void:
	if is_being_played:
		return
	var is_focused := (is_selected or _is_hovered or _is_context_highlighted)
	if _highlight_tween:
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(%HoverOverlay, 'modulate:a8', HOVER_BOOST * float(is_focused), HOVER_EFFECT_DURATION)
	var show_name := false if practice_mode else (is_focused or GameSettings.Interface.show_card_names.value())
	_highlight_tween.parallel().tween_property(%NameLabel, 'modulate:a', float(show_name), HOVER_EFFECT_DURATION)
	if playable:
		z_index = 2 if is_focused else 0
		if get_parent().get_child(0) == self:
			pivot_offset.x = 0
		else:
			pivot_offset.x = size.x / 2
		_highlight_tween.parallel().tween_property(self, 'scale', Vector2.ONE * (1.0 + float(is_focused) * 0.1), HOVER_EFFECT_DURATION)
	_highlight_tween.play()
	if is_focused and not _is_context_highlighted:
		GlobalContextHighlight.offer(ContextHighlight.aspects(self, card_type.aspects))
	else:
		GlobalContextHighlight.retract_offer(self)

func _update_playing_state() -> void:
	if _play_state_tween:
		_play_state_tween.kill()
	_play_state_tween = create_tween()
	_play_state_tween.set_ease(Tween.EASE_OUT)
	if get_parent().get_child(0) == self:
		(%RootVBox as VBoxContainer).pivot_offset.x = 0
	else:
		(%RootVBox as VBoxContainer).pivot_offset.x = size.x / 2
	z_index = 1 if is_being_played else 0
	_play_state_tween.tween_property(%RootVBox, 'position:y', -50 * float(is_being_played), PLAY_STATE_EFFECT_DURATION)
	_play_state_tween.parallel().tween_property(%RootVBox, 'scale', Vector2.ONE * (1.0 + float(is_being_played) * 0.1), PLAY_STATE_EFFECT_DURATION)
	_play_state_tween.set_trans(Tween.TRANS_SPRING)
	_play_state_tween.play()

func _update_highlighted_ability() -> void:
	if _highlighted_ability_tween:
		_highlighted_ability_tween.kill()
	_highlighted_ability_tween = create_tween()
	_highlighted_ability_tween.tween_property(
		%AspectsList,
		'modulate:a',
		0.5 if highlighted_ability else 0.9,
		ABILITY_HIGHLIGHT_DURATION)
	if card_type.abilities:
		_highlighted_ability_tween.parallel().tween_property(
			%AbilityLabel1,
			'modulate:a',
			0.9 if not highlighted_ability or highlighted_ability == card_type.abilities[0] else 0.5,
			ABILITY_HIGHLIGHT_DURATION)
		_highlighted_ability_tween.parallel().tween_method(
			func(v: int) -> void: (%AbilityLabel1 as MarkedUpLabel).add_theme_constant_override('outline_size', v),
			(%AbilityLabel1 as MarkedUpLabel).get_theme_constant('outline_size'),
			10 if highlighted_ability == card_type.abilities[0] else 0,
			ABILITY_HIGHLIGHT_DURATION)
	if card_type.abilities.size() > 1:
		_highlighted_ability_tween.parallel().tween_property(
			%AbilityLabel2,
			'modulate:a',
			0.9 if not highlighted_ability or highlighted_ability == card_type.abilities[1] else 0.5,
			ABILITY_HIGHLIGHT_DURATION)
		_highlighted_ability_tween.parallel().tween_method(
			func(v: int) -> void: (%AbilityLabel2 as MarkedUpLabel).add_theme_constant_override('outline_size', v),
			(%AbilityLabel2 as MarkedUpLabel).get_theme_constant('outline_size'),
			10 if highlighted_ability == card_type.abilities[1] else 0,
			ABILITY_HIGHLIGHT_DURATION)
	_highlighted_ability_tween.play()

func _update_select_effect() -> void:
	if _select_tween:
		_select_tween.kill()
	_select_tween = create_tween()
	var current_factor: Variant = (%RarityOverlay as Control).get_instance_shader_parameter('factor')
	_select_tween.tween_method(func(v: float) -> void:
		if not Utils.is_compatibility_renderer():
			(%RarityOverlay as Control).set_instance_shader_parameter('factor', v)
			(%RarityOverlay2 as Control).set_instance_shader_parameter('factor', v)
	, current_factor if current_factor else 0.0, SELECT_BRIGHTNESS * float(is_selected), SELECT_EFFECT_DURATION)
	_select_tween.play()
	if is_selected:
		_start_sfx()
	else:
		_stop_sfx()

func _start_sfx() -> void:
	if play_selection_loop:
		_selection_sfx_id = GlobalAudioSystem.start_loop(AK.EVENTS.UI_GAMEPLAY_CARD_CARP, self)

func _stop_sfx() -> void:
	if _selection_sfx_id:
		GlobalAudioSystem.stop_loop(_selection_sfx_id)

func _is_casting_enabled() -> bool:
	if Utils.is_in_editor():
		return true
	elif practice_mode:
		return false
	else:
		return GlobalSaveGame.get_main_quest_progress() >= SaveGame.MainQuestProgress.P101_CASTING_ENABLED

func _should_show_all_abilities() -> bool:
	if Utils.is_in_editor():
		return true
	elif practice_mode:
		return false
	else:
		return GlobalSaveGame.get_main_quest_progress() >= SaveGame.MainQuestProgress.P102_COMPLETED_STARTER_TUTORIAL

func _on_mouse_entered() -> void:
	_is_hovered = true
	hovered.emit()
	_update_highlight()
	if playable:
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_DRAWSTACK_HOVER_INHAND)
	else:
		GlobalAudioSystem.play(AK.EVENTS.UI_GAMEPLAY_SELECT_DRAWSTACK_HOVER)

func _on_mouse_exited() -> void:
	_is_hovered = false
	unhovered.emit()
	_update_highlight()

func _open_card_details() -> void:
	CardDetails.open_card_entry(card_type, practice_mode)

func _decorate_anim_name(anim_name: String) -> String:
	if Utils.is_compatibility_renderer():
		return anim_name + '_compatibility'
	else:
		return anim_name

## Click-drag support, started from _gui_input.

func _input(event: InputEvent) -> void:
	if not _is_click_dragging:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event:
		return

	if mouse_event.is_pressed():
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_attempt_click_drop()
			_end_click_drag()
		else:
			get_viewport().set_input_as_handled()
			_end_click_drag()

func _start_click_drag() -> void:
	_is_click_dragging = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	drag_started.emit()
	GlobalUI.notify_drag_started()

func _end_click_drag() -> void:
	_is_click_dragging = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	drag_ended.emit()
	GlobalUI.notify_drag_ended()

func _attempt_click_drop() -> void:
	var target: Node = Utils.get_hovered_control()
	while target:
		if target is Control:
			var control := target as Control
			if target.has_method('_can_drop_data'):
				var local_pos := control.get_local_mouse_position()

				if control._can_drop_data(local_pos, self):
					if target.has_method('_drop_data'):
						control._drop_data(local_pos, self)
					return

		target = target.get_parent()
