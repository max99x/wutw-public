class_name DebugConsoleCommands
extends Node

static var _runvar_serial_num := 1

func _ready() -> void:
	Console.add_command('card', _cmd_add_card, ['card_name_fragment'], 1, 'Add a card (glyph) containing the name fragment to hand (or deck if not in foray or prefixed with *).')
	Console.add_command('inspire', _cmd_add_inspiration, ['points'], 1, 'Add inspiration (can be negative).')
	Console.add_command('bonus', _cmd_add_bonus, ['type', 'points'], 2, 'Add bonus (yield) points of a given type for the current stage (foray).')
	Console.add_command('relic', _cmd_add_relic, ['relic_name_fragment'], 1, 'Add a relic containing the name fragment in the filename or player-visible name.')
	Console.add_command('insights', _cmd_add_insights, ['count'], 1, 'Adds a given number of Insights points.')
	Console.add_command('stroke', _cmd_add_stroke, ['stroke_name_fragment', 'count'], 2, 'Adds a given number of a given Stroke to the player inventory.')
	Console.add_command('main_quest', _cmd_set_main_quest_progress, ['value'], 1, 'Sets the main quest state to the given value.')
	Console.add_command('runvar', _cmd_adjust_run_var, ['name', 'delta'], 2, 'Adds a run var modifier.')
	Console.add_command('event', _cmd_run_event, ['name'], 1, 'Plan an event.')
	Console.add_command('increment_date', _cmd_increment_date, ['num'], 0, 'Increment the date, equivalent to finishing a season.')

	Console.add_command('eventvar', _cmd_set_run_event_var, ['event_id', 'var_id', 'value'], 3, 'Sets the given run-scope EventsState variable. Guesses type.')
	Console.add_command('metaeventvar', _cmd_set_savegame_event_var, ['event_id', 'var_id', 'value'], 3, 'Sets the given savegame-scope EventsState variable. Guesses type.')
	Console.add_command('geteventvar', _cmd_get_event_var, ['event_id', 'var_id'], 2, 'Gets the given EventsState variable, first trying run scope, then savegame scope.')

	Console.add_command('reveal', _cmd_reveal_map, [], 0, 'Reveals the entire map.')

	Console.add_command('respawn', _cmd_respawn, [], 0, 'Respawns hub NPCs. Only usable in hub.')

	Console.add_command('save', _cmd_save_game, [], 0, 'Saves the game immediately.')
	Console.add_command('reload', _reload, [], 0, 'Reload the game from the latest save immediately.')

	Console.add_command('speed', _cmd_speed, ['time_scale'], 1, 'Sets the game speed multiplier.')
	Console.add_command('eval', _cmd_eval, ['code_string'], 1, 'Evaluates a string as GDScript. Has `run` in scope.')
	Console.add_command('debug_footprints', _cmd_footprints, [], 0, 'Toggle footprint debug display on the map.')
	Console.add_command('debug_collision', _cmd_collision, [], 0, 'Toggle collision debug display on the map.')
	Console.add_command('debug_biomes', _cmd_debug_biomes, [], 0, 'Toggle biome grid debug display on the map.')

	Console.add_command('static_stats', _cmd_static_stats, [], 0, 'Print stats about spots (sites).')
	Console.add_command('write_terms', _cmd_write_terms.bind(false), [], 0, 'Writes all the Terms except Cards and Relics and their definitions (images stripped) to terms.txt in the user data folder.')
	Console.add_command('write_terms_csv', _cmd_write_terms.bind(true), [], 0, 'Writes all the Terms except Cards and Relics and their definitions (images stripped) to terms.csv in the user data folder.')
	Console.add_command('write_cards', _cmd_write_cards, [], 0, 'Writes all the Card Types and their definitions (images stripped) to cards.txt in the user data folder.')
	Console.add_command('write_card_power', _cmd_write_card_power, [], 0, 'Writes all the Card Types and their definitions (images stripped) to card_power.csv in the user data folder.')
	Console.add_command('write_relics', _cmd_write_relics, [], 0, 'Writes all the Relics and their definitions (images stripped) to cards.txt in the user data folder.')
	Console.add_command('write_spots', _cmd_write_spots, [], 0, 'Writes all the Spots with their details to spots.txt in the user data folder.')
	Console.add_command('write_events', _cmd_write_events, [], 0, 'Writes all the Events with their details to events.txt in the user data folder.')
	Console.add_command('write_surveys', _cmd_write_surveys, [], 0, 'Writes all the Survey episodes with their details to surveys.txt in the user data folder.')
	Console.add_command('write_shard_types', _cmd_write_shard_types, [], 0, 'Writes all the Shard Types with their details to shard_types.txt in the user data folder.')
	Console.add_command('write_dialogues', _cmd_write_dialogues, [], 0, 'Writes all the Dialogues with their details to shard_types.txt in the user data folder.')
	Console.add_command('write_hauntings', _cmd_write_hauntings, [], 0, 'Writes all the Hauntings with their details to hauntings.txt in the user data folder.')
	Console.add_command('write_art_text', _cmd_write_art_text, [], 0, 'Writes all the text for art viewer contents (art pieces, artists, etc.) art_text.txt in the user data folder.')
	Console.add_command('write_skills', _cmd_write_skills, [], 0, 'Writes all the skills to skills.txt in the user data folder.')

	Console.add_command('steam_clear_achievement', _cmd_clear_achievement, ['id'], 1, 'Clear the Steam achievement matching the [partial] ID.')
	Console.add_command('steam_clear_all_achievements', _cmd_clear_all_achievements, [], 0, 'Clear all Steam achievements.')

	Console.add_command('test_card_rarity', _cmd_test_card_rarity, ['bonus'], 1, 'Test card rarity tier rolls.')

