class_name StageSelector
extends Node2D

enum Mode {SETTLEMENT, CAPITAL, EXISTING_CAPITAL, SURVEY}
enum State {INITIAL, IDLE, SELECTING, CONFIRMING, FORCE_END}

signal location_selected(map_location: Vector2)

static var STAGE_LOCATION_TARGET_SCENE := AsyncLoadedResource.new('res://stage/selector/stage_location_target.tscn')
static var SPOT_TYPE_ENTRY_SCENE := AsyncLoadedResource.new('res://stage/selector/spot_type_entry.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var EVENT_LIST_ENTRY_SCENE := AsyncLoadedResource.new('res://stage/selector/event_list_entry.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var HAUNTING_LIST_ENTRY_SCENE := AsyncLoadedResource.new('res://stage/selector/haunting_list_entry.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)

const DEFAULT_ZOOM := 4
const MIN_DISTANCE_FROM_EDGE_SETTLEMENT := 5
const MIN_DISTANCE_FROM_EDGE_CAPITAL := 16
const MIN_DISTANCE_FROM_EDGE_SURVEY := 2
const MAX_SNAP_DISTANCE := 10
const SNAP_GRADIENT_SAMPLE_DISTANCE := 4.0
const SNAP_GRADIENT_ITERATIONS := 3
const SNAP_SETTLEMENT_ITERATIONS := 5

var mode: Mode
var goal: StageGoal  # Only for regular stages.
var location_radius: int = 15
var num_spots: int = 2

var _state: State = State.INITIAL:
	set = _set_state
var _error: StageSelector.Error = null:
	set = _set_error
var _map: Map
var _stage_event_selector: StageEventSelector
var _stage_location_target: StageLocationTarget
var _selected_location: Vector2
var _last_valid_location: Vector2
var _canceling := false
var _clouds_image: Image
# Shortcuts for unlocks to aid readability.
@onready var _preview_all_bonuses := Skill.get_skill_var(Skill.Var.PREVIEW_BONUSES) > 0
@onready var _preview_events := Skill.get_skill_var(Skill.Var.PREVIEW_EVENTS) > 0
@onready var _preview_hauntings := Skill.get_skill_var(Skill.Var.PREVIEW_HAUNTING) > 0

func _ready() -> void:
	var run := Utils.get_active_run()
	_map = run.get_map()
	_clouds_image = _map.generated_map.blurred_biome_sdfs[MapBiomes.CLOUDS].get_image()

	# Clean setup.
	(%ErrorLabel as Control).visible = false
	(%EventsList as Control).visible = false
	(%HauntingsList as Control).visible = false
	(%CapitalLabel as Control).visible = false
	(%SurveyPreviewEntry as Control).visible = false
	(%CtrlHintLabel as Control).visible = false
	Utils.clear_node(%StageList, 2)

	var title_label := %TitleLabel as Label
	if mode == Mode.SETTLEMENT:
		for _i in num_spots:
			var spot_type_entry := SPOT_TYPE_ENTRY_SCENE.instantiate_loaded_scene() as SpotTypeEntry
			spot_type_entry.visible = false
			%StageList.add_child(spot_type_entry)

		var stage_index_within_season := run.get_current_stage_index() % run.scaling.stages_per_season
		if run.scaling.stages_per_season >= 100:  # Tutorial
			title_label.text = tr('Foray %d') % [stage_index_within_season + 1]
		else:
			title_label.text = tr('Phase %d - Foray %d of %d') % [
				run.get_current_season_index() + 1, stage_index_within_season + 1, run.scaling.stages_per_season]
		(%SelectButton as Button).text = tr('Choose Foray Location')
		(%StartButton as Button).text = tr('Start Foray')
		run.get_stage_goal_tracker().visible = true
		run.get_stage_goal_tracker().goal = goal
		GlobalTooltipSystem.attach(title_label, _make_foray_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])

		_stage_event_selector = StageEventSelector.new()
	elif mode in [Mode.CAPITAL, Mode.EXISTING_CAPITAL]:
		var spot_type_entry := SPOT_TYPE_ENTRY_SCENE.instantiate_loaded_scene() as SpotTypeEntry
		spot_type_entry.visible = false
		%StageList.add_child(spot_type_entry)
		title_label.text = tr('Phase %d - Convergence') % (run.get_current_season_index() + 1)
		(%SelectButton as Button).text = tr('Choose Capital Location')
		(%StartButton as Button).text = tr('Start Convergence')
		(%StartButton_ConfirmOnly as Button).text = tr('Start Convergence')
		run.get_stage_goal_tracker().visible = false
		GlobalTooltipSystem.attach(title_label, _make_harmonization_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])
	elif mode == Mode.SURVEY:
		title_label.text = tr('Phase %d - Regional Survey') % (run.get_current_season_index() + 1)
		(%SelectButton as Button).text = tr('Choose Survey Location')
		(%StartButton as Button).text = tr('Start Survey')
		run.get_stage_goal_tracker().visible = false
		GlobalTooltipSystem.attach(title_label, _make_survey_text,
			[Tooltip.RelativeDirection.BELOW], [Tooltip.Alignment.CENTERED])
	else:
		Utils.ensure(false)

	_map.view_controls_enabled = true
	if run.get_current_stage_index() == 0:
		_map.focus_location(_map.generated_map.starting_point, DEFAULT_ZOOM, 2.5)
	else:
		_map.focus_location(_map.get_current_target_position(), minf(_map.get_zoom(), DEFAULT_ZOOM))

	_state = State.IDLE
	if mode == Mode.EXISTING_CAPITAL:
		_state = StageSelector.State.CONFIRMING
	elif mode == Mode.SETTLEMENT and run.get_current_stage_index() == 0:
		_state = StageSelector.State.SELECTING

	var tween := create_tween()
	modulate.a = 0
	tween.tween_property(self, 'modulate:a', 1.0, 0.5)
	tween.set_speed_scale(Utils.anim_speed())
	tween.play()

	GlobalUI.ui_hide_toggled.connect(func() -> void:
		modulate.a = 0 if GlobalUI.is_ui_hidden() else 1
	)

