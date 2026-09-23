class_name RunSignals
extends RefCounted

@warning_ignore_start('unused_signal')
signal redraw_started(is_first: bool)
signal redraw_finished(is_first: bool)
signal card_drawn(card: Card, reason: CardDeck.CardDrawReason, from_discards: bool)
signal card_added_to_hand(card: Card, reason: CardDeck.CardDrawReason, from_discards: bool)
signal card_slotted(card: Card, aspect_slot: AspectSlot)
signal discard_started(card: Card, reason: CardDeck.DiscardReason)
signal discard_finished(card: Card, reason: CardDeck.DiscardReason)
signal deck_reshuffled
signal card_cast_started(card: Card)
signal card_cast_finished(card: Card)
signal ability_started(card: Card, ability: CardAbility)
signal ability_finished(card: Card, ability: CardAbility)
signal pre_bonus_gained(gain: BonusGain)  # Allows modification before application.
signal bonus_gained(bonus_type: BonusType, amount: int, reason: BonusGain.Reason)
signal bonus_lost(bonus_type: BonusType, amount: int, reason: BonusGain.Reason)
signal pre_inspiration_gained(amount: int, reason: Run.InspirationChangeReason)
signal inspiration_gained(amount: int, reason: Run.InspirationChangeReason)
signal inspiration_lost(amount: int, reason: Run.InspirationChangeReason)
signal inspiration_exhausted(reason: Run.InspirationChangeReason)
signal card_choice_offered
signal card_reward_skipped
signal card_choice_finished
signal card_added(card_type: CardType)  # to deck
signal card_removed(card_type: CardType)  # from deck
signal relic_added(relic: Relic)
signal relic_removed(relic: Relic)
signal relic_triggered(relic: Relic)
signal stage_started
signal stage_finished
signal foray_started
signal before_foray_finished(settlement_state: SettlementState)
signal foray_finished(settlement_state: SettlementState)
signal survey_started
signal survey_episode_finished(episode: SurveyEpisode)
signal survey_finished
signal harmonization_started
signal harmonization_finished
signal aspect_slot_filled(aspect_slot: AspectSlot)
signal spot_recipe_activated(spot_recipe: SpotRecipe)
signal harmonization_recipe_activated(harmonization_recipe: HarmonizationRecipe)
signal settlement_connected(settlement: Settlement)
signal capital_bonuses_changed
signal shop_transacted
signal insights_gained(amount: int)
signal event_started(event: Event)
signal event_finished(event: Event)
signal haunting_spawned(haunting: HauntingBase)
signal haunting_blocked(haunting: HauntingBase)
signal haunting_pacified(haunting: HauntingBase)
signal companion_ability_started(companion: Companion)
signal companion_ability_finished(companion: Companion)
signal settler_quest_challenge_triggered(challenge: SettlerQuestChallenge)
@warning_ignore_restore('unused_signal')