func _cmd_add_card(card_name_fragment: String) -> void:
	var also_to_run_deck := false
	if card_name_fragment.begins_with('*'):
		card_name_fragment = card_name_fragment.substr(1)
		also_to_run_deck = true

	var options: Array[CardType] = []
	for card_type in CardType.get_all_card_types():
		if card_type.card_name.to_lower() == card_name_fragment.to_lower():
			# Exact match.
			options = [card_type]
			break
		if card_type.card_name.containsn(card_name_fragment) or card_type.symbol.containsn(card_name_fragment):
			options.append(card_type)

	if options.size() == 0:
		Console.print_error('No cards matching "%s" found.' % card_name_fragment)
	elif options.size() > 1:
		var names: Array[String] = []
		for option in options:
			names.append('- ' + option.card_name)
		Console.print_error('Multiple cards matching "%s" found:\n%s\nPlease disambiguate.' % [card_name_fragment, '\n'.join(names)])
	else:
		var run := _get_run()
		var stage := run.get_current_stage()
		if stage:
			var deck := stage.get_card_deck()
			deck.add_card_to_hand(options[0], CardDeck.CardDrawReason.RELIC)
			if also_to_run_deck:
				run.add_card_to_deck(options[0])
		else:
			run.add_card_to_deck(options[0])
		Console.print_info('Added card: %s.' % options[0].card_name)

	GlobalSaveGame.mark_used_cheats()

func _cmd_add_inspiration(points_str: String) -> void:
	var points := points_str.to_int()
	_get_run().modify_inspiration(points, Run.InspirationChangeReason.RELIC)
	Console.print_info('Added %d inspiration.' % points)
	GlobalSaveGame.mark_used_cheats()

func _cmd_add_bonus(bonus_name_fragment: String, points_str: String) -> void:
	var points := points_str.to_int()
	var run := _get_run()
	for bonus_type in BonusType.get_all_types():
		if bonus_name_fragment == '*' or bonus_type.name.containsn(bonus_name_fragment):
			run.gain_bonus(BonusGain.new(bonus_type, points, self))
			Console.print_info('Added %dx %s.' % [points, bonus_type.name])
	GlobalSaveGame.mark_used_cheats()

func _cmd_add_relic(relic_name_fragment: String) -> void:
	var options: Array[Relic] = []
	for relic in Relic.get_all_relics():
		if (relic.resource_path.containsn(relic_name_fragment)
				or relic.relic_id.containsn(relic_name_fragment)
				or relic.get_relic_name().containsn(relic_name_fragment)):
			options.append(relic)

	if options.size() == 0:
		Console.print_error('No relics matching "%s" found.' % relic_name_fragment)
	elif options.size() > 1:
		var names: Array[String] = []
		for option in options:
			names.append('- %s (%s)' % [option.get_relic_name(), option.resource_path.split('/')[-1]])
		Console.print_error('Multiple relics matching "%s" found:\n%s\nPlease disambiguate.' % [relic_name_fragment, '\n'.join(names)])
	else:
		var run := _get_run()
		run.add_relic(options[0])
		Console.print_info('Added relic: %s.' % options[0].get_relic_name())
	GlobalSaveGame.mark_used_cheats()