func _enter_tree() -> void:
	var run := Utils.get_active_run()
	run.foray_goal_rerolled.connect(_on_goal_rerolled)

func _exit_tree() -> void:
	var run := Utils.get_active_run()
	if run:
		run.foray_goal_rerolled.disconnect(_on_goal_rerolled)
	_map.view_controls_enabled = false
	_map.flip_settlement_list = false
	if _stage_location_target:
		_stage_location_target.remove()
		_stage_location_target = null

func _process(_delta: float) -> void:
	var offset_node := %NewStageOffset as Control
	if GlobalUI.is_higher_level_active(self):
		offset_node.visible = false
		return
	elif _state == State.CONFIRMING:
		if mode != Mode.EXISTING_CAPITAL:
			offset_node.visible = true
		else:
			offset_node.visible = false
			return
	elif _state in [State.IDLE, State.FORCE_END]:
		return

	var map_location: Vector2
	if _state == State.SELECTING:
		# Position target at cursor.
		map_location = _map.get_location_at_screen_position(get_global_mouse_position())
		_map.set_map_object_location(_stage_location_target, map_location - _stage_location_target.size / 2 / _map.get_map_scale())
	else:
		map_location = (_map.get_map_object_location(_stage_location_target)
				+ _stage_location_target.size / 2 / _map.get_map_scale())

	# Position UI to follow target.
	var ui_location := _map.get_screen_position_at_location(map_location + Vector2(location_radius, 0))
	var infobox_container := %NewStageContainer as Control
	offset_node.position = ui_location
	offset_node.position.y -= infobox_container.size.y / 2
	if infobox_container.get_global_rect().end.x >= 1920:
		offset_node.position.x = _map.get_screen_position_at_location(map_location - Vector2(location_radius, 0)).x
		offset_node.position.x -= infobox_container.size.x
		offset_node.position.x -= 15 # margin

	if infobox_container.get_global_rect().position.y <= 80:
		offset_node.position.y = 80
	elif infobox_container.get_global_rect().end.y >= 1080:
		offset_node.position.y = 1080 - infobox_container.size.y
	infobox_container.size = Vector2.ZERO  # Force minimal size.

	# If we aren't selecting, the contents of the details are fixed.
	# Important, as rebuilding them every frame breaks tooltips.
	if _state != State.SELECTING:
		return

	# Snap to shard edge. Before fog of war to differentiate clouds.
	var snapped_to_shard := _snap_to_sdf(
		map_location, _clouds_image, _get_min_distance_to_shard_edge(), true)
	if snapped_to_shard.distance_to(map_location) <= MAX_SNAP_DISTANCE:
		map_location = snapped_to_shard
		_map.set_map_object_location(_stage_location_target, map_location - _stage_location_target.size / 2 / _map.get_map_scale())
		_stage_location_target.visible = true
		offset_node.visible = true
	else:
		_error = Error.new(tr('Invalid Location'), tr('Must be on the shard.'),
						   tr('Must select a location the shard landmass.'))
		_stage_location_target.visible = false
		offset_node.visible = false
		return

	# Snap to fog of war.
	var snapped_to_fow := _snap_to_sdf(map_location, _map.fow_image, 0)
	if snapped_to_fow.distance_to(map_location) <= MAX_SNAP_DISTANCE:
		map_location = snapped_to_fow
		_map.set_map_object_location(_stage_location_target, map_location - _stage_location_target.size / 2 / _map.get_map_scale())
	else:
		_error = Error.new(tr('Unexplored'), tr('Must explore this area first.'),
						   tr('Cannot select outside the explored area.'))
		return

	# Snap to existing settlement borders.
	var snapped_to_settlements := _snap_to_map_objects(map_location)
	if snapped_to_settlements.distance_to(map_location) <= MAX_SNAP_DISTANCE:
		map_location = snapped_to_settlements
		_map.set_map_object_location(_stage_location_target, map_location - _stage_location_target.size / 2 / _map.get_map_scale())
	else:
		_error = Error.new(tr('Already Settled'), tr('Too close to settlement.'),
						   tr('Cannot select so close to another settlement.'))
		return

	if mode == Mode.SETTLEMENT:
		_process_foray(map_location)
	elif mode in [Mode.CAPITAL, Mode.EXISTING_CAPITAL]:
		_process_capital(map_location)
	elif mode == Mode.SURVEY:
		_process_survey(map_location)
	else:
		Utils.ensure(false)

	if not _error:
		_last_valid_location = map_location

