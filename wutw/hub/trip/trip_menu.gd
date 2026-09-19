class_name TripMenu
extends Node2D

signal closed

static var TRIP_OPTION_BUTTON_SCENE := AsyncLoadedResource.new('res://hub/trip/trip_option.tscn', true, AsyncLoadedResource.LoadPhase.SPECULATIVE)

const MIN_SEASONS_SINCE_SETTLED := 2
const INSIGHTS_REWARD := 20
const MAX_QUEUED_TRIPS := 5

@export var random_trip_rewards: RandomTripRewards
@onready var _runs_button_group: ButtonGroup = ButtonGroup.new()
var _selected_run: PastRun
var _last_selected_index := 0
var _claiming_trip_uid: int = 0
var _current_reward: TripReward
var _closing: bool

func _ready() -> void:
	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)
	_refresh_state()
	(%ScrollPanel as ScrollPanel).animate_unroll()

func _update_font_size() -> void:
	Utils._scale_font_size(%EmptyLabel as RichTextLabel, false, 16)
	Utils._scale_font_size(%InProgressLabel as RichTextLabel, false, 16)
	Utils._scale_font_size(%FinishedLabel as RichTextLabel, false, 16)
	Utils._scale_font_size(%ReportLabel as RichTextLabel, false, 16)
	Utils._scale_font_size(%Label_SkillDescription as RichTextLabel, false, 16)

func _handle_esc() -> bool:
	_close()
	return true

func _on_close_button_pressed() -> void:
	_close()

func _refresh_state() -> void:
	if GlobalSaveGame.has_trip_results_pending():
		_setup_finished()
	else:
		_setup_planning()

func _close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%ScrollPanel as ScrollPanel, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		closed.emit()
		queue_free()

func _setup_finished() -> void:
	var finished_uids := GlobalSaveGame.get_finished_trip_uids()
	_claiming_trip_uid = finished_uids.pop_front() as int
	var past_run := GlobalSaveGame.get_past_run(_claiming_trip_uid)

	(%FinishedLabel as MarkedUpLabel).set_markedup_text(
		tr('The Explorer is back from %s with a report!') % past_run.get_native_shard_display_name(),
		MarkedUpLabel.LinkMode.LINK)
	(%InsightsLabel as MarkedUpLabel).set_markedup_text(
		tr('Gained %d <term_lower:insight>s.') % INSIGHTS_REWARD,
		MarkedUpLabel.LinkMode.LINK)

	(%VBox_Relic as Control).visible = false
	(%VBox_Skill as Control).visible = false

	if past_run.shard_type and past_run.shard_type.trip_reward:
		_current_reward = past_run.shard_type.trip_reward
		var overridden := false
		for override in past_run.shard_type.trip_reward_overrides:
			if override.requirement.is_satisfied(null, null):
				_current_reward = override.trip_reward
				if overridden:
					push_warning('Multiple trip reward overrides apply. Taking the last one. ID: ', past_run.shard_type.shard_type_id)
				overridden = true
	else:
		var possible_trip_results: Array[TripReward]
		for argument in random_trip_rewards.rewards:
			if not GlobalSaveGame.is_argument_unlocked(argument):
				possible_trip_results.append(random_trip_rewards.rewards[argument])
		var rng := GlobalSaveGame.get_hub_random().snapshot()

		if possible_trip_results:
			_current_reward = rng.pick(possible_trip_results)
		else:
			_current_reward = TripReward.new()
			_current_reward.text = tr('The shard seems to be getting along. Nothing of note to report.')

	if not Utils.ensure(_current_reward != null):
		_current_reward = TripReward.new()
		_current_reward.text = tr('The shard seems to be getting along. Nothing of note to report.')

	var report_text := tr(_current_reward.text)
	if past_run.shard_type:
		report_text = past_run.shard_type.format_history_text(0, past_run, report_text)
	if _current_reward.unlocked_relic:
		(%VBox_Relic as Control).visible = true
		(%RelicChoice as RelicChoice).relic = _current_reward.unlocked_relic
	if _current_reward.revealed_skill:
		(%VBox_Skill as Control).visible = true
		(%Icon_Skill as TextureRect).texture = _current_reward.revealed_skill.icon
		(%Label_SkillName as Label).text = _current_reward.revealed_skill.get_effective_skill_name()
		(%Label_SkillDescription as MarkedUpLabel).set_markedup_text(
			_current_reward.revealed_skill.get_effective_description(),
			MarkedUpLabel.LinkMode.LINK)
	if _current_reward.gained_argument and Utils.is_debate_in_progress():
		report_text += '\n\n' + tr('[b]This report can serve as a speech topic.[/b]')
	(%ReportLabel as MarkedUpLabel).set_markedup_text(report_text, MarkedUpLabel.LinkMode.LINK)

	(%VBox_Planning as Control).visible = false
	(%FinishedPanel as Control).visible = true
	(%ActionLabel as MarkedUpLabel).set_markedup_text('', MarkedUpLabel.LinkMode.LINK)
	(%SendButton as Button).text = tr('Claim Rewards')
	(%SendButton as Button).disabled = false

