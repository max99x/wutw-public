class_name Tutorial_Haunting_Harmonization
extends TutorialBase

func get_tutorial_type() -> Type:
	return Type.RUN

func start_listening() -> void:
	Utils.get_active_run().signals.stage_started.connect(_on_stage_started)

func stop_listening() -> void:
	Utils.get_active_run().signals.stage_started.disconnect(_on_stage_started)

func _on_stage_started() -> void:
	if _get_haunting():
		ready_to_trigger.emit()

func trigger() -> void:
	var run := Utils.get_active_run()
	var map := run.get_map()
	var haunting := _get_haunting()
	var settlement := haunting.attached_to_settlement
	map.focus_location(settlement.state.map_location, map.max_zoom, 0.5)
	map.view_controls_enabled = false
	await Utils.wait_with_timeout(map.is_camera_moving, 5.0)
	map.view_controls_enabled = true

	var text := tr('''
Starting from <term:season> %d, <term_lower:settlement>s can have <term_lower:haunting>s during <term:harmonization>.

Most of these will trigger even on actions unrelated to the <term_lower:settlement> they appear in.

All <term_lower:haunting>s also appear at the top of the screen for reference.
''').strip_edges() % (run.scaling.first_season_with_settlement_hauntings + 1)

	_outline_controls([haunting])
	_show_tooltip(haunting, text, [Tooltip.RelativeDirection.BELOW, Tooltip.RelativeDirection.RIGHT])

func get_skip_id() -> String:
	return 'haunting_harmonization'

func _get_haunting() -> Haunting_Harmonization:
	var hauntings := Utils.get_active_run().get_current_stage().get_hauntings()
	for haunting in hauntings:
		if haunting is Haunting_Harmonization:
			return haunting as Haunting_Harmonization
	return null