func _cmd_add_stroke(stroke_name_fragment: String, count_str: String) -> void:
	var count := count_str.to_int()
	for stroke in Stroke.get_all_strokes():
		if stroke_name_fragment == '*' or stroke.name.containsn(stroke_name_fragment) or stroke.resource_name.containsn(stroke_name_fragment):
			GlobalSaveGame.add_stroke(stroke, count)
			Console.print_info('Added %dx %s (%s) strokes.' % [count, stroke.name, stroke.character])
	GlobalSaveGame.mark_used_cheats()

func _cmd_add_insights(count_str: String) -> void:
	var count := count_str.to_int()
	var run := _get_run()
	if run:
		run.grant_insights(count)
	else:
		GlobalSaveGame.insights += count
	Console.print_info('Added %d insights.' % count)
	GlobalSaveGame.mark_used_cheats()

func _cmd_set_main_quest_progress(value_str: String) -> void:
	var value := value_str.to_int()
	GlobalSaveGame.set_main_quest_progress(value as SaveGame.MainQuestProgress)
	Console.print_info('Set main quest state to %d.' % value)
	GlobalSaveGame.mark_used_cheats()

func _cmd_adjust_run_var(var_name_fragment: String, delta_str: String) -> void:
	var options: Array[String] = []
	for var_name: String in RunVars.Var.keys():
		if var_name.to_lower() == var_name_fragment.to_lower():
			options = [var_name]
			break
		elif var_name_fragment.to_lower() in var_name.to_lower():
			options.append(var_name)

	if options.size() == 0:
		Console.print_error('No vars matching "%s" found.' % var_name_fragment)
	elif options.size() > 1:
		var names: Array[String] = []
		for option in options:
			names.append('- %s' % option)
		Console.print_error('Multiple vars matching "%s" found:\n%s\nPlease disambiguate.' % [var_name_fragment, '\n'.join(names)])
	else:
		var var_name := options[0]
		var delta := delta_str.to_int()
		var run := _get_run()
		run.get_vars().add_modifier(RunVars.Var[var_name] as RunVars.Var, delta, '_debug_console_' + str(_runvar_serial_num))
		_runvar_serial_num += 1
		GlobalSaveGame.mark_used_cheats()
		Console.print_info('Added %s to %s.' % [delta, var_name])

func _cmd_run_event(event_id_fragment: String) -> void:
	var options: Array[String] = []
	for event_id: String in Event.get_all_events():
		if event_id.to_lower() == event_id_fragment.to_lower():
			options = [event_id]
			break
		elif event_id_fragment.to_lower() in event_id.to_lower():
			options.append(event_id)

	if options.size() == 0:
		Console.print_error('No events matching "%s" found.' % event_id_fragment)
	elif options.size() > 1:
		var names: Array[String] = []
		for option in options:
			names.append('- %s' % option)
		Console.print_error('Multiple events matching "%s" found:\n%s\nPlease disambiguate.' % [event_id_fragment, '\n'.join(names)])
	else:
		var event := Event.get_event_by_id(options[0])
		var run := _get_run()
		if run:
			run.queue_event(event)
		elif Utils.get_active_hub():
			Utils.get_active_hub()._start_event(event)
		GlobalSaveGame.mark_used_cheats()
		Console.print_info('Started event %s.' % event.event_name)

func _cmd_increment_date(num: String) -> void:
	for _i in maxi(1, num.to_int()):
		GlobalSaveGame.increment_date()

func _cmd_set_run_event_var(event_id: String, var_id: String, value_str: String) -> void:
	_set_event_var(_get_run().get_events_state(), event_id, var_id, value_str)
	Console.print_info('Set run event var [b]%s:%s[/b] to [b]%s[/b].' % [event_id, var_id, value_str])
	GlobalSaveGame.mark_used_cheats()

func _cmd_set_savegame_event_var(event_id: String, var_id: String, value_str: String) -> void:
	_set_event_var(GlobalSaveGame.get_events_state(), event_id, var_id, value_str)
	Console.print_info('Set savegame event var [b]%s:%s[/b] to [b]%s[/b].' % [event_id, var_id, value_str])
	GlobalSaveGame.mark_used_cheats()

func _set_event_var(state: EventsState, event_id: String, var_id: String, value_str: String) -> void:
	if value_str in ['true', 'false']:
		state.set_bool(event_id, var_id, value_str == 'true')
	elif value_str.to_int() or value_str == '0':
		state.set_int(event_id, var_id, value_str.to_int())
	else:
		if ((value_str.begins_with('"') and value_str.ends_with('"'))
				or (value_str.begins_with("'") and value_str.ends_with("'"))):
			value_str = value_str.substr(1, value_str.length() - 2)
		state.set_string(event_id, var_id, value_str)
	GlobalSaveGame.mark_used_cheats()