func _setup_planning() -> void:
	var queued_trip_uids := GlobalSaveGame.get_queued_trip_uids()
	var mq_state := GlobalSaveGame.get_main_quest_progress()
	var past_runs: Array[PastRun]
	for uid in GlobalSaveGame.get_past_run_ids():
		if GlobalSaveGame.is_shard_explored(uid):
			continue
		if uid in queued_trip_uids:
			continue
		var past_run := GlobalSaveGame.get_past_run(uid)

		# Special main quest override.
		if GlobalSaveGame.get_main_quest_progress() == SaveGame.MainQuestProgress.P400_STARTED_DEPRESSION:
			if not past_run.shard_type or past_run.shard_type != load('res://shard_types/mq_teo_abode/shard_type_mq_teo_abode.tres'):
				continue

		if past_run.shard_type:
			if past_run.shard_type.trip_reward and mq_state < past_run.shard_type.trip_reward.min_main_quest_progress:
				continue
			var progress := GlobalSaveGame.get_shard_type_progress(past_run.shard_type)
			if progress.are_all_histories_completed():
				past_runs.append(past_run)
		else:
			if GlobalSaveGame.get_current_date() - past_run.date_settled >= MIN_SEASONS_SINCE_SETTLED:
				past_runs.append(past_run)

	Utils.clear_node(%ShardsList)
	if past_runs:
		past_runs.sort_custom(func(a: PastRun, b: PastRun) -> bool:
			if (a.shard_type != null) != (b.shard_type != null):
				return a.shard_type != null
			else:
				return a.date_settled < b.date_settled
		)

		for past_run in past_runs:
			var option := TRIP_OPTION_BUTTON_SCENE.instantiate_loaded_scene() as TripOption
			option.past_run = past_run
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			option.pressed.connect(_on_run_selected.bind(option))
			option.button_group = _runs_button_group
			(%ShardsList as VBoxContainer).add_child(option)

		(%ActionLabel as MarkedUpLabel).set_markedup_text(
			tr('Select a shard for the Explorer to visit and bring back news and lessons.'),
			MarkedUpLabel.LinkMode.LINK)
		(%EmptyLabel as MarkedUpLabel).visible = false
	else:
		var min_seasons_explanation := tr_n(
			'For other shards, at least %d <term_lower:season> must have passed since it was settled.',
			'For other shards, at least %d <term_lower:season>s must have passed since it was settled.',
			MIN_SEASONS_SINCE_SETTLED) % MIN_SEASONS_SINCE_SETTLED
		(%EmptyLabel as MarkedUpLabel).set_markedup_text(tr('''No shards are available for exploration trips.

For shards with a specific <term_lower:shard_type>, its history must have been fully discovered.

''') + min_seasons_explanation, MarkedUpLabel.LinkMode.LINK)
		(%EmptyLabel as MarkedUpLabel).visible = true
		(%ActionLabel as MarkedUpLabel).set_markedup_text('', MarkedUpLabel.LinkMode.LINK)

	var in_progress_text := tr('The following shards are scheduled to be visited:') + '[ul]'
	for uid in queued_trip_uids:
		var past_run := GlobalSaveGame.get_past_run(uid)
		var label := tr(past_run.shard_name)
		if past_run.shard_type:
			label += ' (%s)' % tr(past_run.shard_type.name)
		in_progress_text += label + '\n'
	in_progress_text += '[/ul]\n\n'
	in_progress_text += tr('[i]It will take one <term_lower:season> to receive the Explorer\'s report for each shard.[/i]')
	(%InProgressLabel as MarkedUpLabel).set_markedup_text(in_progress_text, MarkedUpLabel.LinkMode.LINK)
	if queued_trip_uids.size() >= MAX_QUEUED_TRIPS:
		(%ActionLabel as MarkedUpLabel).set_markedup_text(
			tr('Can schedule no more than %d shards at a time.') % MAX_QUEUED_TRIPS,
			MarkedUpLabel.LinkMode.LINK)

	(%SendButton as Button).text = tr('Queue Trip')
	(%SendButton as Button).disabled = true
	(%VBox_Planning as Control).visible = true
	(%InProgressPanel as Control).visible = not queued_trip_uids.is_empty()
	(%FinishedPanel as Control).visible = false

	if past_runs:
		var option_to_select: TripOption = %ShardsList.get_child(mini(_last_selected_index, %ShardsList.get_child_count() -1))
		option_to_select.button_pressed = true
		_on_run_selected(option_to_select)

func _on_run_selected(option: TripOption) -> void:
	var past_run := option.past_run
	_selected_run = past_run
	_last_selected_index = option.get_index()
	if GlobalSaveGame.get_queued_trip_uids().size() < MAX_QUEUED_TRIPS:
		(%SendButton as Button).disabled = false
		(%ActionLabel as MarkedUpLabel).set_markedup_text(
			tr('This shard is ready for exploration. A trip will take one <term_lower:season>.'),
			MarkedUpLabel.LinkMode.LINK)
	else:
		(%SendButton as Button).disabled = true
		(%ActionLabel as MarkedUpLabel).set_markedup_text(
			tr('Can schedule no more than %d shards at a time.') % MAX_QUEUED_TRIPS,
			MarkedUpLabel.LinkMode.LINK)

func _on_send_button_pressed() -> void:
	if _claiming_trip_uid:
		if _current_reward:
			if _current_reward.unlocked_relic:
				GlobalSaveGame.mark_relic_seen(_current_reward.unlocked_relic)
			if _current_reward.revealed_skill:
				GlobalSaveGame.reveal_skill(_current_reward.revealed_skill)
			if _current_reward.gained_argument:
				GlobalSaveGame.unlock_argument(_current_reward.gained_argument)
		GlobalSaveGame.insights += INSIGHTS_REWARD
		GlobalSaveGame.mark_trip_result_claimed(_claiming_trip_uid)
		_claiming_trip_uid = 0
		_current_reward = null
	else:
		assert(_selected_run)
		GlobalSaveGame.queue_trip(_selected_run)
		_selected_run = null
	GlobalSaveGame.save_game()
	_refresh_state()
