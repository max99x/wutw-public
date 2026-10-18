class_name UI
extends Node2D

# Values are each root node's z-index.
enum Layer {
	GAME = 0,
	GAME_MENU = 100,
	GAME_MENU_SUBMENU = 200,
	STATE_MENU = 300,
	STATE_MENU_SUBMENU = 400,
	HUD_TOP = 500,
	ANNOUNCEMENT = 600,
	ANNOUNCEMENT_SUBMENU = 700,
	DIALOGUE = 800,
	SAVE_INDICATOR = 900,
	TUTORIAL = 1000,
	CUTSCENE = 1100,
	PAUSE_MENU = 1200,
	PAUSE_MENU_SUBMENU = 1300,
	MODAL = 1400,
	NOTIFICATION = 1500,
	LOADING_SCREEN = 1600,
	DEV_CONSOLE = 1700,
	WATERMARK = 1800,
}

enum TransitionType { NONE, CLEAR, ZOOM, PORTAL, FADE_TO_BLACK, SCROLLIFY }

enum ZoomMode { DISABLED, SHIFT, ALWAYS }

const LAYER_SPACING := 99

const DYNAMIC_LAYERS: Array[Layer] = [  # Ordered from highest to lowest.
	Layer.MODAL,
	Layer.PAUSE_MENU_SUBMENU,
	Layer.PAUSE_MENU,
	Layer.CUTSCENE,
	Layer.TUTORIAL,
	Layer.DIALOGUE,
	Layer.ANNOUNCEMENT,
	Layer.STATE_MENU_SUBMENU,
	Layer.STATE_MENU,
	Layer.GAME_MENU_SUBMENU,
	Layer.GAME_MENU,
]

const PERSISTENT_LAYERS: Array[Layer] = [  # Not cleared in reset().
	Layer.ANNOUNCEMENT,
	Layer.SAVE_INDICATOR,
	Layer.NOTIFICATION,
	Layer.DEV_CONSOLE,
	Layer.WATERMARK,
]

signal dialogue_ended
signal pause_menu_opened
signal pause_menu_closed
signal ui_hide_toggled
@warning_ignore('unused_signal')  # Called from pause menu
signal return_to_main_menu_requested
signal global_drag_started
signal global_drag_ended

