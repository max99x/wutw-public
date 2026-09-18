@tool
class_name UkiyoeButton
extends Button

const TRANSITION_SPEED = 12

@export var hover_sound: WwiseEvent
@export var click_sound: WwiseEvent
@export var stylebox_override: StyleBox
@export var scale_font_size: bool = false

var manually_hovered := false

var _shadow: TextureRect
var _state: float = 0.0
var _default_font_size: int

func _ready() -> void:
	if not material or (material as ShaderMaterial).shader.resource_path == 'res://theme/button/ukiyoe_button.gdshader':
		if not Utils.is_in_editor():
			if Utils.is_compatibility_renderer():
				material = load('res://theme/button/ukiyoe_button_material_compatibility.tres').duplicate()
			else:
				material = load('res://theme/button/ukiyoe_button_material.tres')

	var stylebox := stylebox_override if stylebox_override else load('res://theme/button/ukiyoe_button_stylebox.tres') as StyleBox
	add_theme_stylebox_override('normal', stylebox)
	add_theme_stylebox_override('hover', stylebox)
	add_theme_stylebox_override('pressed', stylebox)
	add_theme_stylebox_override('disabled', stylebox)
	add_theme_stylebox_override('hover_pressed', stylebox)

	if not Utils.is_in_editor():  # Avoid dirtying scenes on every reload.
		if Utils.is_compatibility_renderer():
			(material as ShaderMaterial).set_shader_parameter('background_offset', Vector2(randf(), randf()))
		else:
			set_instance_shader_parameter('background_offset', Vector2(randf(), randf()))

	_shadow = TextureRect.new()
	_shadow.texture = load('res://theme/button/button_shadow.png')
	_shadow.show_behind_parent = true
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_shadow, false, Node.INTERNAL_MODE_FRONT)

	mouse_entered.connect(func() -> void:
		if not disabled:
			GlobalAudioSystem.play(hover_sound.id if hover_sound else AK.EVENTS.UI_GAMEPLAY_BUTTON_HOVER)
	)
	pressed.connect(func() -> void:
		GlobalAudioSystem.play(click_sound.id if click_sound else AK.EVENTS.UI_GAMEPLAY_BUTTON_SELECT_SMALL)
	)
	focus_mode = Control.FOCUS_NONE

	if scale_font_size:
		_default_font_size = get_theme_font_size('font_size')
		_update_font_size()
		GlobalGameSettings.changed.connect(_update_font_size)

	_process(100)  # Instantly update state (e.g. for disabled).

func _process(delta: float) -> void:
	_shadow.size.x = size.x
	_shadow.size.y = min(size.y + 3, 45)
	_shadow.position.y = size.y - 40;

	if disabled:
		_state = -1
	elif button_pressed:
		_state = 2
	elif is_hovered() or manually_hovered:
		_state = 1
	else:
		_state = 0
	var current_state_variant: Variant
	if Utils.is_compatibility_renderer():
		current_state_variant = (material as ShaderMaterial).get_shader_parameter('state')
	else:
		current_state_variant = get_instance_shader_parameter('state')
	var current_state := current_state_variant as float if current_state_variant else 0.0
	var new_state := lerpf(current_state, _state, TRANSITION_SPEED * delta)

	if Utils.is_compatibility_renderer():
		(material as ShaderMaterial).set_shader_parameter('state', new_state)
	else:
		set_instance_shader_parameter('state', new_state)

func _update_font_size() -> void:
	var font_size := _default_font_size
	font_size = roundi(font_size * GameSettings.Interface.paragraph_font_scale.value())
	add_theme_font_size_override('font_size', font_size)
