extends SceneTree

# Run with: godot --headless --path . --script res://tests/test_popup_window.gd
class TestPopup:
	extends "res://scripts/PopupWindow.gd"
	var mouse_position := Vector2i.ZERO
	var right_button_pressed := false
	func _get_mouse_screen_position() -> Vector2i:
		return mouse_position
	func _is_right_button_pressed() -> bool:
		return right_button_pressed

class InputProbe:
	extends TextEdit
	var right_clicks_received := 0
	var left_clicks_received := 0
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				right_clicks_received += 1
			elif event.button_index == MOUSE_BUTTON_LEFT:
				left_clicks_received += 1

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _mouse_button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(60, 60)
	event.global_position = event.position
	return event


func _run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(640, 480)
	var popup := TestPopup.new()
	popup.visible = false
	popup.borderless = true
	popup.position = Vector2i(20, 30)
	popup.size = Vector2i(300, 200)
	var editor := InputProbe.new()
	editor.size = Vector2(300, 200)
	editor.text = "First line\nSecond line"
	popup.add_child(editor)
	root.add_child(popup)
	popup.show()
	await process_frame
	_check(popup.is_processing_input(), "window input is enabled")
	_check(not popup.is_right_dragging and not popup.is_processing(), "popup starts without polling for drag")

	popup.mouse_position = popup.position + Vector2i(60, 60)
	popup.right_button_pressed = true
	var press := _mouse_button(MOUSE_BUTTON_RIGHT, true)
	popup.push_input(press, true)
	_check(editor.right_clicks_received == 0, "right press is consumed before the text editor")
	_check(popup.is_right_dragging and popup.is_processing(), "right press starts dragging")
	_check(popup.right_drag_offset == Vector2i(60, 60), "right press preserves cursor offset")
	popup.mouse_position += Vector2i(40, 25)
	popup._process(0.0)
	_check(popup.position == Vector2i(60, 55), "drag follows global mouse without snapping the cursor")
	popup.mouse_position = Vector2i(600, 400)
	popup._process(0.0)
	_check(popup.position == Vector2i(540, 340), "drag continues beyond the original popup bounds")
	popup.right_button_pressed = false
	popup._process(0.0)
	_check(not popup.is_right_dragging and not popup.is_processing(), "right release outside ends polling")
	var released_position := popup.position
	popup.mouse_position += Vector2i(20, 20)
	await process_frame
	_check(popup.position == released_position, "released popup no longer follows pointer")

	popup.position = Vector2i(20, 30)
	popup.mouse_position = popup.position + Vector2i(60, 60)
	popup.right_button_pressed = true
	popup.push_input(press, true)
	popup.hide()
	_check(not popup.is_right_dragging and not popup.is_processing(), "hiding popup cancels dragging")
	popup.show()
	popup.push_input(press, true)
	popup.focus_exited.emit()
	_check(not popup.is_right_dragging and not popup.is_processing(), "losing focus cancels dragging")
	popup.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true), true)
	_check(not popup.is_right_dragging, "left press leaves window position handling unchanged")
	_check(editor.left_clicks_received == 1, "left press still reaches the text editor")
	popup.push_input(press, true)
	popup.push_input(_mouse_button(MOUSE_BUTTON_RIGHT, false), true)
	_check(not popup.is_right_dragging, "right release event cancels dragging")
	popup.queue_free()
	await process_frame
	print("Popup windows: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