func _cmd_get_event_var(event_id: String, var_id: String) -> void:
	var id := EventsState._format_id(event_id, var_id)

	var run_events_data := _get_run().get_events_state().to_flat()
	if id in run_events_data:
		Console.print_info('Event var [b]%s[/b] set in RUN to [b]%s[/b].' % [id, str(run_events_data[id])])
		return

	var savegame_events_data := GlobalSaveGame.get_events_state().to_flat()
	if id in savegame_events_data:
		Console.print_info('Event var [b]%s[/b] set in SAVEGAME to [b]%s[/b].' % [id, str(savegame_events_data[id])])
		return

func _cmd_save_game() -> void:
	GlobalSaveGame.save_game()
	Console.print_info('Game saved.')

func _reload() -> void:
	((Engine.get_main_loop() as SceneTree).current_scene as Main)._reload()

func _cmd_reveal_map() -> void:
	_get_run().get_map().clear_all_fow()
	Console.print_info('Map revealed.')
	GlobalSaveGame.mark_used_cheats()

func _cmd_respawn() -> void:
	var hub := Utils.get_active_hub()
	var hub_content := hub.get_node('%HubContent') as HubContents
	var character_manager := hub_content.get_node('%HubCharacterManager') as HubCharacterManager
	hub._claimed_settler_quests.clear()
	character_manager.spawn(GlobalSaveGame.get_hub_random())
	hub_content._update()
	for facility in Utils.get_all_hub_facilities_within(hub_content):
		if not facility.hovered.is_connected(hub_content._on_facility_hovered.bind(facility)):
			facility.hovered.connect(hub_content._on_facility_hovered.bind(facility))
			facility.unhovered.connect(hub_content._on_facility_unhovered.bind(facility))
			if facility is HubCharacter:
				facility.clicked.connect(hub_content.character_clicked.emit.bind(facility as HubCharacter))
	hub_content._hovered_facilities.clear()
	Console.print_info('NPCs respawned.')

func _cmd_speed(time_scale: String) -> void:
	Engine.time_scale = time_scale.to_float()
	Console.print_info('Set time scale to %f.' % Engine.time_scale)

func _cmd_eval(code_string: String) -> void:
	for command in code_string.split('\n'):
		if command.strip_edges().begins_with('#'):
			continue
		var expression := Expression.new()
		expression.parse(command, ['run'])
		expression.execute([_get_run()], self)
	GlobalSaveGame.mark_used_cheats()

func _cmd_footprints() -> void:
	var run := _get_run()
	if not run:
		Console.print_error('Can only be used during an active run.')
		return
	var map := run.get_map()
	map.get_sprite_renderer().draw_debug_footprints = not map.get_sprite_renderer().draw_debug_footprints
	Console.print_info('Debug footprints %s.' % ('enabled' if map.get_sprite_renderer().draw_debug_footprints else 'disabled'))

func _cmd_collision() -> void:
	var run := _get_run()
	if not run:
		Console.print_error('Can only be used during an active run.')
		return
	var map := run.get_map()
	map.get_sprite_renderer().draw_debug_collision = not map.get_sprite_renderer().draw_debug_collision
	Console.print_info('Debug collision %s.' % ('enabled' if map.get_sprite_renderer().draw_debug_collision else 'disabled'))

func _cmd_debug_biomes() -> void:
	var run := _get_run()
	if not run:
		Console.print_error('Can only be used during an active run.')
		return
	var map := run.get_map()
	map.preview_mode = not map.preview_mode
	Console.print_info('Debug collision %s.' % ('enabled' if map.preview_mode else 'disabled'))

func _cmd_write_terms(csv_format: bool) -> void:
	var terms: Array[Term]
	for term: Term in Term.get_all_terms().values():
		if term is CardType or term is Relic:
			continue
		terms.append(term)
	terms.sort_custom(func(a: Term, b: Term) -> bool:
		return a.get_term_priority() < b.get_term_priority()
	)
	_write_terms(terms, 'terms.' + ('csv' if csv_format else 'txt'), csv_format)

func _cmd_write_cards() -> void:
	var terms: Array[Term]
	for term: Term in Term.get_all_terms().values():
		if term is CardType:
			terms.append(term)
	terms.sort_custom(CardType.compare)
	_write_terms(terms, 'cards.txt')

