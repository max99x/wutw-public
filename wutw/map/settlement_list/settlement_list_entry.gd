class_name SettlementListEntry
extends PanelContainer

signal clicked

var settlement: Settlement:
	set(value):
		if settlement:
			settlement.state.bonuses_changed.disconnect(_update)
		settlement = value
		if value:
			settlement.state.bonuses_changed.connect(_update)
		if is_node_ready():
			_update()

func _ready() -> void:
	_update()
	GlobalTooltipSystem.attach(self, settlement._make_tooltip_text,
			[Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.RIGHT],
			[Tooltip.Alignment.CENTERED])
	GlobalGameSettings.changed.connect(_update)  # For name display style.
	# Overkill, but prob. fine.
	Utils.get_active_run().signals.haunting_spawned.connect(_update.unbind(1))
	Utils.get_active_run().signals.haunting_pacified.connect(_update.unbind(1))
	Utils.get_active_run().signals.bonus_gained.connect(_update_shop_state.unbind(3))
	Utils.get_active_run().signals.bonus_lost.connect(_update_shop_state.unbind(3))
	Utils.get_active_run().signals.shop_transacted.connect(_update_shop_state)

func _process(_delta: float) -> void:
	# HACK: Several hard-to-repro cases have been reported causing the lack display
	#       to get out of date, so we brute-force update it here.
	_update_lacks()

func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func _update() -> void:
	(%NameLabel as Label).text = settlement.state.settlement_name.get_display_name()
	(%RoofColor as ColorRect).color = settlement.state.roof_color
	if settlement.is_settlement_connected():
		(%ConnectIcon as TextureRect).texture = load('res://map/settlement_list/connected.png')
	else:
		(%ConnectIcon as TextureRect).texture = load('res://map/settlement_list/unconnected.png')
	(%ShopIcon as Control).visible = not settlement.get_shops().is_empty()
	(%HauntedIcon as Control).visible = settlement.get_haunting() != null

	(%PositiveBonus as Bonus).bonus_type = settlement.get_yield_type()
	(%PositiveBonus as Bonus).visible = Skill.get_skill_var(Skill.Var.CAPITAL_CONNECTION) > 0

	# HACK: Currently brute-forced in _process()
	#_update_lacks()

	if not settlement.connected.is_connected(_update):
		settlement.connected.connect(_update)
	if not settlement.lacks_changed.is_connected(_update):
		settlement.lacks_changed.connect(_update)

	_update_shop_state()

func _update_lacks() -> void:
	if not Utils.ensure(settlement != null):
		return
	var negative_bonus_1 := %NegativeBonus as Bonus
	var negative_bonus_2 := %NegativeBonus2 as Bonus
	var lacks := settlement.get_unsatisfied_lacks()
	Utils.ensure(lacks.size() <= 2)
	var run := Utils.get_active_run()
	if run and lacks.size() > 0 and run.scaling.stages_per_season < 100:  # Not tutorial
		negative_bonus_1.bonus_type = lacks[0]
		negative_bonus_1.visible = true
		if lacks.size() > 1:
			negative_bonus_2.bonus_type = lacks[1]
			negative_bonus_2.visible = true
		else:
			negative_bonus_2.visible = false
	else:
		negative_bonus_1.visible = false
		negative_bonus_2.visible = false

func _update_shop_state() -> void:
	if not settlement.get_shops():
		return
	var run := Utils.get_active_run()
	var available := false
	for shop_type in settlement.get_shops():
		if not run.has_shop_been_used_this_round(shop_type):
			var available_amount := run.get_bonus_amounts().get_amount(shop_type.cost_type)
			if available_amount >= shop_type.get_scaled_cost(run):
				available = true
				break
	(%ShopIcon as Control).modulate = (
		Color(1.306, 1.306, 1.306) if available else Color(0.4, 0.4, 0.4))

func _on_mouse_entered() -> void:
	self_modulate = Color(1, 1, 1, 0.2)

func _on_mouse_exited() -> void:
	self_modulate = Color(1, 1, 1, 0)
