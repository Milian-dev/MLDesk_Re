extends Window

var is_right_dragging := false
var right_drag_offset := Vector2i.ZERO


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	focus_exited.connect(_stop_right_drag)
	set_process(false)


func _input(event: InputEvent) -> void:
	_on_window_input(event)


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and visible:
			right_drag_offset = _get_mouse_screen_position() - position
			is_right_dragging = true
			set_process(true)
		else:
			_stop_right_drag()
		# Handle this before child controls can move the caret or open a menu.
		set_input_as_handled()
	elif event is InputEventMouseMotion and is_right_dragging:
		_move_window_to_mouse()
		set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible or not _is_right_button_pressed():
		_stop_right_drag()
		return
	_move_window_to_mouse()


func _move_window_to_mouse() -> void:
	position = _get_mouse_screen_position() - right_drag_offset


func _stop_right_drag() -> void:
	is_right_dragging = false
	set_process(false)


func _on_visibility_changed() -> void:
	if not visible:
		_stop_right_drag()


func _get_mouse_screen_position() -> Vector2i:
	return DisplayServer.mouse_get_position()


func _is_right_button_pressed() -> bool:
	return (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_RIGHT) != 0