func _process_foray(map_location: Vector2) -> void:
	# Check valid spot types.
	var spot_types := _map.get_spot_types_at_position(map_location, location_radius, num_spots)
	if not spot_types:
		_error = Error.new(tr('Invalid Location'), tr('Must settle on dry land.'),
						   tr('Cannot select a location outside of dry land.'))
		return

	# Sort spot types consistently for display so the UI doesn't change with irrelefant order changes.
	var unsorted_spot_types := spot_types.duplicate()  # Used to get consistent event/haunting predictions.
	spot_types.sort_custom(func(a: SpotType, b: SpotType) -> bool: return tr(a.name) < tr(b.name))

	for i in num_spots:
		var spot_type_entry := %StageList.get_child(2 + i) as SpotTypeEntry
		spot_type_entry.setup(spot_types[i], goal, spot_types[i] not in spot_types.slice(0, i))
		spot_type_entry.visible = true

	var run := Utils.get_active_run()

	# We're finally good to go!
	_error = null
	(%HeaderLabel as Label).text = tr('Potential Yields')

	# IMPORTANT: Snapshot the events RNG, and use it *first* on events, then hauntings.
	var events_rng := run.get_events_random().snapshot()

	# Predict events.
	var selected_events := _stage_event_selector.select_events(
		events_rng, run, unsorted_spot_types, goal.bonus_requirements.keys())
	(%EventsList as Control).visible = _preview_events and not selected_events.is_empty()
	if selected_events:
		Utils.clear_node(%EventsList, 1)
		for event: Event_Stage in selected_events.values():
			var entry := EVENT_LIST_ENTRY_SCENE.instantiate_loaded_scene() as EventListEntry
			entry.event = event
			%EventsList.add_child(entry)

	# Predict hauntings.
	Utils.clear_node(%HauntingsList, 1)
	var hauntigs_roll_result := HauntingType.choose_spot_hauntings(
		unsorted_spot_types, events_rng, run.get_run_data().haunting_leftover_roll)
	for haunting_type in hauntigs_roll_result.hauntings:
		if haunting_type:
			var entry := HAUNTING_LIST_ENTRY_SCENE.instantiate_loaded_scene() as HauntingListEntry
			entry.haunting_type = haunting_type
			%HauntingsList.add_child(entry)
	(%HauntingsList as Control).visible = _preview_hauntings and %HauntingsList.get_child_count() > 1
	if Utils.is_realistic_era():
		(%HauntingsLabel as Label).text = tr('Challenges')
	else:
		(%HauntingsLabel as Label).text = tr('Hauntings')

	(%CtrlHintLabel as Control).visible = _preview_all_bonuses

