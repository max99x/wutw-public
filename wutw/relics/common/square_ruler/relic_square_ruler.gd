@tool
class_name Relic_SquareRuler
extends Relic

func on_added(run: Run, apply_modifiers: bool) -> void:
	super.on_added(run, apply_modifiers)
	_run.signals.ability_started.connect(_on_ability_started)

func on_removed() -> void:
	_run.signals.ability_started.disconnect(_on_ability_started)
	super.on_removed()

func _on_ability_started(card: Card, ability: CardAbility) -> void:
	if CardType.Tag.THEME_NUMBER in card.card_type.tags and ability is CardAbility_Discard:
		triggered.emit()
		_run.get_vars().modify_base_value(RunVars.Var.ABILITY_CASTS_BLOCKED, 1)
		await _brief_wait()
