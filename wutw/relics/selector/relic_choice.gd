class_name RelicChoice
extends Control

signal selected

@export var relic: Relic:
	set(value):
		relic = value
		if is_node_ready():
			_update()
@export var new_icon_visible: bool = false:
	set(value):
		new_icon_visible = value
		if is_node_ready():
			(%NewIcon as Control).visible = new_icon_visible
@export var min_text_width: float = 400:
	set(value):
		min_text_width = value
		if is_node_ready():
			_update()
@export var max_text_width: float = 400:
	set(value):
		max_text_width = value
		if is_node_ready():
			_update()
@export var interactive: bool = true:
	set(value):
		interactive = value
		if is_node_ready():
			_update()

func _ready() -> void:
	_update_font_size()
	GlobalGameSettings.changed.connect(_update_font_size)
	_update()
	if Utils.is_museum_unlocked():
		GlobalTooltipSystem.attach(%Button as Control, _make_tooltip_text,
				[Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.BELOW, Tooltip.RelativeDirection.RIGHT],
				[Tooltip.Alignment.CENTERED, Tooltip.Alignment.BEGIN, Tooltip.Alignment.END])
		GlobalTooltipSystem.attach(%FakeButton as Control, _make_tooltip_text,
				[Tooltip.RelativeDirection.LEFT, Tooltip.RelativeDirection.BELOW, Tooltip.RelativeDirection.RIGHT],
				[Tooltip.Alignment.CENTERED, Tooltip.Alignment.BEGIN, Tooltip.Alignment.END])

func _update_font_size() -> void:
	Utils._scale_font_size(%DescriptionLabel as RichTextLabel, false, 18)

func _on_button_pressed() -> void:
	selected.emit()

func _update() -> void:
	if not relic:
		return
	(%Icon as TextureRect).texture = relic.icon
	(%NameLabel as Label).text = relic.get_relic_name(true)
	(%DescriptionLabel as MarkedUpLabel).set_markedup_text(relic.get_markedup_description(), MarkedUpLabel.LinkMode.LINK)
	(%DescriptionLabel as MarkedUpLabel).custom_minimum_size.x = min_text_width
	(%DescriptionLabel as MarkedUpLabel).custom_maximum_size.x = max_text_width
	(%NewIcon as Control).visible = new_icon_visible
	if interactive:
		(%Button as Control).visible = true
		(%FakeButton as Control).visible = false
		(%DescriptionLabel as MarkedUpLabel).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		(%FakeButton as Control).visible = true
		(%Button as Control).visible = false
		(%DescriptionLabel as MarkedUpLabel).mouse_default_cursor_shape = Control.CURSOR_ARROW

func _make_tooltip_text() -> String:
	if GlobalSaveGame.has_seen_relic(relic):
		return tr('[i]%s to open museum entry.[/i]') % InputPrompts.get_input_markup(
				InputPrompts.InputType.RIGHT_CLICK)
	else:
		return tr('[b]This relic hasn\'t been seen before.[/b]')

func _on_button_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not mouse_event or not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if Utils.is_museum_unlocked():
			if GlobalSaveGame.has_seen_relic(relic):
				MuseumBrowser.open_museum_entry(relic, UI.Layer.STATE_MENU_SUBMENU)
			else:
				GlobalUI.show_error(tr('The <term_lower:relic> hasn\'t been seen before.'))

func _on_description_label_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not mouse_event:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
		if (%DescriptionLabel as MarkedUpLabel).mouse_filter != MouseFilter.MOUSE_FILTER_STOP:
			(%Button as UkiyoeButton).pressed.emit()
	else:
		_on_button_gui_input(event)

func _on_description_label_mouse_entered() -> void:
	(%Button as UkiyoeButton).manually_hovered = true

func _on_description_label_mouse_exited() -> void:
	(%Button as UkiyoeButton).manually_hovered = false