func _process_capital(map_location: Vector2) -> void:
	# Check valid spot types.
	var spot_types := _map.get_spot_types_at_position(map_location, location_radius, num_spots)
	if not spot_types:
		_error = Error.new(tr('Invalid Location'), tr('Must settle on dry land.'),
						   tr('Cannot select a location outside of dry land.'))
		return

	_error = null
	(%HeaderLabel as Label).text = tr('Potential Capital')
	(%CapitalLabel as Label).visible = true
	var spot_type_entry := %StageList.get_child(2) as SpotTypeEntry
	spot_type_entry.setup(spot_types[0], goal, true)
	spot_type_entry.visible = true

func _process_survey(map_location: Vector2) -> void:
	if [MapBiomes.Biome.SEA] == _map.get_biomes_in_radius(map_location, _get_min_distance_to_shard_edge()):
		_error = Error.new(tr('Invalid Survey Location'), tr('Must be on dry land.'),
						   tr('Surveys can only start on dry land.'))
		return

	var available_episodes: Array[SurveyEpisode]
	var run := Utils.get_active_run()
	available_episodes.assign(SurveyEpisode.choose_episodes(run, map_location).keys())
	if not available_episodes:
		push_warning('Found location with no survey episodes.')
		_error = Error.new(tr('Invalid Survey Location'), tr('No survey encounters possible here.'),
						   tr('Must select a location with possble survey encounters.'))
		return

	_error = null
	(%HeaderLabel as Label).text = tr('Survey Departure Point')
	(%SurveyPreviewEntry as SurveyPreviewEntry).episodes = available_episodes
	(%SurveyPreviewEntry as SurveyPreviewEntry).visible = true

func _handle_esc() -> bool:
	if _state == State.SELECTING:
		_state = State.IDLE
		return true
	elif _state == State.CONFIRMING and mode != Mode.EXISTING_CAPITAL:
		_state = State.SELECTING
		return true
	else:
		return false

func fade_out() -> void:
	for child in get_children():
		if child is Control:
			Utils.set_input_enabled(child as Control, false)
	var tween := create_tween()
	tween.tween_property(self, 'modulate:a', 0.0, 0.25)
	tween.set_speed_scale(Utils.anim_speed())
	tween.play()
	await tween.finished

func set_force_end() -> void:
	# Used by the tutorial quest.
	_state = StageSelector.State.FORCE_END

func is_selecting() -> bool:
	return _state == StageSelector.State.SELECTING

func _set_map_planning_mode(planning: bool) -> void:
	for map_object in _map.get_map_objects():
		if map_object is Settlement:
			(map_object as Settlement).mode = Settlement.Mode.PLANNING if planning else Settlement.Mode.SHOPPABLE
		elif map_object is Capital:
			(map_object as Capital).mode = Capital.Mode.PLANNING if planning else Capital.Mode.SHOPPABLE

	if planning:
		if not _map.clicked.is_connected(_handle_map_clicked):
			_map.clicked.connect(_handle_map_clicked)
	else:
		if _map.clicked.is_connected(_handle_map_clicked):
			_map.clicked.disconnect(_handle_map_clicked)
		_map.flip_settlement_list = false

