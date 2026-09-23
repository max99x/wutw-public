class_name SettlerQuestChallenge_DamageOnRelic
extends SettlerQuestChallenge

@export var damage: int = 1

func start_listening(run: Run) -> void:
	run.signals.relic_triggered.connect(_on_relic_triggered.unbind(1))

func stop_listening(run: Run) -> void:
	run.signals.relic_triggered.disconnect(_on_relic_triggered.unbind(1))

func _on_relic_triggered() -> void:
	var run := Utils.get_active_run()
	run.run_or_queue_action(func() -> void:
		run.signals.settler_quest_challenge_triggered.emit(self)
		run.modify_inspiration(-damage, Run.InspirationChangeReason.SETTLER_QUEST)
	)

func describe() -> String:
	return tr('Lose %d <term_lower:inspiration> when a relic is triggered.') % damage
