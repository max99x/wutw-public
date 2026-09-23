class_name EventOutcomeWidget_ChooseCard
extends EventOutcomeWidget

static var CARD_REWARD_SCENE := AsyncLoadedResource.new('res://stage/card_reward_choice.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)

var specific_card_types: Array[CardType]
var card_tier_bonus: int = 0
var aspect: AspectType = null
var card_tag: CardType.Tag = CardType.Tag.NO_TAG
var ui_layer: UI.Layer = UI.Layer.GAME_MENU_SUBMENU

func _ready() -> void:
	(%Label as Label).visible = false
	(%Card as Card).visible = false
	var tween := create_tween()
	modulate.a = 0
	tween.tween_property(self, 'modulate:a', 1.0, Utils.anim_duration(0.5))
	tween.play()
	await tween.finished

func _on_button_pressed() -> void:
	var run := Utils.get_active_run()
	var modifier_tag := Utils.generate_guid()
	run.get_vars().add_modifier(RunVars.Var.CARD_TIER_BONUS_PERCENT, card_tier_bonus, modifier_tag)

	var choices: Array[CardType]
	if specific_card_types:
		choices = specific_card_types
	else:
		var is_acceptable: Callable = func(card_type: CardType) -> bool:
			if aspect and aspect not in card_type.aspects:
				return false
			if card_tag != CardType.Tag.NO_TAG and card_tag not in card_type.tags:
				return false
			return true
		var count := run.get_var(RunVars.Var.CARD_REWARD_CHOICES)
		var tier_weights := run.get_current_card_reward_weights()
		choices = Utils.choose_card_rewards(run, tier_weights, count, true, is_acceptable)

	var card_reward := CARD_REWARD_SCENE.instantiate_loaded_scene() as CardRewardChoice
	card_reward.specific_card_types = choices
	card_reward.allow_removal = false
	card_reward.card_added.connect(func(card_type: CardType) -> void:
		(%Label as Label).visible = true
		(%Button as Button).visible = false
		(%Card as Card).card_type = card_type
		(%Card as Card).visible = true
		var stage := run.get_current_stage()
		if stage:
			stage.get_card_deck().add_card_to_hand(card_type, CardDeck.CardDrawReason.EVENT)
		card_reward.close()
		_clear_modifier(modifier_tag)
		finished.emit()
	)
	card_reward.canceled.connect(func() -> void:
		(%Label as Label).visible = true
		(%Button as Button).visible = false
		(%Label as Label).text = tr('Chose not to add a glyph.')
		card_reward.close()
		_clear_modifier(modifier_tag)
		finished.emit()
	)
	GlobalUI.add_layer_content(card_reward, ui_layer)

func _clear_modifier(modifier_tag: String) -> void:
	Utils.get_active_run().get_vars().remove_modifier(modifier_tag)
