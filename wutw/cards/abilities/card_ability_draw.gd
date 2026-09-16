@tool
class_name CardAbility_Draw
extends CardAbility

@export var count: int = 1
@export var aspect: AspectType = null

func get_ability_name(markedup: bool = false, short: bool = false) -> String:
	var text := ('<term:draw>' if markedup else tr('Draw', 'ABILITY')) + ' '
	if count <= 0:
		Utils.ensure(aspect == null)
		return text + tr('Full')
	else:
		if aspect:
			if count > 1:
				text += str(count)

			if short:
				text += '[img width=1.25em height=1.25em]%s[/img]' % aspect.get_used_icon().resource_path
			else:
				text += aspect.get_term_tag()
		else:
			text += str(count)
	return text

func get_ability_tooltip(_card: Card) -> String:
	if count == -1:
		return tr('<term:draw> <term_lower:glyph>s until your hand is full.')
	else:
		var text: String
		if count == 1:
			text = tr('<term:draw> a <term_lower:glyph>')
		else:
			text = tr('<term:draw> %d <term_lower:glyph>s') % count
		if aspect:
			text += tr(' with %s <term:aspect>, if available in the <term_lower:draw_pile>') % aspect.get_term_tag()
		text += tr('.')
		return text

func get_term() -> Term:
	return load('res://cards/abilities/terms/term_card_ability_draw.tres')

func cast(_card: Card) -> void:
	var stage := Utils.get_active_run().get_current_stage()
	var deck := stage.get_card_deck()
	var draw_count := deck.get_hand_size() - deck.get_hand_cards().size() if count < 0 else count
	var any_cards_drawn := [false]  # Array, so we can capture it.
	var error_shown := [false]  # Array, so we can capture it.
	for _i in range(draw_count):
		stage.queue_action(func() -> void:
			if deck.get_draw_pile_cards() or deck.get_discard_pile_cards():
				if aspect:
					for card_type in deck.get_draw_pile_cards():
						if aspect in card_type.aspects:
							await deck.draw_specific_card(card_type, CardDeck.CardDrawReason.ABILITY)
							any_cards_drawn[0] = true
							return
					await deck.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
				else:
					await deck.draw(CardDeck.CardDrawReason.ABILITY, true)
					any_cards_drawn[0] = true
					return
			# Did not successfully return above.
			if not error_shown[0]:
				error_shown[0] = true
				if any_cards_drawn[0]:
					GlobalUI.show_error(tr('No more %s<term_lower:glyph>s to <term_lower:draw>.') %
										(aspect.get_term_tag() + ' ') if aspect else '')
				else:
					GlobalUI.show_error(tr('There are no %s<term_lower:glyph>s to <term_lower:draw>.') %
										(aspect.get_term_tag() + ' ') if aspect else '')
				await deck.get_tree().create_timer(Utils.anim_duration(0.3)).timeout
		)

func estimate_power(_card_type: CardType) -> int:
	match count:
		1: return 11
		2: return 26
		3: return 40
		4: return 60
		_: return 100
