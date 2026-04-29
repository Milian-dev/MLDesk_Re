extends Sprite2D

var dragging = false
var drag_offset = Vector2.ZERO


func _get_popup_window() -> Window:
	return get_window()

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if dragging:
		var popup_window = _get_popup_window()
		if popup_window == null:
			return

		var target_pos = Vector2(DisplayServer.mouse_get_position()) - drag_offset
		popup_window.position = Vector2i(target_pos)



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = false


func _on_button_drag_button_down() -> void:
	var popup_window = _get_popup_window()
	if popup_window == null:
		return

	dragging = true
	drag_offset = Vector2(DisplayServer.mouse_get_position()) - Vector2(popup_window.position)


func _on_button_drag_button_up() -> void:
	dragging = false