func _cmd_write_card_power() -> void:
	var card_types := CardType.get_all_card_types().duplicate() as Array[CardType]
	card_types.sort_custom(CardType.compare)
	var output_file := FileAccess.open('user://card_power.csv', FileAccess.WRITE)
	output_file.store_line('Tier,Ideal AP,Symbol,Name,Abilities,Aspect Power,Ability Power,Adjustment')
	for card_type in card_types:
		var ability_names := ''
		if card_type.abilities:
			ability_names += card_type.abilities[0].get_ability_name()
			if card_type.abilities.size() > 1:
				ability_names += '; ' + card_type.abilities[1].get_ability_name()
		output_file.store_line('%d,%d,%s,%s,%s,%d,%d,%d' % [
			card_type.rarity,
			[10, 10, 15, 20, 30, 50, -10][card_type.rarity],
			card_type.symbol,
			card_type.card_name,
			ability_names,
			card_type.estimate_aspect_power(),
			card_type.estimate_ability_power(),
			card_type.debug_power_adjustment])
	output_file.close()
	Console.print_info('Wrote card power stats to card_power.csv.')

func _cmd_write_relics() -> void:
	var terms: Array[Term]
	for term: Term in Term.get_all_terms().values():
		if term is Relic:
			terms.append(term)
	terms.sort_custom(func(a: Relic, b: Relic) -> bool: return a.rarity < b.rarity)
	_write_terms(terms, 'relics.txt')

func _cmd_write_spots() -> void:
	var write_upgrade_details := func(upgrade: SpotUpgrade) -> String:
		var result := upgrade.required_aspects[0].name
		for aspect: AspectType in upgrade.required_aspects.slice(1):
			result += '+' + aspect.name
		result += ' -> ['
		var first := true
		for bonus_type in upgrade.granted_bonuses:
			if first:
				first = false
			else:
				result += ', '
			result += str(upgrade.granted_bonuses[bonus_type]) + ' ' + bonus_type.name
		result += '] '
		result += '"' + upgrade.description + '"'
		return result

	var output_file := FileAccess.open('user://spots.txt', FileAccess.WRITE)
	for spot_type in SpotType.get_all_spot_types():
		output_file.store_line('# Site: %s' % spot_type.name)
		output_file.store_line('')
		output_file.store_line(spot_type.description)
		output_file.store_line('')
		for upgrade in spot_type.upgrades:
			output_file.store_line('- %s (T1): %s' % [upgrade.name, write_upgrade_details.call(upgrade)])
			for upgrade2 in upgrade.child_upgrades:
				output_file.store_line('  - %s (T2): %s' % [upgrade2.name, write_upgrade_details.call(upgrade2)])
				for upgrade3 in upgrade2.child_upgrades:
					output_file.store_line('    - %s (T3): %s' % [upgrade3.name, write_upgrade_details.call(upgrade3)])
		output_file.store_line('')
	output_file.close()
	Console.print_info('Wrote spots to spots.txt.')

func _cmd_write_events() -> void:
	var output_file := FileAccess.open('user://events.txt', FileAccess.WRITE)
	for event: Event in Event.get_all_events().values():
		if event.steps:
			output_file.store_string('# %s' % event.event_name)
			output_file.store_string(' [%s]' % event.event_id)
			if event is Event_Stage:
				output_file.store_line(' (Site: %s)' % (event as Event_Stage).default_spot_upgrade.name)
			else:
				output_file.store_string('\n')
			for step in event.steps:
				if step.event_step_id:
					output_file.store_line('## Scene ID "%s"\n' % step.event_step_id)
				output_file.store_line('%s\n' % step.markedup_text)
				output_file.store_line('## Choices\n')
				for choice: EventChoice in step.choices + ([step.exit_choice] if step.exit_choice else []):
					output_file.store_string('- ')
					if choice.markedup_requirement_hint:
						output_file.store_string('[Req. %s] ' % choice.markedup_requirement_hint)
					elif choice.requirement:
						output_file.store_string('[Req. %s] ' % choice.requirement.describe(null, true))

					output_file.store_string('**%s**<br>\n' % choice.markedup_text)

					if choice.markedup_outcome_hint:
						output_file.store_string('  -> %s<br>\n' % choice.markedup_outcome_hint)
					elif choice.outcome:
						output_file.store_string('  -> %s<br>\n' % Term.parse(choice.outcome.describe(_get_run())).bbcode_text)

					if choice.markedup_result_text:
						output_file.store_string('  ' + choice.markedup_result_text.replace('\n', '<br>\n'))
					elif choice.result_event_step_id:
						output_file.store_string('  _Go to scene ID "%s"_' % choice.result_event_step_id)

					output_file.store_string('\n')
				output_file.store_string('\n')
			output_file.store_string('\n')
	output_file.close()
	Console.print_info('Wrote events to events.txt.')

