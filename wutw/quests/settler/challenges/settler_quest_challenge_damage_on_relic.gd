class_name SettlerQuestChallenge_DamageOnRelic
extends SettlerQuestChallenge

@export var damage: int = 5

var _triggered_this_turn := false

func start_listening(run: Run) -> void:
	run.signals.redraw_started.connect(_on_redraw_started.unbind(1))
	run.signals.relic_triggered.connect(_on_relic_triggered.unbind(1))

func stop_listening(run: Run) -> void:
	run.signals.redraw_started.disconnect(_on_redraw_started.unbind(1))
	run.signals.relic_triggered.disconnect(_on_relic_triggered.unbind(1))

func _on_redraw_started() -> void:
	_triggered_this_turn = false

func _on_relic_triggered() -> void:
	if _triggered_this_turn:
		return
	_triggered_this_turn = true
	var run := Utils.get_active_run()
	run.run_or_queue_action(func() -> void:
		run.signals.settler_quest_challenge_triggered.emit(self)
		run.modify_inspiration(-damage, Run.InspirationChangeReason.SETTLER_QUEST)
		await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
	)

func describe() -> String:
	return tr('Lose %d <term_lower:inspiration> the first time a relic is triggered each <term_lower:turn>.') % damage
