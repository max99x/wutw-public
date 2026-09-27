@tool
class_name RunScaling
extends Resource

@export_group('Challenges')
@export var stage_goal_amounts: Curve
@export var capital_bonus_req_per_settlement: int = 10
@export var first_season_with_double_lacks: int = 2
@export var first_season_with_settlement_hauntings: int = 2
@export var stages_per_season: int = 6
@export var haunting_standalone_probability: float = 0.33
@export var haunting_base_probability: float = 0.15
@export var haunting_variance: float = 0.7
@export var haunting_bonus_per_slot: int = 200
@export var haunting_bonus_per_extra_chance: int = 200
@export var haunting_max_slots_spot: int = 8
@export var haunting_max_slots_harmonization: int = 4
@export var stages_before_survey: int = 3

@export_group('Rewards')
@export var card_tier_weights: Array[Curve]
@export var insights_per_stage: Curve
@export var insights_harmonization_multilier: int = 10
@export var max_insights_from_excess: int = 20
@export var early_exit_insights_bonus: float = 0.25
@export var season_relic_reward_pool: Array[Relic]

@export_group('Size')
@export var settlement_radius: Curve
@export var settlement_reveal_radius_base: int = 25
@export var capital_reveal_radius_base: int = 25
@export var base_stage_spot_count: int = 2
@export var survey_targeting_radius: int = 2
@export var survey_scan_radius: int = 20
@export var survey_reveal_radius_base: int = 16
@export var survey_reveal_radius_per_episode: int = 7
@export var survey_episode_count_base: int = 4

func get_num_stage_spots(stage_index: int) -> int:
	@warning_ignore('integer_division')
	var season_index := stage_index / stages_per_season
	var count := base_stage_spot_count
	count += season_index * Skill.get_skill_var(Skill.Var.SPOTS_PER_SEASON)
	return count

func get_stage_goal_amount(stage_index: int) -> int:
	return floori(_sample_int(stage_goal_amounts, stage_index) / 5.0) * 5

func get_num_stage_goals(stage_index: int, rng: RandomState) -> int:
	var weights: Array[float]
	if stage_index == 0:
		weights = [1.0]
	elif stage_index <= 2:
		weights = [0.2, 0.8]
	elif stage_index <= 5:
		weights = [0.4, 0.5, 0.1]
	elif stage_index <= 8:
		weights = [0.4, 0.4, 0.2]
	else:
		weights = [0.1, 0.4, 0.4, 0.1]
	return rng.pick_weighted_array(weights)[0] + 1

func get_capital_bonus_req(season_index: int) -> int:
	return (1 + season_index) * stages_per_season * capital_bonus_req_per_settlement

func get_card_tier_weights(stage_index: int) -> Array[float]:
	var result: Array[float]
	for curve in card_tier_weights:
		result.append(maxf(0, curve.sample(minf(stage_index, curve.max_domain))))
	return result

func get_rewarded_insights_for_stage(stage_index: int) -> int:
	return _sample_int(insights_per_stage, stage_index)

func get_rewarded_insights_for_harmonization(season_index: int) -> int:
	return get_rewarded_insights_for_stage((1 + season_index) * stages_per_season) * insights_harmonization_multilier

func get_early_exit_insights_bonus(base_insights: int) -> int:
	return roundi(base_insights * early_exit_insights_bonus)

func get_settlement_radius(stage_index: int) -> int:
	return _sample_int(settlement_radius, stage_index)

func _sample_int(curve: Curve, key: int) -> int:
	return roundi(curve.sample(minf(key, curve.max_domain)))