func _cmd_write_surveys() -> void:
	var output_file := FileAccess.open('user://surveys.txt', FileAccess.WRITE)
	for episode: SurveyEpisode in SurveyEpisode.get_all_episodes().values():
		output_file.store_line('# %s [%s]' % [episode.title, episode.episode_id])
		var locations := episode.get_location_names()
		if locations:
			output_file.store_line('## %s' % ' / '.join(locations))
		else:
			output_file.store_line('## Anywhere')
		output_file.store_line('')
		output_file.store_line(episode.text + '  ')
		output_file.store_line('')
		output_file.store_line('## Choices')
		output_file.store_line('')
		for choice in episode.choices:
			var cost := ','.join(choice.aspects.map(func(a: AspectType) -> String:
				return a.name if a else 'Any')
			)
			if choice.requirement:
				cost = 'Req ' + choice.requirement.describe(null, false) + '; ' + cost
			output_file.store_line('- [%s] %s  ' % [cost, choice.label])
			if choice.outcome is EventOutcome_Random:
				var outcome_random := choice.outcome as EventOutcome_Random
				for suboutcome in outcome_random.suboutcomes:
					var cur_outcome_text := choice.outcome_text
					var chance := outcome_random.suboutcomes[suboutcome]
					output_file.store_line('(%d%% chance)  ' % roundi(chance * 100))
					if suboutcome is EventOutcome_OverrideNextStep:
						cur_outcome_text = (suboutcome as EventOutcome_OverrideNextStep).result_text
					elif suboutcome is EventOutcome_All:
						for subsuboutcome in (suboutcome as EventOutcome_All).suboutcomes:
							if subsuboutcome is EventOutcome_OverrideNextStep:
								cur_outcome_text = (subsuboutcome as EventOutcome_OverrideNextStep).result_text
					output_file.store_line(cur_outcome_text + '  ')
					if suboutcome and suboutcome is not EventOutcome_OverrideNextStep:
						output_file.store_line('-> %s  ' % suboutcome.describe(null))
					else:
						output_file.store_line('-> No gameplay effect.  ')
			else:
				output_file.store_line(choice.outcome_text + '  ')
				if choice.outcome:
					output_file.store_line('-> %s  ' % choice.outcome.describe(null))
				else:
					output_file.store_line('-> No gameplay effect.  ')
			output_file.store_line('')
		output_file.store_line('')
	output_file.close()
	Console.print_info('Wrote events to surveys.txt.')

func _cmd_write_shard_types() -> void:
	var output_file := FileAccess.open('user://shard_types.txt', FileAccess.WRITE)
	for shard_type: ShardType in ShardType.get_all_shard_types().values():
		output_file.store_string('# %s\n\n' % shard_type.name)
		output_file.store_string('## Requirements\n')
		for req in shard_type.describe_requirements():
			output_file.store_string('- %s\n' % Term.parse(req).bbcode_text)
		output_file.store_string('\n')
		output_file.store_string('## Revealed History\n')
		for snippet in shard_type.history:
			output_file.store_string('- %s\n' % snippet.text.replace('\n', '\n  '))
			for override in snippet.overrides:
				output_file.store_string('  - [override if %s] %s\n' % [
					override.requirement.to_expression(),
					override.text.replace('\n', '\n    ')])
		if shard_type.trip_reward and shard_type.trip_reward.text:
			output_file.store_string('\n## Explorer Trip Report\n')
			output_file.store_string(shard_type.trip_reward.text)
			output_file.store_string('\n')
		for override in shard_type.trip_reward_overrides:
			output_file.store_string('- [override if %s] %s\n' % [
				override.requirement.to_expression(),
				override.trip_reward.text.replace('\n', '\n  ')])
		output_file.store_string('\n')
	output_file.close()
	Console.print_info('Wrote shard types to shard_types.txt.')

func _cmd_write_dialogues() -> void:
	var output_file := FileAccess.open('user://dialogues.txt', FileAccess.WRITE)
	for dialogue: Dialogue in Dialogue.get_all_dialogues().values():
		if dialogue and dialogue.text:
			output_file.store_line('# %s' % dialogue.resource_path.split('/')[-1])
			output_file.store_line(dialogue.text.replace('\n', '  \n'))
			output_file.store_line('')
	output_file.close()
	Console.print_info('Wrote dialogues to dialogues.txt.')

