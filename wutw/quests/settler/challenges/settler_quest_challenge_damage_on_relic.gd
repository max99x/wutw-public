class_name SettlerQuestChallenge_DamageOnRelic
extends SettlerQuestChallenge

@export var damage: int = 1

var _reentry_blocked := false

func start_listening(run: Run) -> void:
	run.signals.relic_triggered.connect(_on_relic_triggered.unbind(1))

func stop_listening(run: Run) -> void:
	run.signals.relic_triggered.disconnect(_on_relic_triggered.unbind(1))

func _on_relic_triggered() -> void:
	if _reentry_blocked:
		return
	var run := Utils.get_active_run()
	run.run_or_queue_action(func() -> void:
		run.signals.settler_quest_challenge_triggered.emit(self)
		_reentry_blocked = true
		run.modify_inspiration(-damage, Run.InspirationChangeReason.SETTLER_QUEST)
		_reentry_blocked = false
		await run.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
	)

func describe() -> String:
	return tr('Lose %d <term_lower:inspiration> when a relic is triggered.') % damage