func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	match _state:
		State.INITIAL:
			pass
		State.IDLE:
			(%NewStageOffset as Control).visible = false
			(%CancelButton as Control).visible = false
			(%CancelForayButton as Control).visible = false
			(%SelectButton as Control).visible = true
			(%StartButton as Control).visible = false
			(%StartButton_ConfirmOnly as Control).visible = false
			(%EndRunButton as Control).visible = Utils.is_early_finishing_unlocked()
			if _stage_location_target:
				_stage_location_target.remove()
				_stage_location_target = null
			_set_map_planning_mode(false)
		State.SELECTING:
			(%NewStageOffset as Control).visible = true
			(%CancelButton as Control).visible = true
			(%CancelForayButton as Control).visible = false
			(%SelectButton as Control).visible = false
			(%StartButton as Control).visible = false
			(%StartButton_ConfirmOnly as Control).visible = false
			(%EndRunButton as Control).visible = false
			(%CtrlHintLabel as Control).visible = mode == Mode.SETTLEMENT and _preview_all_bonuses
			if not _stage_location_target:
				_stage_location_target = STAGE_LOCATION_TARGET_SCENE.instantiate_loaded_scene()
				_map.add_map_object(_stage_location_target)
				_stage_location_target.size = location_radius * 2 * _map.get_map_scale()
				_stage_location_target.pivot_offset = _stage_location_target.size / 2
			_stage_location_target.confirmed = false
			_set_map_planning_mode(true)
		State.CONFIRMING:
			(%NewStageOffset as Control).visible = mode != Mode.EXISTING_CAPITAL
			(%CancelButton as Control).visible = false
			(%CancelForayButton as Control).visible = mode != Mode.EXISTING_CAPITAL
			(%SelectButton as Control).visible = false
			(%StartButton as Control).visible = mode != Mode.EXISTING_CAPITAL
			(%StartButton_ConfirmOnly as Control).visible = mode == Mode.EXISTING_CAPITAL
			(%EndRunButton as Control).visible = false
			(%CtrlHintLabel as Control).visible = false
			if _stage_location_target:  # Null when starting S2+ convergence.
				_stage_location_target.confirmed = true
			_set_map_planning_mode(false)
		State.FORCE_END:
			(%NewStageOffset as Control).visible = false
			(%CancelButton as Control).visible = false
			(%CancelForayButton as Control).visible = false
			(%SelectButton as Control).visible = false
			(%StartButton as Control).visible = false
			(%StartButton_ConfirmOnly as Control).visible = false
			(%EndRunButton as Control).visible = true
			(%CtrlHintLabel as Control).visible = false
			if _stage_location_target:
				_stage_location_target.visible = false  # Avoid showing it in the first place.
			_set_map_planning_mode(false)

func _handle_map_clicked(_map_location: Vector2) -> void:
	if GlobalUI.is_higher_level_active(self) or _canceling:
		return
	Utils.ensure(_state == State.SELECTING)
	if Utils.get_hovered_control() and not _map.is_ancestor_of(Utils.get_hovered_control()):
		return
	_map.stop_focus_tween()
	if _error:
		GlobalUI.show_error(_error.explanation)
	else:
		_selected_location = _last_valid_location
		_state = State.CONFIRMING

func _set_error(new_error: StageSelector.Error) -> void:
	if new_error == _error:
		return
	_error = new_error
	var error_label := %ErrorLabel as Label
	if _error:
		(%HeaderLabel as Label).text = _error.title
		error_label.text = _error.summary
		error_label.visible = true
		for i in num_spots:
			(%StageList.get_child(2 + i) as Control).visible = false
		(%EventsList as Control).visible = false
		(%HauntingsList as Control).visible = false
		(%CapitalLabel as Control).visible = false
		(%SurveyPreviewEntry as Control).visible = false
		(%CtrlHintLabel as Control).visible = false
		_stage_location_target.modulate = Color.FIREBRICK
	else:
		error_label.visible = false
		_stage_location_target.modulate = Color.BLACK

func _on_select_button_pressed() -> void:
	match _state:
		State.IDLE:
			_state = State.SELECTING
		_:
			assert(false)

