class_name SpotTypeEntry
extends HBoxContainer

static var BONUS_SCENE := AsyncLoadedResource.new('res://bonuses/bonus.tscn')
static var BONUS_COUNTER_SCENE := AsyncLoadedResource.new('res://bonuses/bonus_counter.tscn')

var spot_type: SpotType
var goal: StageGoal
var is_first_spot: bool = true

@onready var _preview_all_bonuses := Skill.get_skill_var(Skill.Var.PREVIEW_BONUSES) > 0

var _cached_spot_type: SpotType
var _cached_is_first_spot: bool
var _cached_goal_filter: Array[BonusType]
var _cached_max_bonuses: Dictionary[BonusType, int]

var _cached_only_goal: bool = true

func _ready() -> void:
	_update()
	GlobalTooltipSystem.attach(self, _make_tooltip_text,
		[Tooltip.RelativeDirection.RIGHT, Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.BELOW],
		[Tooltip.Alignment.CENTERED])

func _gui_input(input_event: InputEvent) -> void:
	var mouse_event := input_event as InputEventMouseButton
	if not mouse_event:
		return
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if Utils.is_museum_unlocked():
			if spot_type.get_all_upgrades().any(GlobalSaveGame.has_seen_upgrade):
				MuseumBrowser.open_museum_entry(spot_type, UI.Layer.GAME_MENU)
			else:
				GlobalUI.show_error(tr('The <term_lower:spot> type hasn\'t been discovered yet.'))

func setup(in_spot_type: SpotType, in_goal: StageGoal, in_is_first_spot: bool) -> void:
	var only_goal := not (_preview_all_bonuses and Input.is_key_pressed(KEY_CTRL))
	var changed := (spot_type != in_spot_type
				 or goal != in_goal
				 or is_first_spot != in_is_first_spot
				 or only_goal != _cached_only_goal)
	if changed:
		spot_type = in_spot_type
		goal = in_goal
		is_first_spot = in_is_first_spot
		_cached_only_goal = only_goal
		_update()

func _update() -> void:
	if not spot_type:
		return
	(%SpotTypeNameLabel as Label).text = tr(spot_type.name)
	Utils.clear_node(self, 1)
	if goal:
		var goal_filter: Array[BonusType] = goal.bonus_requirements.keys()
		if Skill.get_skill_var(Skill.Var.NONGOAL):
			goal_filter = []
		# HACK: The bonus estimates still don't account for upgrades made visible by events.
		#       But they are a guaranteed lower bound, which is what matters to the player.
		var max_bonuses := _get_max_bonuses(goal_filter)
		var bonus_types := BonusType.get_all_types()
		if GameSettings.Interface.sort_predicted_yields.value():
			bonus_types.sort_custom(func(a: BonusType, b: BonusType) -> bool:
				return max_bonuses.get(a, 0) > max_bonuses.get(b, 0))
		else:
			bonus_types.sort_custom(func(a: BonusType, b: BonusType) -> bool:
				return goal.bonus_requirements.get(a, 0) > goal.bonus_requirements.get(b, 0))
		var only_goal := not (_preview_all_bonuses and Input.is_key_pressed(KEY_CTRL))
		for bonus_type: BonusType in bonus_types:
			if only_goal and bonus_type not in goal.bonus_requirements:
				continue
			var counter := BONUS_COUNTER_SCENE.instantiate_loaded_scene() as BonusCounter
			counter.bonus_type = bonus_type
			counter.current_value = max_bonuses.get(bonus_type, 0)
			counter.label_first = true
			counter.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
			counter.custom_minimum_size.x = 50
			if not only_goal and bonus_type in goal.bonus_requirements:
				counter.highlight_type = Bonus.HighlightType.POSITIVE
			add_child(counter)
	elif Skill.get_skill_var(Skill.Var.CAPITAL_INITIAL_PROVISION):
		var bonus := BONUS_SCENE.instantiate_loaded_scene() as Bonus
		bonus.bonus_type = spot_type.granted_capital_bonus
		bonus.custom_minimum_size = Vector2(32, 32)
		bonus.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		add_child(bonus)

func _make_tooltip_text() -> String:
	if Utils.is_in_editor():
		return ''

	var pieces: Array[String]
	if not goal:
		if Skill.get_skill_var(Skill.Var.CAPITAL_INITIAL_PROVISION):
			pieces.append('<header_font_size>[b]<term:spot>: %s[/b][/font_size]' % tr(spot_type.name))
			pieces.append('\n\n')
			pieces.append(tr('This will provide %s from the capital.') % spot_type.granted_capital_bonus.get_term_tag())
			return ''.join(pieces)
		else:
			pieces.append('<header_font_size>[b]<term:spot>: %s[/b][/font_size]' % tr(spot_type.name))
			pieces.append('\n\n')
			pieces.append(tr('A valid location for the capital.'))
			return ''.join(pieces)

	if _preview_all_bonuses:
		var goal_filter: Array[BonusType] = goal.bonus_requirements.keys()
		if Skill.get_skill_var(Skill.Var.NONGOAL):
			goal_filter = []
		var max_bonuses := _get_max_bonuses(goal_filter)
		var sorted_bonuses: Array[BonusType] = max_bonuses.keys()
		sorted_bonuses.sort_custom(func(a: BonusType, b: BonusType) -> bool:
			return max_bonuses[a] > max_bonuses[b]
		)

		pieces.append('<header_font_size>[b]<term:spot>: %s[/b][/font_size]' % tr(spot_type.name))
		pieces.append('\n\n')
		pieces.append(tr('Maximum <term_lower:bonus>s:'))
		pieces.append('[ul]\n')
		for bonus_type in sorted_bonuses:
			pieces.append('%s: %d\n' % [bonus_type.get_term_tag(), max_bonuses[bonus_type]])
		pieces.append('[/ul]\n\n')

	pieces.append(tr('[i]“%s”[/i]') % tr(spot_type.description))

	if spot_type.get_all_upgrades().any(GlobalSaveGame.has_seen_upgrade):
		if Utils.is_museum_unlocked():
			pieces.append('\n\n')
			pieces.append(tr('[i]%s to open museum entry.[/i]') % InputPrompts.get_input_markup(
				InputPrompts.InputType.RIGHT_CLICK))
	else:
		pieces.append('\n\n')
		pieces.append(tr('[b]This spot type has not been discovered yet.[/b]'))

	return ''.join(pieces)

func _get_max_bonuses(goal_filter: Array[BonusType]) -> Dictionary[BonusType, int]:
	var cache_hit := (_cached_spot_type == spot_type
				  and _cached_is_first_spot == is_first_spot
				  and _cached_goal_filter == goal_filter)
	if not cache_hit:
		_cached_spot_type = spot_type
		_cached_is_first_spot = is_first_spot
		_cached_goal_filter = goal_filter
		_cached_max_bonuses = StageSatisfiability.get_max_spot_bonuses(
			Utils.get_active_run(), spot_type, is_first_spot, goal_filter)
	return _cached_max_bonuses
