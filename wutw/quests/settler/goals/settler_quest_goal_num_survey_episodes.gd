class_name SettlerQuestGoal_NumSurveyEpisodes
extends SettlerQuestGoal

@export var num_required: int = 5

func start_listening(run: Run) -> void:
	run.signals.survey_episode_finished.connect(_on_survey_finished)

func stop_listening(run: Run) -> void:
	run.signals.survey_episode_finished.disconnect(_on_survey_finished)

func _on_survey_finished(_episode: SurveyEpisode) -> void:
	if _count_finished() >= num_required:
		achieved.emit()

func describe() -> String:
	assert(num_required > 0)
	var result := ''
	if Utils.get_active_run():
		result += tr('[%d/%d] ') % [_count_finished(), num_required]
	result += tr('Finish at least %d <term_lower:survey> <term_lower:encounter>s.') % num_required
	return result

func _count_finished() -> int:
	var num_finished := 0
	var run := Utils.get_active_run()
	for episodes_list: Array in run.get_run_data().finished_episodes.values():
		num_finished += episodes_list.size()
	var stage := run.get_current_stage()
	if stage and stage.get_survey():
		num_finished += stage.get_survey().get_num_episodes_finished()
	return num_finished
