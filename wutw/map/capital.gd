class_name Capital
extends Control

static var SHOP_TRADE := AsyncLoadedResource.new('res://shops/trade/shop_trade.tres', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var SPRITE := AsyncLoadedResource.new('res://map/sprites/buildings/mst_castle.tres', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var BONUS_SCENE := AsyncLoadedResource.new('res://bonuses/bonus.tscn')

enum Mode { SETUP, SHOPPABLE, PLANNING, HARMONIZATION }

const RADIUS := 25
const ICON_RADIUS_FACTOR: float = 1.0
const SHOP_ACTIVE_STATES := [
	RunData.State.STAGE_SELECTOR,
	RunData.State.CAPITAL_PLACEMENT,
	RunData.State.SURVEY_SELECTOR,
]

@export var settlement_sprite_config: MapSpritePlacerConfig
@export var fallback_removable_sprites: Array[MapSpriteType]

var map_location: Vector2
var mode: Mode = Mode.SHOPPABLE:
	set(value):
		mode = value
		if is_node_ready():
			_update()

var _map: Map

@onready var _has_craft_connection_skill := Skill.get_skill_var(Skill.Var.CAPITAL_CRAFT_CONNECTION) > 0
@onready var _has_provisions_skill := Skill.get_skill_var(Skill.Var.CAPITAL_ACTIVATE_PROVISIONS) > 0

func _ready() -> void:
	var run := Utils.get_active_run()
	_map = run.get_map()
	_map.zoom_changed.connect(_update_legend_scale)
	_map.controls_changed.connect(_update)
	GlobalGameSettings.changed.connect(_update)
	_update()
	_setup_radius_clip()
	run.signals.capital_bonuses_changed.connect(_on_capital_bonuses_changed)
	run.get_bonus_amounts().changed.connect(_update)

	for map_object in run.get_map().get_map_objects():
		if map_object is Settlement:
			_on_map_object_added(map_object)
	_map.map_object_added.connect(_on_map_object_added)

	for recipe in get_recipes():
		if recipe == %ConnectionRecipe:
			recipe.slot_filled.connect(_on_craft_connection_slot_filled)
			recipe.activated.connect(_on_craft_connection_recipe_activated)
		else:
			recipe.activated.connect(_on_provision_recipe_activated.bind(recipe))
	GlobalTooltipSystem.attach(self, _make_tooltip_text,
			[Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.BELOW],
			[Tooltip.Alignment.CENTERED], %TooltipAnchor as Control)

	GlobalTooltipSystem.attach(%ShopButton as Control, _make_shop_tooltip_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

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

func _enter_tree() -> void:
	UI.register_zoomable(%RecipesBox as Control, 0.5, 1.0)

# DISABLED: Edge cases happen with overlap, and drag-drop doesn't respect z-index.
#func _can_drop_data(pos: Vector2, data: Variant) -> bool:
#	assert(data is Card)
#	if pos.length() > (%RadiusIndicatorFrame as Control).size.x / 2.0:
#		return false
#	return SlotUtils.match_slot(get_aspect_slots(), (data as Card).card_type.aspects) != null
#
#func _drop_data(_pos: Vector2, data: Variant) -> void:
#	assert(data is Card)
#	var slot := SlotUtils.match_slot(get_aspect_slots(), (data as Card).card_type.aspects)
#	assert(slot)
#	slot.card_dropped.emit(data as Card)

func get_radius() -> int:
	return RADIUS

func get_map_location() -> Vector2:
	return map_location

func get_recipes() -> Array[HarmonizationRecipe]:
	var result : Array[HarmonizationRecipe] = []
	for recipe in find_children('*', 'HarmonizationRecipe'):
		if recipe == %ConnectionRecipe:
			if not _has_craft_connection_skill:
				continue
		else:
			if not _has_provisions_skill:
				continue
		result.append(recipe as HarmonizationRecipe)
	return result

func get_aspect_slots() -> Array[AspectSlot]:
	var options : Array[AspectSlot] = []
	for recipe in get_recipes():
		if recipe.state == HarmonizationRecipe.State.AVAILABLE:
			options += recipe.get_aspect_slots()
	return options

func update_settlement_lacks() -> void:
	var run := Utils.get_active_run()
	for map_object in run.get_map().get_map_objects():
		if map_object is Settlement:
			var map_settlement := (map_object as Settlement)
			if map_settlement.is_settlement_connected():
				for bonus_type in run.get_unlocked_capital_bonuses():
					map_settlement.satisfy_lack(bonus_type)

func reveal() -> void:
	(%NameBox as Control).visible = false

	var run := Utils.get_active_run()
	var map := run.get_map()

	var old_map_view_controls_enabled := map.view_controls_enabled
	map.view_controls_enabled = false
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED

	var reveal_radius := get_radius() + run.scaling.capital_reveal_radius_base
	reveal_radius = roundi(reveal_radius * run.get_var(RunVars.Var.REVEAL_RADIUS_PERCENT) / 100.0)
	map.reveal_fow_tween(get_map_location(), reveal_radius)
	map.focus_location(get_map_location(), Stage.ZOOM_HARMONIZATION)

	# Place the main castle sprite.
	var place_mod := MapModification_Place.new()
	place_mod.location = get_map_location()
	place_mod.radius = get_radius()
	place_mod.biome = MapBiomes.Biome.CLOUDS
	place_mod.sprite_type = SPRITE.get_loaded() as MapSpriteType
	place_mod.extra_removables = fallback_removable_sprites
	place_mod.force = true
	var place_success := await place_mod.apply(map)
	Utils.ensure(place_success)
	run.get_run_data().map_modifications.append(place_mod)
	GlobalAudioSystem.play(AK.EVENTS.SFX_MAP_CONVERGENCE_START)
	await get_tree().create_timer(1.5).timeout

	# Place houses.
	var fill_mod := MapModification_Fill.new()
	fill_mod.location = get_map_location()
	fill_mod.radius = get_radius() - 2  # To reduce overlap outside range.
	fill_mod.config = settlement_sprite_config
	fill_mod.fallback_removable_sprites = fallback_removable_sprites
	fill_mod.apply(map, true)  # Not awaiting. Let it finish whenever.
	run.get_run_data().map_modifications.append(fill_mod)

	# Reveal name.
	var label := %NameLabel as Label
	label.material = label.material.duplicate()
	var mat := label.material as ShaderMaterial
	mat.set_shader_parameter('width', label.size.x)
	mat.set_shader_parameter('reveal_progress', 0)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		mat.set_shader_parameter('reveal_progress', t)
	, 0.0, 1.0, 2.0)
	tween.set_speed_scale(Utils.anim_speed())
	tween.play()
	(%NameRevealFVX as GPUParticles2D).emitting = true
	GlobalAudioSystem.play(AK.EVENTS.UI_GENERIC_UNLOCK_BELL_RING)
	(%NameBox as Control).visible = true
	await tween.finished

	map.view_controls_enabled = old_map_view_controls_enabled
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED

func _update() -> void:
	var run := Utils.get_active_run()

	(%RecipesBox as Control).visible = mode == Mode.HARMONIZATION
	if mode == Mode.PLANNING:
		(%RadiusIndicatorFrame as Control).modulate.a = int(GameSettings.Interface.show_settlement_border.value())
	else:
		(%RadiusIndicatorFrame as Control).modulate.a = 0
	(%ShopButton as Control).visible = (
		Skill.get_skill_var(Skill.Var.SHOP_TRADE)
		and mode == Mode.SHOPPABLE
		and run.get_state() in SHOP_ACTIVE_STATES)

	var name_label := %NameLabel as Label
	match GameSettings.Japanese.town_names.value():
		GameSettings.TownNameDisplayType.ROMAJI, GameSettings.TownNameDisplayType.MEANING:
			# Romaji is the default, but setting it for the capital is confusing.
			name_label.text = tr('Shard Capital')
		GameSettings.TownNameDisplayType.KANJI:
			name_label.text = '京'
		GameSettings.TownNameDisplayType.HIRAGANA:
			name_label.text = 'きょう'
	if GameSettings.Japanese.town_names.value() in [GameSettings.TownNameDisplayType.ROMAJI, GameSettings.TownNameDisplayType.MEANING]:
		name_label.label_settings.font = null
		name_label.label_settings.font_size = 36
	else:
		name_label.label_settings.font = load('res://theme/fonts/Yuji_Mai/YujiMai-Regular.ttf')
		name_label.label_settings.font_size = 70

	# Setup bonuses.
	_update_bonuses()

	# Setup recipes.
	for recipe in find_children('*', 'HarmonizationRecipe'):
		if recipe == %ConnectionRecipe:
			(recipe as Control).visible = _has_craft_connection_skill
		else:
			(recipe as Control).visible = _has_provisions_skill
	var capital_bonuses := run.get_unlocked_capital_bonuses()
	var min_bonus_required := run.scaling.get_capital_bonus_req(run.get_current_season_index())
	for recipe in get_recipes():
		if recipe == %ConnectionRecipe:
			if run.get_capital_craft_recipe_state().size() < 3:  # Old saves might have broken state.
				recipe.filled_slots = run.get_capital_craft_recipe_state()
		else:
			var bonus_type := recipe.bonus_types[0]
			recipe.description = (tr('Enable the <term:capital> to provide %s to <term_lower:connect_settlement>ed <term_lower:settlement>s.') %
								  bonus_type.get_term_tag())
			if recipe.bonus_types[0] in capital_bonuses:
				for slot in recipe.get_aspect_slots():
					slot.is_filled = true  # In case it was completed using connections.
				# Recipe state changes as a result of filling.
			elif recipe.state != HarmonizationRecipe.State.ACTIVE:
				if run.get_bonus_amounts().get_amount(bonus_type) >= min_bonus_required:
					recipe.state = HarmonizationRecipe.State.AVAILABLE
				else:
					recipe.state = HarmonizationRecipe.State.UNAVAILABLE
					recipe.description += '\n\n' +(
						tr('[b]Requires at least %d total %s, which you do not have.[/b]') %
						[min_bonus_required, bonus_type.get_term_tag()])

	# Setup scale.
	scale = RADIUS * 2 * _map.get_map_scale() / (%RadiusIndicatorFrame as Control).size

	_update_legend_scale()

func _update_bonuses() -> void:
	var capital_bonuses := Utils.get_active_run().get_unlocked_capital_bonuses()
	Utils.clear_node(%BonusesList)
	for bonus_type in BonusType.get_all_types():  # In standard order.
		if bonus_type in capital_bonuses:
			var bonus := BONUS_SCENE.instantiate_loaded_scene() as Bonus
			bonus.custom_minimum_size = Vector2(32, 32)
			bonus.bonus_type = bonus_type
			bonus.highlight_type = Bonus.HighlightType.POSITIVE
			%BonusesList.add_child(bonus)
	(%BonusesPanel as Control).visible = not capital_bonuses.is_empty()

func _on_map_object_added(map_object: Node) -> void:
	if map_object is Settlement:
		(map_object as Settlement).connected.connect(_on_settlement_connected.bind(map_object))

func _on_provision_recipe_activated(recipe: HarmonizationRecipe) -> void:
	var run := Utils.get_active_run()
	run.unlock_capital_bonus(recipe.bonus_types[0])

func _on_craft_connection_slot_filled() -> void:
	var filled_slots: Array[int] = []
	var i := 0
	for slot in (%ConnectionRecipe as HarmonizationRecipe).get_aspect_slots():
		if slot.is_filled:
			filled_slots.append(i)
		i += 1
	var run := Utils.get_active_run()
	run.set_capital_craft_recipe_state(filled_slots)

func _on_craft_connection_recipe_activated() -> void:
	var run := Utils.get_active_run()
	var stage := run.get_current_stage()
	var deck := stage.get_card_deck()

	# Choose a random connection card
	var tier_weights := run.get_current_card_reward_weights()
	var connection_aspect_type := load('res://aspects/types/connection/aspect_connection.tres') as AspectType
	var is_acceptable := func(card_type: CardType) -> bool:
		if CardType.Tag.NOT_RANDOMLY_SELECTED in card_type.tags:
			return false
		return connection_aspect_type in card_type.aspects
	var card_type_to_add : = Utils.choose_card_rewards(run, tier_weights, 1, true, is_acceptable, false)[0]

	stage.queue_action(func() -> void:
		# Make the recipe reusable.
		for slot in (%ConnectionRecipe as HarmonizationRecipe).get_aspect_slots():
			slot.animate_clear()
		run.set_capital_craft_recipe_state([])
		(%ConnectionRecipe as HarmonizationRecipe).state = HarmonizationRecipe.State.AVAILABLE
		GlobalAudioSystem.play(AK.EVENTS.UI_MAP_CAPITAL_CONNECTION)
		# Add that card to the player's hand.
		await deck.add_card_to_hand(card_type_to_add, CardDeck.CardDrawReason.HARMONIZATION_RECIPE)
	)

func _on_capital_bonuses_changed() -> void:
	update_settlement_lacks()
	_update()

func _on_settlement_connected(map_settlement: Settlement) -> void:
	var run := Utils.get_active_run()
	run.unlock_capital_bonus(map_settlement.get_yield_type())
	update_settlement_lacks()

func _update_legend_scale() -> void:
	var ui_scale := Vector2.ONE * 2.0 / _map.get_zoom() / scale.x

	(%RecipesBox as Control).scale = ui_scale
	(%ShopButton as Control).scale = ui_scale

	var zoom_level := remap(_map.get_zoom(), _map.min_zoom, _map.max_zoom, 0.0, 1.0)

	(%NameBox as Control).modulate.a = clamp(remap(zoom_level, 0.1, 0.2, 0, 1), 0, 1)

	(%RecipesBox as Control).modulate.a = clamp(remap(zoom_level, 0.1, 0.2, 0, 1), 0, 1)

	(%ShopButton as Control).modulate.a = clamp(remap(zoom_level, 0.1, 0.2, 0, 1), 0, 1)
	(%ShopButton as Control).mouse_filter = MOUSE_FILTER_STOP if (%ShopButton as Control).modulate.a > 0 else MOUSE_FILTER_IGNORE

func _on_shop_button_pressed() -> void:
	Utils.get_active_run().open_shop(SHOP_TRADE.get_loaded() as ShopType)

func _make_tooltip_text() -> String:
	var term := load('res://glossary/terms/standalone/term_capital.tres') as Term
	var text := ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[term.get_term_name(true), term.get_markedup_description()])

	if Skill.get_skill_var(Skill.Var.CAPITAL_CONNECTION):
		var capital_bonuses := Utils.get_active_run().get_unlocked_capital_bonuses()
		text += '\n\n'
		if capital_bonuses:
			text += tr('The <term_lower:capital> currently provides the following <term_lower:bonus>s:[ul]')
			for bonus_type in BonusType.get_all_types():  # In standard order.
				if bonus_type in capital_bonuses:
					text += '%s\n' % bonus_type.get_term_tag()
			text += '[/ul]'
			text += tr('<term:connect_settlement>ing <term_lower:settlement>s to it will <term_lower:satisfy_lack> <term_lower:lack>s of these <term_lower:bonus>s.')
		else:
			text += tr('The <term_lower:capital> doesn\'t currently provide any <term_lower:bonus>s.')

	return text

func _make_shop_tooltip_text() -> String:
	var shop_type := SHOP_TRADE.get_loaded() as ShopType
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[shop_type.get_term_name(true), shop_type.get_markedup_description()])

func _setup_radius_clip() -> void:
	await get_tree().process_frame  # Wait for map to register the object.
	((%RadiusIndicatorFrame as Control).material as ShaderMaterial).set_shader_parameter(
		'landmass_sdf', _map.generated_map.blurred_biome_sdfs[0])
	var map_size := Vector2(_map.get_map_size())
	var relative_position := _map.get_map_object_location(self)
	var indicator_size := Vector2((%RadiusIndicatorFrame as Control).size * scale) / _map.get_map_scale()
	var start_coord := (relative_position - indicator_size / 2) / map_size
	var end_coord := (relative_position + indicator_size / 2) / map_size
	((%RadiusIndicatorFrame as Control).material as ShaderMaterial).set_shader_parameter(
		'global_rect', Vector4(start_coord.x, start_coord.y, end_coord.x, end_coord.y))