func _cmd_write_hauntings() -> void:
	var output_file := FileAccess.open('user://hauntings.txt', FileAccess.WRITE)
	for haunting in HauntingType.get_all_haunting_types():
		output_file.store_line('# %s (%s, %s) [%s]' % [haunting.name, haunting.name_japanese, haunting.name_translation, haunting.resource_path.split('/')[-1]])
		output_file.store_line('## Short Description')
		output_file.store_line(haunting.description)
		output_file.store_line('## Long Description')
		output_file.store_line(haunting.description_long)
		output_file.store_line('## Realistic Version: %s' % haunting.name_realistic)
		output_file.store_line(haunting.description_realistic)
		output_file.store_line('## Gameplay Description')
		output_file.store_line(haunting.get_mechanics_description(HauntingTrigger.Mode.UNIVERSAL))
		output_file.store_line('')
	output_file.close()
	Console.print_info('Wrote hauntings to hauntings.txt.')

func _cmd_write_skills() -> void:
	var output_file := FileAccess.open('user://skills.txt', FileAccess.WRITE)

	for skill: Skill in Skill.get_all_skills().values():
		output_file.store_line('# %s [%s]' % [skill.skill_name, skill.skill_id])
		if skill.skill_name_realistic:
			output_file.store_line('* Realistic-era name override: ' + skill.skill_name_realistic)
		output_file.store_line(_parse_markup(skill.description))
		if skill.description_realistic:
			output_file.store_line('* Realistic-era description override: ' + _parse_markup(skill.description_realistic))
		output_file.store_line('')
	output_file.close()
	Console.print_info('Wrote skills to skills.txt.')

func _cmd_write_art_text() -> void:
	var output_file := FileAccess.open('user://art_text.txt', FileAccess.WRITE)

	output_file.store_line('# Artists\n')
	for artist in ArtViewer.get_all_artists():
		output_file.store_line('## %s\n' % artist.name)
		output_file.store_line(artist.blurb)
		output_file.store_line('')
	output_file.store_line('')

	output_file.store_line('# Schools\n')
	for school in ArtViewer.get_all_schools():
		output_file.store_line('## %s\n' % school.name)
		output_file.store_line(school.blurb)
		output_file.store_line('')
	output_file.store_line('')

	output_file.store_line('# Series\n')
	for series in ArtViewer.get_all_series():
		output_file.store_line('## %s - %s\n' % [series.artist.name if series.artist else 'Unknown Artist', series.name])
		output_file.store_line(series.blurb)
		output_file.store_line('')
	output_file.store_line('')

	output_file.store_line('# Styles\n')
	for style in ArtViewer.get_all_styles():
		output_file.store_line('## %s\n' % style.name)
		output_file.store_line(style.blurb)
		output_file.store_line('')
	output_file.store_line('')

	output_file.store_line('# Art Pieces\n')
	for piece in ArtViewer.get_all_pieces():
		output_file.store_line('## %s' % piece.get_attribution())
		if piece.blurb:
			output_file.store_line(piece.blurb)
		else:
			print('No art piece blurb for %s (%s)' % [piece.get_title(), piece.resource_path.split('/')[-1]])
		if piece.get('edits_description'):  # HACK
			output_file.store_line('Edited for ingame use: %s' % piece.get('edits_description'))
		output_file.store_line('')

	output_file.close()
	Console.print_info('Wrote art text to art_text.txt.')

func _cmd_static_stats() -> void:
	print('SPOT STATS')
	for spot_type in SpotType.get_all_spot_types():
		var max_spot_bonuses := _get_max_spot_bonuses(spot_type)
		var line := spot_type.name + ','
		for bonus_type in BonusType.get_all_types():
			line += '%s,' % max_spot_bonuses.get(bonus_type, 0)
		print(line)
	print('')

	print('ASPECT USAGE STATS')
	var aspect_uses: Dictionary[AspectType, int] = {}
	var count_aspect_uses := func(upgrade: SpotUpgrade) -> void:
		for aspect_type in upgrade.required_aspects:
			aspect_uses[aspect_type] = aspect_uses.get(aspect_type, 0) + 1
	_visit_all_recipes(count_aspect_uses)
	for aspect_type in aspect_uses:
		print(aspect_type.name, ' -> ', aspect_uses[aspect_type])
	print('')

	print('ASPECT TO BONUS STATS')
	var aspect_bonuses: Dictionary[AspectType, Dictionary] = {}  # Dictionary[BonusType, int]
	var count_aspect_bonuses := func(upgrade: SpotUpgrade) -> void:
		for aspect_type in upgrade.required_aspects:
			if not aspect_bonuses.has(aspect_type):
				aspect_bonuses[aspect_type] = {}
			for bonus_type in upgrade.granted_bonuses:
				aspect_bonuses[aspect_type][bonus_type] = aspect_bonuses[aspect_type].get(bonus_type, 0) + upgrade.granted_bonuses[bonus_type]
	_visit_all_recipes(count_aspect_bonuses)
	for aspect_type in aspect_bonuses:
		print(aspect_type.name, ':')
		var bonus_amounts := aspect_bonuses[aspect_type]
		for bonus_type: BonusType in bonus_amounts:
			print('- ', bonus_type.name, ': ', bonus_amounts[bonus_type])
	print('')

