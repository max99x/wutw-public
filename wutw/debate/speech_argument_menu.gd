class_name SpeechArgumentMenu
extends Node2D

signal closed
signal speech_confirmed(argument: DebateArgument)

@export var talisman_arguments: Array[DebateArgument]
@export var forest_shrine_arguments: Array[DebateArgument]
@export var lake_shrine_argument: DebateArgument
@export var fox_arguments: Array[DebateArgument]
@export var final_argument: DebateArgument

var _closing: bool

func _ready() -> void:
	Utils.clear_node(%ArgumentsList)
	var group := ButtonGroup.new()
	var all_arguments := DebateArgument.get_all_arguments().values()
	for argument: DebateArgument in all_arguments:
		if GlobalSaveGame.is_argument_unlocked(argument) and not GlobalSaveGame.is_argument_used(argument):
			var button := UkiyoeButton.new()
			button.text = tr(argument.name)
			button.button_group = group
			button.toggle_mode = true
			button.button_pressed = false
			button.set_meta('argument', argument)
			%ArgumentsList.add_child(button)
	Utils.ensure(%ArgumentsList.get_child_count() > 0)
	(%ArgumentsList.get_child(0) as Button).button_pressed = true

	(%NoMissableLabel as Label).visible = all_arguments.size() == 1 and _get_num_missable_arguments() == 0

	(%ScrollPanel as ScrollPanel).animate_unroll()

func _handle_esc() -> bool:
	_close()
	return true

func _on_close_button_pressed() -> void:
	_close()

func _close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		closed.emit()
		queue_free()

func _on_send_button_pressed() -> void:
	var argument: DebateArgument
	for button: Button in %ArgumentsList.get_children():
		if button.button_pressed:
			argument = button.get_meta('argument') as DebateArgument
			break
	assert(argument)

	if argument == final_argument:
		var num_missable := _get_num_missable_arguments()
		if num_missable > 0:
			var prompt := tr('Giving this final speech will lead to the game\'s ending.')
			prompt += '\n\n'
			prompt += tr_n(
				'You will be able to continue playing afterwards, but you will permanently miss %d speech.',
				'You will be able to continue playing afterwards, but you will permanently miss %d speeches.',
				num_missable) % num_missable
			var confirm := GlobalUI.show_confirm(tr('Finish Debate?'), prompt, tr('Yes, let\'s end this!'), tr('No, wait!'))
			await confirm.confirmed  # If not confirmed, never continues.

	speech_confirmed.emit(argument)
	_close()

func _get_num_missable_arguments() -> int:
	var num_missable := 0

	if not GlobalSaveGame.is_argument_used(lake_shrine_argument):
		if GlobalSaveGame.get_events_state().get_bool_or_default('shrine_ritual', 'waterline', false):
			num_missable += 1

	var any_talisman_used := false
	for argument in talisman_arguments:
		if GlobalSaveGame.is_argument_used(argument):
			any_talisman_used = true
			break
	if not any_talisman_used:
		num_missable += 1

	var any_magic_used := false
	for argument in fox_arguments:
		if GlobalSaveGame.is_argument_used(argument):
			any_magic_used = true
			break
	if not any_magic_used:
		num_missable += 1

	var any_religion_used := false
	for argument in forest_shrine_arguments:
		if GlobalSaveGame.is_argument_used(argument):
			any_religion_used = true
			break
	if not any_religion_used:
		num_missable += 1

	for argument: DebateArgument in DebateArgument.get_all_arguments().values():
		if argument == final_argument:
			continue
		if argument == lake_shrine_argument:
			continue
		if argument in talisman_arguments:
			continue
		if argument in forest_shrine_arguments:
			continue
		if argument in fox_arguments:
			continue
		if not GlobalSaveGame.is_argument_used(argument):
			num_missable += 1

	return num_missable