func _on_cancel_button_pressed() -> void:
	# HACK: We keep a canceling flag on for a frame to prevent the map click from triggering instantly afterwards.
	_canceling = true
	await get_tree().process_frame
	if _state == State.SELECTING:
		_state = State.IDLE
	elif _state == State.CONFIRMING and mode != Mode.EXISTING_CAPITAL:
		_state = State.SELECTING
	_canceling = false

func _on_start_button_pressed() -> void:
	match _state:
		State.CONFIRMING:
			set_process(false)
			if _stage_location_target:
				_stage_location_target.remove()
				_stage_location_target = null
			location_selected.emit(_selected_location)
		_:
			assert(false)

func _on_start_button_confirm_only_pressed() -> void:
	_on_start_button_pressed()

func _on_end_run_button_pressed() -> void:
	if _state == StageSelector.State.FORCE_END:
		Utils.get_active_run().set_state(RunData.State.RUN_WON)
		return

	var prompt := tr('Are you sure you want to finish this expedition?')
	prompt += '\n\n'
	var run := Utils.get_active_run()
	var insights := run.get_total_insights_gained()
	insights += run.get_insights_from_discoveries()
	var bonus_insights := run.scaling.get_early_exit_insights_bonus(insights)
	if bonus_insights:
		prompt += tr_n(
			'You will gain %d bonus insight in addition to the %d you earned for returning before inspiration is exhausted.',
			'You will gain %d bonus insights in addition to the %d you earned for returning before inspiration is exhausted.',
			bonus_insights) % [bonus_insights, insights]
	GlobalUI.show_confirm(tr('Finish Expedition?'), prompt).confirmed.connect(func() -> void:
		Utils.get_active_run().set_state(RunData.State.RUN_WON)
	)

func _make_foray_text() -> String:
	var term := load('res://glossary/terms/standalone/term_stage.tres') as Term
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[term.get_term_name(true), term.get_markedup_description()])

func _make_harmonization_text() -> String:
	var term := load('res://glossary/terms/standalone/term_harmonization.tres') as Term
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[term.get_term_name(true), term.get_markedup_description()])

func _make_survey_text() -> String:
	var term := load('res://glossary/terms/standalone/term_survey.tres') as Term
	return ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
			[term.get_term_name(true), term.get_markedup_description()])

func _get_min_distance_to_shard_edge() -> int:
	if mode == Mode.SETTLEMENT:
		return MIN_DISTANCE_FROM_EDGE_SETTLEMENT
	elif mode in [Mode.CAPITAL, Mode.EXISTING_CAPITAL]:
		return MIN_DISTANCE_FROM_EDGE_CAPITAL
	elif mode == Mode.SURVEY:
		return MIN_DISTANCE_FROM_EDGE_SURVEY
	else:
		assert(false)
		return 0

func _snap_to_sdf(map_location: Vector2, sdf: Image, margin: float, invert: bool = false) -> Vector2:
	var dist := _sample_sdf(map_location, sdf, margin, invert)
	if dist <= 0:
		return map_location
	elif dist >= _map.generation_config.sdf_max_distance:
		return Vector2(-1, -1)

	var span := SNAP_GRADIENT_SAMPLE_DISTANCE
	var dx := (_sample_sdf(Vector2(map_location.x + span, map_location.y),sdf, margin, invert)
			 - _sample_sdf(Vector2(map_location.x - span, map_location.y), sdf, margin, invert))
	var dy := (_sample_sdf(Vector2(map_location.x, map_location.y + span), sdf, margin, invert)
			 - _sample_sdf(Vector2(map_location.x, map_location.y - span), sdf, margin, invert))

	var dir := Vector2(dx, dy)
	if dir == Vector2.ZERO:
		return map_location
	dir = dir.normalized()

	var p_edge := map_location - (dir * dist)
	for i in SNAP_GRADIENT_ITERATIONS:
		var error_dist := _sample_sdf(p_edge, sdf, margin, invert)
		if abs(error_dist) <= 0.01:
			break
		p_edge -= dir * error_dist

	return p_edge