func _cmd_clear_achievement(id_fragment: String) -> void:
	var options: Array[Achievement] = []
	for achievement: Achievement in Achievements._debug_get_all():
		if achievement.achievement_id.containsn(id_fragment):
			options.append(achievement)

	if options.size() == 0:
		Console.print_error('No achievements matching "%s" found.' % id_fragment)
	elif options.size() > 1:
		var names: Array[String] = []
		for option in options:
			names.append('- %s' % option.achievement_id)
		Console.print_error('Multiple achievements matching "%s" found:\n%s\nPlease disambiguate.' % [id_fragment, '\n'.join(names)])
	else:
		Steam.clearAchievement(options[0].achievement_id)
		Steam.storeStats()
		Console.print_info('Cleared achievement: %s.' % options[0].achievement_id)

func _cmd_clear_all_achievements() -> void:
	Steam.resetAllStats(true)
	Console.print_info('Cleared all achievements.')

func _cmd_test_card_rarity(bonus_str: String) -> void:
	var bonus := bonus_str.to_int()
	var run := _get_run()
	run.get_vars().add_modifier(RunVars.Var.CARD_TIER_BONUS_PERCENT, bonus, '_cmd_test_card_rarity')

	var counts: Dictionary[int, int]
	for _i in 100:
		for c in Utils.choose_card_rewards(run, run.get_current_card_reward_weights(), 5, true):
			counts[c.rarity] = counts.get(c.rarity, 0) + 1
	for tier in 6:
		Console.print_info(str(tier) + ': ' + str(counts.get(tier, 0)))

	run.get_vars().remove_modifier('_cmd_test_card_rarity')

func _write_terms(terms : Array[Term], filename: String, csv_format: bool = false) -> void:
	var img_regex := RegEx.create_from_string('\\[(img|font_size).*?\\[/(img|font_size)\\]\\s*')
	var output_file := FileAccess.open('user://' + filename, FileAccess.WRITE)
	if csv_format:
		output_file.store_line('ID,Name,Long Name,Description')
	for term: Term in terms:
		var description_bbcode := Term.parse(term.get_markedup_description()).bbcode_text
		var term_name := img_regex.sub(term.get_term_name(true), '', true)
		description_bbcode = img_regex.sub(description_bbcode, '', true)
		if csv_format:
			output_file.store_csv_line([
				term.get_term_id(),
				img_regex.sub(term.get_term_name(false), '', true),
				term_name,
				description_bbcode,
			])
		else:
			output_file.store_line('* %s: %s\n' % [term_name, description_bbcode])
	output_file.close()
	Console.print_info('Wrote terms to %s.' % filename)

func _parse_markup(input: String) -> String:
	var img_regex := RegEx.create_from_string('\\[img.*?\\[/img\\]\\s*')
	var description_bbcode := Term.parse(input).bbcode_text
	return img_regex.sub(description_bbcode, '', true)

func _get_max_spot_bonuses(spot_type: SpotType) -> Dictionary[BonusType, int]:
	var possibilities := StageSatisfiability._get_spot_gain_possibilities(_get_run(), spot_type, true)
	var global_max: Dictionary[BonusType, int] = {}
	for outcome in possibilities.branch_outcomes:
		var outcome_dict := outcome.to_dict()
		for bonus_type in outcome_dict:
			global_max[bonus_type] = max(global_max.get(bonus_type, 0), outcome_dict[bonus_type])
	return global_max

func _visit_all_recipes(f: Callable) -> void:
	var visit_recipe_tree := func(upgrade: SpotUpgrade, recurse: Callable) -> void:
		f.call(upgrade)
		for child in upgrade.child_upgrades:
			recurse.call(child, recurse)
	for spot_type in SpotType.get_all_spot_types():
		for upgrade in spot_type.upgrades:
			visit_recipe_tree.call(upgrade, visit_recipe_tree)

func _get_all_resources(path: String = 'res://') -> Array[String]:
	var result: Array[String]
	var dir := DirAccess.open(path)
	if dir:
		for file in dir.get_files():
			if file.ends_with('.res') or file.ends_with('.tres'):
				result.append(path + '/' + file)
		for subdir in dir.get_directories():
			if not subdir.begins_with('.'):
				result.append_array(_get_all_resources(path + '/' + subdir))
	return result

func _get_run() -> Run:
	return Utils.get_active_run()
