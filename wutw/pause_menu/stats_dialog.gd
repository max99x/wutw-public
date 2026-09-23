class_name StatsDialog
extends Control

var _closing := false

func _ready() -> void:
	# Haunt chance is special.
	(%HauntChanceTextLabel as Label).text = (
		tr('Base Challenge Chance') if Utils.is_realistic_era() else tr('Base Haunting Chance'))
	var haunt_probability := HauntingType.get_base_haunt_probability(Utils.get_active_run())
	(%HauntChanceValueLabel as Label).text = '%d%%' % roundi(haunt_probability * 100)
	(%HauntChanceValueLabel as Label).visible = Utils.are_hauntings_unlocked()
	GlobalTooltipSystem.attach(
		%HauntChanceBox as Control, _make_haunt_chanch_tooltip,
		[Tooltip.RelativeDirection.RIGHT], [Tooltip.Alignment.CENTERED])

	(%ScrollPanel as ScrollPanel).animate_unroll()

func _handle_esc() -> bool:
	close()
	return true

func close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(self, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		queue_free()

func _on_close_button_pressed() -> void:
	close()

func _make_haunt_chanch_tooltip() -> String:
	var run := Utils.get_active_run()
	return tr('For each <term_lower:spot>, %s chance is %d%% + 1%% per %d total yields.') % [
		tr('Challenge') if Utils.is_realistic_era() else tr('Haunting'),
		roundi(run.scaling.haunting_base_probability * 100),
		run.scaling.haunting_bonus_per_extra_chance
	]
