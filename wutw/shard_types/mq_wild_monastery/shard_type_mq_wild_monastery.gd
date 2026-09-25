@tool
class_name ShardType_MainQuest_WildMonastery
extends ShardType

@export var monastery: SpotUpgrade
@export var harmony: BonusType
@export var min_harmony: int = 150

func score_requirement(run_data: RunData, index: int) -> float:
	match index:
		0:
			for settlement_state in run_data.settlement_states:
				for upgrades in settlement_state.activated_upgrades:
					if monastery in upgrades:
						return 1
			return 0
		1: return 1 if run_data.bonus_amounts.get_amount(harmony) >= min_harmony else 0
		2: return 1 if run_data.capital_location.x < 0 else 0
		_: return -1

func describe_requirements() -> Array[String]:
	return [
		tr('A <spot_upgrade:%s> <term_lower:spot_upgrade> in the <spot:%s>.') % [
			monastery.spot_upgrade_id, monastery.spot.spot_type_id],
		tr('At least %d %s.') % [min_harmony, harmony.get_term_tag()],
		tr('No shard capital.'),
	]
