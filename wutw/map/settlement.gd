class_name Settlement
extends Control

signal connected
signal lacks_changed

const ICON_RADIUS_FACTOR: float = 0.4

enum Mode { SETUP, SHOPPABLE, PLANNING, HARMONIZATION }

static var _last_picked_roof_color := -1

@export var settlement_sprite_config: MapSpritePlacerConfig
@export var fallback_removable_sprites: Array[MapSpriteType]
@export var roof_color_options: Array[Color]

var state: SettlementState:
	set(value):
		if state:
			state.bonuses_changed.disconnect(_update)
		state = value
		if value:
			state.bonuses_changed.connect(_update)
		if is_node_ready():
			_update()
var mode: Mode = Mode.SETUP:
	set(value):
		mode = value
		if is_node_ready():
			_update()

var _map: Map
var _current_haunting: Haunting_Harmonization
@onready var _lack_recipe_1: HarmonizationRecipe = %LackRecipe1
@onready var _lack_recipe_2: HarmonizationRecipe = %LackRecipe2
@onready var _connection_recipe: HarmonizationRecipe = %ConnectRecipe

func _ready() -> void:
	if not Utils.ensure(state != null):
		state = SettlementState.new()
	_map = Utils.get_active_run().get_map()
	_map.zoom_changed.connect(_update_legend_scale)
	_map.controls_changed.connect(_update)
	GlobalGameSettings.changed.connect(_update)

	Utils.clear_node(%HauntingBox)
	_update()
	_setup_radius_clip()
	GlobalTooltipSystem.attach(self, _make_tooltip_text,
			[Tooltip.RelativeDirection.BELOW, Tooltip.RelativeDirection.RIGHT, Tooltip.RelativeDirection.LEFT],
			[Tooltip.Alignment.CENTERED], %TooltipAnchor as Control)
	GlobalUI.ui_hide_toggled.connect(func() -> void:
		modulate.a = 0 if GlobalUI.is_ui_hidden() else 1
	)
	# Avoid blocking drag-drop.
	GlobalUI.global_drag_started.connect(func() -> void:
		(%TooltipTrigger as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		(%NameBox as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	)
	GlobalUI.global_drag_ended.connect(func() -> void:
		(%TooltipTrigger as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		(%NameBox as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	)
	# NOTE: This doesn't support click-drag, but that's probably fine for now.
	(%BonusesPanel as PanelContainer).set_drag_forwarding(Callable(), _on_bonuses_can_drop_data, _on_bonuses_drop_data)

func _enter_tree() -> void:
	UI.register_zoomable(%RecipesBox as Control, 0.5, 1.0)

# DISABLED: Edge cases happen with overlap, and drag-drop doesn't respect z-index.
#func _can_drop_data(pos: Vector2, data: Variant) -> bool:
#	if mode != Mode.HARMONIZATION:
#		return false
#	if pos.length() > (%RadiusIndicatorFrame as Control).size.x / 2.0:
#		return false
#	assert(data is Card)
#	return SlotUtils.match_slot(get_aspect_slots(), (data as Card).card_type.aspects) != null
#
#func _drop_data(_pos: Vector2, data: Variant) -> void:
#	assert(mode == Mode.HARMONIZATION)
#	assert(data is Card)
#	var slot := SlotUtils.match_slot(get_aspect_slots(), (data as Card).card_type.aspects)
#	assert(slot)
#	slot.card_dropped.emit(data as Card)

func get_radius() -> int:
	return state.radius

func get_map_location() -> Vector2:
	return state.map_location

func get_recipes() -> Array[HarmonizationRecipe]:
	var result: Array[HarmonizationRecipe] = [_lack_recipe_1]
	if should_have_double_lacks() and _lack_recipe_2.state != HarmonizationRecipe.State.UNAVAILABLE:
		result.append(_lack_recipe_2)
	if _connection_recipe.visible:
		result.append(_connection_recipe)
	return result

func get_aspect_slots() -> Array[AspectSlot]:
	var options := _lack_recipe_1.get_aspect_slots() as Array[AspectSlot]
	if should_have_double_lacks() and _lack_recipe_2.state != HarmonizationRecipe.State.UNAVAILABLE:
		options += _lack_recipe_2.get_aspect_slots()
	if _connection_recipe.visible:
		options += _connection_recipe.get_aspect_slots()
	return options

func get_yield_type() -> BonusType:
	return state.get_sorted_bonus_types()[0]

func is_settlement_connected() -> bool:
	return state.is_settlement_connected

func get_unsatisfied_lacks() -> Array[BonusType]:
	var result: Array[BonusType] = []
	if state.lack1_slots_filled != SettlementState.FULLY_FILLED_SLOTS:
		result.append(_lack_recipe_1.bonus_types[0])
	if should_have_double_lacks() and state.lack2_slots_filled != SettlementState.FULLY_FILLED_SLOTS:
		result.append(_lack_recipe_2.bonus_types[0])
	return result

func activate_upgrade(spot_index: int, spot_upgrade: SpotUpgrade) -> void:
	_setup_roof_color()
	if spot_index >= state.activated_upgrades.size():
		state.activated_upgrades.resize(spot_index + 1)
	state.activated_upgrades[spot_index].append(spot_upgrade)
	add_spot_upgrade_sprite(spot_upgrade)

func add_spot_upgrade_sprite(spot_upgrade: SpotUpgrade) -> void:
	var run := Utils.get_active_run()
	for visual in spot_upgrade.visuals:
		var mod := await visual.apply(run.get_map(), get_map_location(), get_radius() + 1, state.roof_color)
		if mod:
			run.get_run_data().map_modifications.append(mod)
			return
		await get_tree().process_frame  # Fixes stutter for things like river sprites with many versions.
	if spot_upgrade.visuals and Utils.is_dev():
		push_warning('Failed to apply upgrade visual for:', spot_upgrade.resource_path)

func reveal() -> void:
	_setup_roof_color()
	(%NameBox as Control).visible = false

	# Add house sprites.
	var mod := MapModification_Fill.new()
	mod.location = get_map_location()
	mod.radius = get_radius() - 1  # To reduce overlap outside range.
	mod.config = settlement_sprite_config
	mod.roof_color_override = state.roof_color
	mod.fallback_removable_sprites = fallback_removable_sprites
	var run := Utils.get_active_run()
	var map := run.get_map()
	GlobalAudioSystem.play(AK.EVENTS.SFX_MAP_FOREY_FINISH)
	await mod.apply(map, true)
	run.get_run_data().map_modifications.append(mod)

	# Reveal name.
	var label := %NameLabel as Label
	var mat := label.material as ShaderMaterial
	mat.set_shader_parameter('reveal_progress', 0)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		mat.set_shader_parameter('width', label.size.x)
		mat.set_shader_parameter('reveal_progress', t)
	, 0.0, 1.0, 2.0)
	tween.set_speed_scale(Utils.anim_speed())
	tween.play()
	(%NameRevealFVX as GPUParticles2D).emitting = true
	GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_UNLOCK_BELL_RING)
	(%NameBox as Control).visible = true
	await tween.finished
	await get_tree().create_timer(Utils.anim_duration(1.0)).timeout

func _on_lack_recipe_activated(recipe: HarmonizationRecipe) -> void:
	if Utils.ensure(recipe.bonus_types.size() > 0):
		satisfy_lack(recipe.bonus_types[0])

func satisfy_lack(bonus_type: BonusType) -> void:
	var recipe: HarmonizationRecipe
	if bonus_type == _lack_recipe_1.bonus_types[0]:
		recipe = _lack_recipe_1
	elif bonus_type == _lack_recipe_2.bonus_types[0]:
		recipe = _lack_recipe_2

	if recipe:
		for slot in recipe.get_aspect_slots():
			slot.is_filled = true  # In case it was completed using connections.
		recipe.show_lack_label = false
		recipe.title = tr('Fulfilled')
		lacks_changed.emit()
		_update()

func add_shop(shop_type: ShopType) -> void:
	assert(shop_type)
	assert(shop_type not in state.shop_types)
	state.shop_types.append(shop_type)
	GlobalSaveGame.mark_shop_seen(shop_type)
	if is_node_ready():
		_update()

func clear_shops() -> void:
	state.shop_types.clear()
	if is_node_ready():
		_update()

func get_shops() -> Array[ShopType]:
	return state.shop_types.duplicate()

func connect_to_capital() -> void:
	if not state.is_settlement_connected:
		state.is_settlement_connected = true
		for slot in _connection_recipe.get_aspect_slots():
			slot.is_filled = true  # In case it was completed using anything other than the recipe.
		connected.emit()

		var run := Utils.get_active_run()
		var map := run.get_map()
		var mod := MapModification_Road.new()
		mod.src = get_map_location()
		mod.src_radius = get_radius()
		var closest_dst := run.get_capital().get_map_location()
		for settlement in run.get_settlements():
			if settlement != self and settlement.is_settlement_connected():
				if settlement.get_map_location().distance_to(mod.src) < closest_dst.distance_to(mod.src):
					closest_dst = settlement.get_map_location()
		mod.dst = closest_dst
		mod.dst_radius = Capital.RADIUS
		mod.apply(map)  # Explicitly not awaiting. Just let it finish whenever.
		run.get_run_data().map_modifications.append(mod)

		run.signals.settlement_connected.emit(self)

func set_haunting(haunting: Haunting_Harmonization) -> void:
	if get_haunting():
		get_haunting().cleanup()
	Utils.clear_node(%HauntingBox)
	if haunting:
		%HauntingBox.add_child(haunting)
	_current_haunting = haunting

func get_haunting() -> Haunting_Harmonization:
	if is_instance_valid(_current_haunting) and _current_haunting.is_available():
		return _current_haunting
	else:
		return null

func _update() -> void:
	if not state:
		return

	match mode:
		Mode.SETUP:
			(%RadiusIndicatorFrame as Control).modulate.a = 0
			(%NameBox as Control).visible = false
			(%RecipesBox as Control).visible = false
			(%ShopsBox as Control).visible = false
		Mode.SHOPPABLE:
			(%RadiusIndicatorFrame as Control).modulate.a = 0
			(%NameBox as Control).visible = true
			(%RecipesBox as Control).visible = false
			(%ShopsBox as Control).visible = _should_show_shop()
		Mode.PLANNING:
			(%RadiusIndicatorFrame as Control).modulate.a = int(GameSettings.Interface.show_settlement_border.value())
			(%NameBox as Control).visible = true
			(%RecipesBox as Control).visible = false
			(%ShopsBox as Control).visible = false
		Mode.HARMONIZATION:
			(%RadiusIndicatorFrame as Control).modulate.a = 0
			(%NameBox as Control).visible = true
			(%RecipesBox as Control).visible = true
			(%HauntingBox as Control).visible = true
			(%ShopsBox as Control).visible = false

			(%NegativeBonus as Bonus).visible = state.lack1_slots_filled != SettlementState.FULLY_FILLED_SLOTS
			(%NegativeBonus2 as Bonus).visible = should_have_double_lacks() and state.lack2_slots_filled != SettlementState.FULLY_FILLED_SLOTS
			for slot in _connection_recipe.get_aspect_slots():
				slot.is_filled = is_settlement_connected()
			_connection_recipe.description = (tr('<term:connect_settlement> this <term:settlement> to the <term:capital>.\n\n' +
										   'This lets the capital provide <related_term:stage_specialization>%s to' +
										   ' other <term_lower:connect_settlement>ed <term_lower:settlement>s.') %
										  state.get_sorted_bonus_types()[0].get_term_tag())
			if not _connection_recipe.activated.is_connected(_on_connection_recipe_activated):
				_connection_recipe.activated.connect(_on_connection_recipe_activated)
		_:
			Utils.ensure(false)
	(%BonusesPanel as Control).visible = (%PositiveBonus as Bonus).visible or (%NegativeBonus as Bonus).visible or (%NegativeBonus2 as Bonus).visible

	# Yields and lacks
	if state.settlement_name:
		var name_label := %NameLabel as Label
		name_label.text = state.settlement_name.get_display_name()
		if GameSettings.Japanese.town_names.value() in [GameSettings.TownNameDisplayType.ROMAJI, GameSettings.TownNameDisplayType.MEANING]:
			name_label.label_settings.font = null
			name_label.label_settings.font_size = 44
		else:
			name_label.label_settings.font = load('res://theme/fonts/Yuji_Mai/YujiMai-Regular.ttf')
			name_label.label_settings.font_size = 64
		var sorted_bonus_types := state.get_sorted_bonus_types()
		(%PositiveBonus as Bonus).bonus_type = sorted_bonus_types[0]
		(%NegativeBonus as Bonus).bonus_type = sorted_bonus_types[-1]
		(%NegativeBonus2 as Bonus).bonus_type = sorted_bonus_types[-2]
		_setup_lack_recipe(_lack_recipe_1, sorted_bonus_types[-1], state.lack1_slots_filled)
		_setup_lack_recipe(_lack_recipe_2, sorted_bonus_types[-2], state.lack2_slots_filled)
		(%PositiveBonus as Bonus).visible = Skill.get_skill_var(Skill.Var.CAPITAL_CONNECTION) > 0
		if _lack_recipe_2.is_available():
			_lack_recipe_2.visible = should_have_double_lacks()
		var mat := name_label.material as ShaderMaterial
		mat.set_shader_parameter('width', name_label.size.x)
		mat.set_shader_parameter('reveal_progress', 1.0)

	if _connection_recipe.is_available():
		_connection_recipe.visible = Skill.get_skill_var(Skill.Var.CAPITAL_CONNECTION) > 0

	# Shops
	var run := Utils.get_active_run()
	while %ShopsBox.get_child_count() > 1:
		var child := %ShopsBox.get_child(0)
		%ShopsBox.remove_child(child)
		child.queue_free()
	for shop_type in state.shop_types:
		var shop_button := UkiyoeButton.new()
		shop_button.text = tr(shop_type.title)
		shop_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		shop_button.pressed.connect(run.open_shop.bind(shop_type))
		%ShopsBox.add_child(shop_button)
		%ShopsBox.move_child(shop_button, 0)
		GlobalTooltipSystem.attach(shop_button, _make_shop_tooltip_text.bind(shop_type),
				[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

	# Setup scale
	scale = state.radius * 2 * _map.get_map_scale() / (%RadiusIndicatorFrame as Control).size

	var label := %NameLabel as Label
	label.material = label.material.duplicate()

	_update_legend_scale()

func hide_completed_recipes() -> void:
	_lack_recipe_1.visible = _lack_recipe_1.state != HarmonizationRecipe.State.ACTIVE
	_lack_recipe_2.visible = _lack_recipe_2.state != HarmonizationRecipe.State.ACTIVE and should_have_double_lacks()
	_connection_recipe.visible = Skill.get_skill_var(Skill.Var.CAPITAL_CONNECTION) > 0 and _connection_recipe.state != HarmonizationRecipe.State.ACTIVE

func should_have_double_lacks() -> bool:
	var run := Utils.get_active_run()
	return run.get_current_season_index() >= run.scaling.first_season_with_double_lacks

func _update_legend_scale() -> void:
	var zoom_level := remap(_map.get_zoom(), _map.min_zoom, _map.max_zoom, 0.0, 1.0)
	var ui_scale := Vector2.ONE * 2.0 / _map.get_zoom() / scale.x

	(%RecipesBox as Control).scale = Vector2.ONE * ui_scale
	(%ShopsBox as Control).scale = Vector2.ONE * ui_scale

	(%NameBox as Control).modulate.a = clampf(remap(zoom_level, 0.1, 0.2, 0, 1), 0, 1)

	(%RecipesBox as Control).modulate.a = clampf(remap(zoom_level, 0.1, 0.2, 0, 1), 0, 1)
	(%RecipesBox as Control).visible = mode == Mode.HARMONIZATION and (%RecipesBox as Control).modulate.a > 0

	(%ShopsBox as Control).modulate.a = clampf(remap(zoom_level, 0.1, 0.2, 0, 1), 0, 1)
	(%ShopsBox as Control).visible = _should_show_shop()

func _setup_lack_recipe(recipe: HarmonizationRecipe, bonus_type: BonusType, filled_slots: Array[int]) -> void:
	recipe.description = tr('<term:satisfy_lack>s the <term_lower:lack> of %s at this <term_lower:settlement>.') % bonus_type.get_term_tag()
	recipe.bonus_types = [bonus_type]
	recipe.aspect_types = [_get_lack_to_aspect()[bonus_type], _get_lack_to_aspect()[bonus_type]]
	recipe.filled_slots = filled_slots
	if filled_slots.size() == 2:
		recipe.state = HarmonizationRecipe.State.ACTIVE
		recipe.title = tr('Fulfilled')
		recipe.show_lack_label = false
	if not recipe.activated.is_connected(_on_lack_recipe_activated.bind(recipe)):
		recipe.slot_filled.connect(_on_slots_filled.bind(recipe))
		recipe.activated.connect(_on_lack_recipe_activated.bind(recipe))

func _on_connection_recipe_activated() -> void:
	connect_to_capital()

func _on_slots_filled(recipe: HarmonizationRecipe) -> void:
	var filled_slots: Array[int] = []
	var i := 0
	for slot in recipe.get_aspect_slots():
		if slot.is_filled:
			filled_slots.append(i)
		i += 1
	if recipe == _lack_recipe_1:
		state.lack1_slots_filled = filled_slots
	elif recipe == _lack_recipe_2:
		state.lack2_slots_filled = filled_slots
	else:
		assert(false)

func _should_show_shop() -> bool:
	if mode != Mode.SHOPPABLE:
		return false
	if not state.shop_types:
		return false
	if not _map.view_controls_enabled:
		return false
	return (%ShopsBox as Control).modulate.a > 0

func _make_tooltip_text() -> String:
	if not state.settlement_name:
		return '<header_font_size>[b]<term:settlement>[/b][/font_size]'

	var text := '<header_font_size>[b]%s (<term:settlement>)[/b][/font_size]' % state.settlement_name.get_display_name()

	if Skill.get_skill_var(Skill.Var.CAPITAL_CONNECTION):
		text += '\n\n'
		text += (tr('This <term_lower:settlement> is <related_term:stage_specialization>specialized in %s') %
				 get_yield_type().get_term_tag())
		if is_settlement_connected():
			text += tr(', which it provides to the <term:capital> because it is <term_lower:connect_settlement>ed.')
		else:
			text += tr('. It can provide this <term_lower:bonus> to the <term:capital> if <term_lower:connect_settlement>ed.')

	if Skill.get_skill_var(Skill.Var.CAPITAL_UNLOCKED):
		var lacks := get_unsatisfied_lacks()
		if lacks:
			var lack_tags: Array[String]
			lack_tags.append(lacks[0].get_term_tag())
			if lacks.size() > 1:
				lack_tags.append(lacks[1].get_term_tag())
			text += '\n\n'
			text += tr('This <term_lower:settlement> has a <term_lower:lack> of %s.') % Utils.format_conjunction(lack_tags)

	if state.activated_upgrades:
		text += '\n\n'
		text += tr('This <term_lower:settlement> has the following <term_lower:spot>s:')
		text += '[ul]'
		for i in range(state.spot_types.size()):
			text += state.spot_types[i].name
			text += tr(': ')
			if i < state.activated_upgrades.size():
				if state.activated_upgrades[i].is_empty():
					text += tr('No <term_lower:spot_upgrade>s')
				else:
					text += (state.activated_upgrades[i][-1] as SpotUpgrade).name
			else:
				text += tr('No <term_lower:spot_upgrade>s')
			text += '\n'
		text += '[/ul]'

	var haunting := get_haunting()
	if haunting:
		text += '\n\n'
		text += tr('This <term_lower:settlement> is affected by a <term_lower:haunting>,')
		text += ' [b]'
		if Utils.is_realistic_era():
			text += tr(haunting.haunting_type.name_realistic)
		else:
			text += haunting.haunting_type.get_localized_name()
		text += '[/b].'

	if state.shop_types:
		text += '\n\n'
		if state.shop_types.size() == 1:
			text += tr('This <term_lower:settlement> has a <term_lower:shop>, %s.') % state.shop_types[0].get_term_tag()
		else:
			text += tr('This <term_lower:settlement> has the following <term_lower:shop>s: ') + state.shop_types[0].get_term_tag()
			for shop_type: ShopType in state.shop_types.slice(1):
				text += tr(', ') + shop_type.get_term_tag()
			text += tr('.')

	text += '\n\n' + state.settlement_name.get_markedup_name_explanation().replace('\n', ' ') + tr('.')

	return text

func _make_shop_tooltip_text(shop_type: ShopType) -> String:
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[shop_type.get_term_name(true), shop_type.get_markedup_description()])

func _setup_radius_clip() -> void:
	await get_tree().process_frame  # Wait for map to register the object.
	var indicator := %RadiusIndicatorFrame as Control
	indicator.material = indicator.material.duplicate()
	(indicator.material as ShaderMaterial).set_shader_parameter(
		'landmass_sdf', _map.generated_map.blurred_biome_sdfs[0])
	var map_size := Vector2(_map.get_map_size())
	var relative_position := _map.get_map_object_location(self)
	var indicator_size := Vector2(indicator.size * scale) / _map.get_map_scale()
	var start_coord := (relative_position - indicator_size / 2) / map_size
	var end_coord := (relative_position + indicator_size / 2) / map_size
	(indicator.material as ShaderMaterial).set_shader_parameter(
		'global_rect', Vector4(start_coord.x, start_coord.y, end_coord.x, end_coord.y))

func _setup_roof_color() -> void:
	if not GameSettings.Interface.vary_roof_color.value():
		return
	if state.roof_color.a > 0.5:
		return

	if _last_picked_roof_color == -1:
		_last_picked_roof_color = randi_range(1, roof_color_options.size() - 1)

	state.roof_color = roof_color_options[_last_picked_roof_color]
	# Pick a random prime to avoid cycles.
	const PRIMES: Array[int] = [3, 5, 7, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89]
	var step := PRIMES[Utils.get_active_run().get_run_data().run_seed % PRIMES.size()]
	_last_picked_roof_color = (_last_picked_roof_color + step) % roof_color_options.size()

func _get_lack_to_aspect() -> Dictionary[BonusType, AspectType]:
	return {
		load('res://bonuses/types/bonus_food.tres'): load('res://aspects/types/life/aspect_life.tres'),
		load('res://bonuses/types/bonus_safety.tres'): load('res://aspects/types/stability/aspect_stability.tres'),
		load('res://bonuses/types/bonus_beauty.tres'): load('res://aspects/types/connection/aspect_connection.tres'),
		load('res://bonuses/types/bonus_harmony.tres'): load('res://aspects/types/spirit/aspect_spirit.tres'),
		load('res://bonuses/types/bonus_knowledge.tres'): load('res://aspects/types/illumination/aspect_illumination.tres'),
		load('res://bonuses/types/bonus_adventure.tres'): load('res://aspects/types/change/aspect_change.tres'),
		load('res://bonuses/types/bonus_productivity.tres'): load('res://aspects/types/craft/aspect_craft.tres'),
	}

func _on_bonuses_can_drop_data(pos: Vector2, data: Variant) -> bool:
	if mode != Mode.HARMONIZATION:
		return false
	if pos.length() > (%RadiusIndicatorFrame as Control).size.x / 2.0:
		return false
	assert(data is Card)
	return SlotUtils.match_slot(get_aspect_slots(), (data as Card).card_type.aspects) != null

func _on_bonuses_drop_data(_pos: Vector2, data: Variant) -> void:
	assert(mode == Mode.HARMONIZATION)
	assert(data is Card)
	var slot := SlotUtils.match_slot(get_aspect_slots(), (data as Card).card_type.aspects)
	assert(slot)
	slot.card_dropped.emit(data as Card)
