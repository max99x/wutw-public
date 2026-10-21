class_name Achievements
extends Node

static var _group_loader := AsyncLoadedGroup.new('res://achievements/achievements_resourcegroup.tres', true, AsyncLoadedResource.LoadPhase.SPECULATIVE)

const STAT_STORE_INTERVAL_SECONDS := 30.0

var _cached_stats: Dictionary[String, int]
var _time_until_next_stat_store: float = STAT_STORE_INTERVAL_SECONDS
var _stats_store_pending := false
var _stats_store_requested := false

func _ready() -> void:
	if Utils.is_demo():
		return

	await GlobalStartup.wait_loaded_unlikely()

	for achievement: Achievement in _group_loader.get_loaded():
		if Steam.getAchievement(achievement.achievement_id).get('achieved'):
			continue
		achievement.achieved.connect(_on_achievement_achieved.bind(achievement))
		achievement.stat_changed.connect(_on_stat_changed.bind(achievement))
		if achievement.stat_id:
			_cached_stats[achievement.stat_id] = Steam.getStatInt(achievement.stat_id)
		if not achievement.handled_by_higher_tier:
			achievement.start_listening()
			achievement.check()

	# Recheck when loading a new save.
	GlobalSaveGame.save_loaded.connect(func() -> void:
		for achievement: Achievement in _group_loader.get_loaded():
			if Steam.getAchievement(achievement.achievement_id)['achieved']:
				continue
			if not achievement.handled_by_higher_tier:
				achievement.check()
	)

func _process(delta: float) -> void:
	if _stats_store_pending:
		if _stats_store_requested or _time_until_next_stat_store < 0:
			if Steam.storeStats():
				_stats_store_pending = false
			_time_until_next_stat_store = STAT_STORE_INTERVAL_SECONDS
			_stats_store_requested = false
		else:
			_time_until_next_stat_store -= delta

func get_stat(stat_id: String) -> int:
	return Steam.getStatInt(stat_id)

func _on_achievement_achieved(achievement: Achievement) -> void:
	if GlobalSaveGame.has_used_cheats():
		return
	_stop_listening_to(achievement)
	Steam.setAchievement(achievement.achievement_id)
	_stats_store_pending = true
	_stats_store_requested = true  # Try to force it now. If fails, will be picked up by _process() later.

func _on_stat_changed(new_value: int, achievement: Achievement) -> void:
	if GlobalSaveGame.has_used_cheats():
		return
	assert(achievement.stat_id)
	# All our stats are increment-only, so we ignore values that aren't above what we already have.
	if new_value > _cached_stats.get(achievement.stat_id, 0):
		if Steam.setStatInt(achievement.stat_id, new_value):
			_cached_stats[achievement.stat_id] = new_value
			_stats_store_pending = true
		# Picked up by the next time we call storeStats() in _process().
		if Steam.getAchievement(achievement.achievement_id)['achieved']:  # Did this cause an unlock?
			_stop_listening_to(achievement)

func _stop_listening_to(achievement: Achievement) -> void:
	achievement.stop_listening()
	# In case a few stat changes are emitted from a single callback.
	achievement.achieved.disconnect(_on_achievement_achieved.bind(achievement))
	achievement.stat_changed.disconnect(_on_stat_changed.bind(achievement))

static func _debug_get_all() -> Array[Achievement]:
	var result: Array[Achievement]
	result.assign(_group_loader.get_loaded())
	return result