static var WATERMARK_SCENE := AsyncLoadedResource.new('res://utils/version_watermark.tscn', false, AsyncLoadedResource.LoadPhase.INITIAL)
static var SAVE_INDICATOR_SCENE := AsyncLoadedResource.new('res://utils/save_game_indicator.tscn')
static var QUEST_ANNOUNCEMENT_SCENE := AsyncLoadedResource.new('res://quests/announcement/quest_announcement.tscn')
static var CLEAR_LOAD_SCREEN_SCENE := AsyncLoadedResource.new('res://visuals/inkblot_transition/inkblot_transition.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var ZOOM_LOAD_SCREEN_SCENE := AsyncLoadedResource.new('res://visuals/zoom_transition/zoom_transition.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var PORTAL_LOAD_SCREEN_SCENE := AsyncLoadedResource.new('res://visuals/portal_transition/portal_transition.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)
static var FADE_TO_BLACK_LOAD_SCREEN_SCENE := AsyncLoadedResource.new('res://visuals/fade_transition/fade_transition.tscn')
static var SCROLLIFY_LOAD_SCREEN_SCENE := AsyncLoadedResource.new('res://visuals/map_scroll_transition/map_scroll_transition.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var DIALOGUE_DISPLAY_SCENE := AsyncLoadedResource.new('res://dialogue/dialogue_display.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var ERROR_NOTIFICATIONS_LIST_SCENE := AsyncLoadedResource.new('res://utils/error_notifications_list/error_notifications_list.tscn')
static var CONFIRM_SCENE := AsyncLoadedResource.new('res://theme/confirm_dialog/confirm_dialog.tscn', false, AsyncLoadedResource.LoadPhase.SPECULATIVE)
static var PAUSE_MENU_SCENE := AsyncLoadedResource.new('res://pause_menu/pause_menu.tscn', false, AsyncLoadedResource.LoadPhase.LIKELY)

var _layers: Dictionary[Layer, Node2D] = {}
var _zoomable_controls: Dictionary[Control, Vector2]  # Keys are pivot overrides.
var _currently_zoomed_control: Control
var _ui_hidden := false
var _is_dragging := false

func _enter_tree() -> void:
	for layer_name: String in Layer.keys():
		var layer := Layer[layer_name] as Layer
		var layer_node := Node2D.new()
		layer_node.name = 'UILayer_' + layer_name
		layer_node.z_index = layer as int
		add_child(layer_node)
		_layers[layer] = layer_node

func _ready() -> void:
	await GlobalStartup.wait_loaded_initial()
	add_layer_content(WATERMARK_SCENE.instantiate_loaded_scene(), Layer.WATERMARK)

	await GlobalStartup.wait_loaded_normal()
	add_layer_content(SAVE_INDICATOR_SCENE.instantiate_loaded_scene(), Layer.SAVE_INDICATOR)
	add_layer_content(ERROR_NOTIFICATIONS_LIST_SCENE.instantiate_loaded_scene(), Layer.NOTIFICATION)
	add_layer_content(QUEST_ANNOUNCEMENT_SCENE.instantiate_loaded_scene(), Layer.ANNOUNCEMENT)

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_DRAG_BEGIN:
		notify_drag_started()
	elif what == Node.NOTIFICATION_DRAG_END:
		notify_drag_ended()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and key_event.keycode == KEY_ESCAPE:
		handle_esc()
	elif key_event and key_event.pressed and key_event.is_action('toggle_ui_visiblity'):
		_ui_hidden = not _ui_hidden
		for layer in _layers:
			if layer > Layer.GAME:
				_layers[layer].visible = not _ui_hidden
		ui_hide_toggled.emit()
	elif key_event and key_event.pressed and key_event.is_action('debug_reload_i18n'):
		GameSettings.reload_i18n()

func notify_drag_started() -> void:
	Utils.ensure(not _is_dragging)
	global_drag_started.emit()
	_is_dragging = true

func notify_drag_ended() -> void:
	Utils.ensure(_is_dragging)
	global_drag_ended.emit()
	_is_dragging = false

func is_dragging() -> bool:
	return _is_dragging

static func register_zoomable(control: Control, x_pivot_override: float = -1, y_pivot_override: float = -1) -> void:
	if not Utils.is_in_editor():
		GlobalUI._register_zoomable(control, x_pivot_override, y_pivot_override)

func _register_zoomable(control: Control, x_pivot_override: float = -1, y_pivot_override: float = -1) -> void:
	if Utils.ensure(control not in _zoomable_controls):
		_zoomable_controls[control] = Vector2(x_pivot_override, y_pivot_override)
		control.tree_exiting.connect(unregister_zoomable.bind(control))

func unregister_zoomable(control: Control) -> void:
	if not control:  # Already left the tree.
		return
	if Utils.ensure(control in _zoomable_controls):
		_zoomable_controls.erase(control)

func is_ui_hidden() -> bool:
	return _ui_hidden

func _process(_delta: float) -> void:
	if (GameSettings.Interface.zoom_on_hover.value() == ZoomMode.DISABLED or
		(GameSettings.Interface.zoom_on_hover.value() == ZoomMode.SHIFT
		 and not Input.is_physical_key_pressed(KEY_SHIFT))):
		if _currently_zoomed_control:
			_currently_zoomed_control.offset_transform_enabled = false
			_currently_zoomed_control.z_index -= 5
			_currently_zoomed_control = null
		return
	if not _zoomable_controls:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var new_zoomable_control: Control = null
	for control in _zoomable_controls:
		if not control:
			continue
		if control.visible and Utils.get_screen_rect(control).has_point(mouse_pos):
			if not new_zoomable_control or Utils.get_absolute_z_index(control) > Utils.get_absolute_z_index(new_zoomable_control):
				new_zoomable_control = control
	if _currently_zoomed_control == new_zoomable_control:
		return

	if _currently_zoomed_control:
		_currently_zoomed_control.offset_transform_enabled = false
		_currently_zoomed_control.z_index -= 5
	if new_zoomable_control:
		var rect := Utils.get_screen_rect(new_zoomable_control)
		rect = rect.grow_individual(
			rect.size.x * 0.25,
			rect.size.y * 0.25,
			rect.size.x * 0.25,
			rect.size.y * 0.25)

		var pivot_override := _zoomable_controls[new_zoomable_control]
		if pivot_override.x >= 0:
			new_zoomable_control.offset_transform_pivot_ratio.x = pivot_override.x
		elif rect.position.x < 0:
			new_zoomable_control.offset_transform_pivot_ratio.x = 0.0
		elif rect.end.x > 1920:
			new_zoomable_control.offset_transform_pivot_ratio.x = 1.0
		else:
			new_zoomable_control.offset_transform_pivot_ratio.x = 0.5

		if pivot_override.y >= 0:
			new_zoomable_control.offset_transform_pivot_ratio.y = pivot_override.y
		elif rect.end.y > 1080:
			new_zoomable_control.offset_transform_pivot_ratio.y = 1.0
		else:
			new_zoomable_control.offset_transform_pivot_ratio.y = 0.0
		new_zoomable_control.offset_transform_scale = Vector2(1.5, 1.5)
		new_zoomable_control.offset_transform_visual_only = false
		new_zoomable_control.offset_transform_enabled = true
		new_zoomable_control.z_index += 5
	_currently_zoomed_control = new_zoomable_control

func handle_esc() -> void:
	if not GlobalStartup.is_phase_finished(AsyncLoadedResource.LoadPhase.STARTUP):
		return

	var closeable_layers := DYNAMIC_LAYERS + [Layer.GAME]
	if GlobalTutorialSystem.get_current_tutorial():
		# Don't break tutorials by closing the menu they are attached to.
		closeable_layers = [Layer.PAUSE_MENU]

	for layer: Layer in closeable_layers:
		var children := _layers[layer].get_children()
		children.reverse()
		for child in children:
			if child.has_method('_handle_esc'):  # A bit magical, but makes for clean code.
				@warning_ignore('unsafe_method_access')
				if child._handle_esc():
					return

	if Utils.ensure(get_tree().current_scene.has_method('_handle_esc')):
		@warning_ignore('unsafe_method_access')
		if get_tree().current_scene._handle_esc():
			return

	Utils.ensure(_layers[Layer.PAUSE_MENU].get_child_count() == 0)  # Otherwise should've caught _handle_esc().
	toggle_pause_menu()

func toggle_pause_menu() -> void:
	if _layers[Layer.PAUSE_MENU].get_child_count():
		var pause_menu := _layers[Layer.PAUSE_MENU].get_child(0) as PauseMenu
		if Utils.ensure(pause_menu != null):
			pause_menu._handle_esc()
	else:
		var pause_menu := PAUSE_MENU_SCENE.instantiate_loaded_scene() as PauseMenu
		pause_menu.closed.connect(pause_menu_closed.emit)
		_layers[Layer.PAUSE_MENU].add_child(pause_menu)
		pause_menu_opened.emit()

func add_layer_content(node: Node, layer: Layer) -> void:
	_layers[layer].add_child(node)

func clear_layer(layer: Layer) -> void:
	Utils.clear_node(_layers[layer])

func get_layer(layer: Layer) -> Node2D:
	return _layers[layer]

func reset() -> void:
	_ui_hidden = false
	for layer_id in _layers:
		if layer_id in PERSISTENT_LAYERS:
			continue
		Utils.clear_node(_layers[layer_id])

func show_dialogue(dialogue: Dialogue) -> void:
	var hub := Utils.get_active_hub()
	if hub:
		await hub.play_dialogue(dialogue)
	else:
		var dialogue_display := DIALOGUE_DISPLAY_SCENE.instantiate_loaded_scene() as DialogueDisplay
		dialogue_display.dialogue = dialogue
		dialogue_display.finished.connect(dialogue_ended.emit)
		add_layer_content(dialogue_display, Layer.DIALOGUE)
		await dialogue_display.finished

func show_error(error_message: String) -> void:
	(_layers[Layer.NOTIFICATION].get_child(0) as ErrorNotificationsList).show_error(error_message)

func show_loading_transition(transition_type: TransitionType) -> void:
	match transition_type:
		TransitionType.NONE:
			pass
		TransitionType.CLEAR:
			add_layer_content(CLEAR_LOAD_SCREEN_SCENE.instantiate_loaded_scene(), Layer.LOADING_SCREEN)
		TransitionType.ZOOM:
			add_layer_content(ZOOM_LOAD_SCREEN_SCENE.instantiate_loaded_scene(), Layer.LOADING_SCREEN)
		TransitionType.PORTAL:
			add_layer_content(PORTAL_LOAD_SCREEN_SCENE.instantiate_loaded_scene(), Layer.LOADING_SCREEN)
		TransitionType.FADE_TO_BLACK:
			add_layer_content(FADE_TO_BLACK_LOAD_SCREEN_SCENE.instantiate_loaded_scene(), Layer.LOADING_SCREEN)
		TransitionType.SCROLLIFY:
			add_layer_content(SCROLLIFY_LOAD_SCREEN_SCENE.instantiate_loaded_scene(), Layer.LOADING_SCREEN)

func show_confirm(title: String, text: String,
				  confirm_text: String = tr('Ok'), cancel_text: String = tr('Cancel'),
				  extra_button_text: String = '') -> ConfirmDialog:
	var confirm: ConfirmDialog = CONFIRM_SCENE.instantiate_loaded_scene()
	confirm.title = title
	confirm.text = text
	confirm.confirm_text = confirm_text
	confirm.cancel_text = cancel_text
	confirm.extra_button_text = extra_button_text
	_layers[Layer.MODAL].add_child(confirm)
	return confirm

@warning_ignore('int_as_enum_without_match')
func get_highest_interactive_layer(except: Layer = -1 as Layer) -> Layer:
	if Console.is_visible():
		return Layer.DEV_CONSOLE
	for layer: Layer in DYNAMIC_LAYERS:
		if layer == except:
			continue
		for child in _layers[layer].get_children():
			if Utils.ensure(child is Control or child is Node2D):
				@warning_ignore('unsafe_property_access')  # Duck typing
				if child.visible:
					return layer
	return Layer.GAME

func choose_dynamic_menu_layer() -> Layer:
	var highest := get_highest_interactive_layer()
	if highest >= UI.Layer.PAUSE_MENU:
		return UI.Layer.PAUSE_MENU_SUBMENU
	elif highest >= UI.Layer.ANNOUNCEMENT:
		return UI.Layer.ANNOUNCEMENT_SUBMENU
	elif highest >= UI.Layer.GAME_MENU_SUBMENU:
		return UI.Layer.STATE_MENU_SUBMENU
	else:
		return UI.Layer.GAME_MENU_SUBMENU

func is_higher_level_active(node: Node) -> bool:
	var node_z_index := Utils.get_absolute_z_index(node)
	return get_highest_interactive_layer() > node_z_index

func is_dialogue_active() -> bool:
	return _layers[Layer.DIALOGUE].get_child_count() > 0