func _sample_sdf(map_location: Vector2, sdf: Image, margin: float = 0.0, invert: bool = false) -> float:
	var max_x := sdf.get_width() - 1
	var max_y := sdf.get_height() - 1

	var x := clampf(map_location.x, 0.0, float(max_x))
	var y := clampf(map_location.y, 0.0, float(max_y))

	var x0 := int(x)
	var y0 := int(y)
	var x1 := mini(x0 + 1, max_x)
	var y1 := mini(y0 + 1, max_y)

	var tx := x - float(x0)
	var ty := y - float(y0)

	var val00 := sdf.get_pixel(x0, y0).r
	var val10 := sdf.get_pixel(x1, y0).r
	var val01 := sdf.get_pixel(x0, y1).r
	var val11 := sdf.get_pixel(x1, y1).r

	var top := lerpf(val00, val10, tx)
	var bottom := lerpf(val01, val11, tx)

	var dist_raw := lerpf(top, bottom, ty)
	var dist: float
	if invert:
		dist = remap(dist_raw, 1, 0, -_map.generation_config.sdf_max_distance, _map.generation_config.sdf_max_distance)
	else:
		dist = remap(dist_raw, 0, 1, -_map.generation_config.sdf_max_distance, _map.generation_config.sdf_max_distance)
	return margin + dist

func _snap_to_map_objects(map_location: Vector2) -> Vector2:
	var current_pos := map_location
	var hit_any := false

	var effective_radius := location_radius
	var overlap_percent := Skill.get_skill_var(Skill.Var.SETTLEMENT_OVERLAP_PERCENT)
	effective_radius = floori(effective_radius * (1.0 - overlap_percent / 100.0))
	effective_radius -= 1  # For player convenience so that radius visuals match up better.

	for iter in SNAP_SETTLEMENT_ITERATIONS + 1:
		var snapped_this_pass := false

		for map_object in _map.get_map_objects():
			if not (map_object is Settlement or map_object is Capital):
				continue

			@warning_ignore('unsafe_method_access')  # Duck Type
			var center: Vector2 = map_object.get_map_location()
			var dist_to_center := current_pos.distance_to(center)
			@warning_ignore('unsafe_method_access')  # Duck Type
			var max_dist: float = effective_radius + map_object.get_radius()

			if dist_to_center < max_dist:
				var dir := (current_pos - center).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.RIGHT
				current_pos = center + (dir * (max_dist + 0.01))
				hit_any = true
				snapped_this_pass = true
		if not snapped_this_pass:
			break
		# We have been snapping to the very last iteration.
		# Let's make sure the final result is valid.
		if iter == SNAP_SETTLEMENT_ITERATIONS and hit_any:
			for map_object in _map.get_map_objects():
				if not (map_object is Settlement or map_object is Capital):
					continue
				@warning_ignore('unsafe_method_access')  # Duck Type
				var center: Vector2 = map_object.get_map_location()
				var dist_to_center := current_pos.distance_to(center)
				@warning_ignore('unsafe_method_access')  # Duck Type
				var max_dist: float = effective_radius + map_object.get_radius()
				if dist_to_center < max_dist:
					return Vector2(-1, -1)

	if hit_any:
		return current_pos
	else:
		return map_location

func _on_goal_rerolled() -> void:
	assert(goal)

	var run := Utils.get_active_run()
	goal = run.get_run_data().current_settlement_state.goal

	_state = State.IDLE

func _on_spot_placement_button_started() -> void:
	if mode == Mode.EXISTING_CAPITAL:
		_state = StageSelector.State.CONFIRMING
	else:
		_state = State.IDLE
	(%ButtonsContainer as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	(%EndRunButton as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	(%PlacementButtonContainer as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED

func _on_spot_placement_button_finished(_success: bool) -> void:
	(%ButtonsContainer as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	(%EndRunButton as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	(%PlacementButtonContainer as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED

class Error extends RefCounted:
	var title: String
	var summary: String
	var explanation: String

	func _init(in_title: String, in_summary: String, in_explanation: String) -> void:
		title = in_title
		summary = in_summary
		explanation = in_explanation
