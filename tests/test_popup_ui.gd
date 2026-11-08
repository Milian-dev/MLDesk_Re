extends SceneTree

# Run with: godot --headless --path . --script res://tests/test_popup_ui.gd
# Persistence hooks are replaced so UI checks never touch personal notes/settings.
class PopupScene:
	extends "res://scripts/Scene.gd"
	var note_save_count := 0
	var last_saved_note := ""
	func _setup_window() -> void:
		pass
	func _setup_notebook() -> void:
		note_save_timer = Timer.new()
		note_save_timer.one_shot = true
		note_save_timer.wait_time = 10.0
		add_child(note_save_timer)
		note_save_timer.timeout.connect(_save_note_text)
	func _load_config() -> void:
		pass
	func _save_config() -> void:
		pass
	func _save_note_text() -> void:
		note_save_count += 1
		last_saved_note = note_input.text
	func _setup_system_tray() -> void:
		pass
	func _apply_scale() -> void:
		pass
	func _restore_saved_pet_position() -> void:
		pass
	func _update_mouse_mask() -> void:
		pass
	func _update_sleep_state() -> void:
		pass
	func _update_dinner_state() -> void:
		pass
	func _position_timer_window_over_pet() -> void:
		timer_window.position = Vector2i(40, 40)

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(800, 600)
	var scene = load("res://map/Scene.tscn").instantiate()
	scene.set_script(PopupScene)
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.idle_variant_timer.stop()
	_test_close_buttons(scene)
	_test_timer_reopen_and_alarm(scene)
	await _test_layout_and_wrapping(scene)
	scene.queue_free()
	await process_frame
	print("Popup UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _test_close_buttons(scene) -> void:
	_check(scene.button_close_note.get_parent() == scene.note_window and scene.button_close_timer.get_parent() == scene.timer_window, "close buttons belong directly to their windows")
	for close_button in [scene.button_close_note, scene.button_close_timer]:
		_check(close_button.texture_normal.resource_path == "res://ui/checkbox_closed.png", "close button uses requested image")
	scene.note_window.show()
	scene.note_input.text = "Keep this note when the window closes."
	scene.note_save_timer.start(10.0)
	var saved_before: int = scene.note_save_count
	scene.button_close_note.pressed.emit()
	_check(not scene.note_window.visible and scene.note_save_timer.is_stopped(), "note close hides window and cancels delayed save")
	_check(scene.note_save_count == saved_before + 1 and scene.last_saved_note == scene.note_input.text, "note close flushes the latest text immediately")
	scene.note_window.show()
	scene.note_window.close_requested.emit()
	_check(not scene.note_window.visible and scene.note_save_count == saved_before + 2, "native note close uses the same saving behavior")
	scene.timer_window.show()
	scene.timer_end_time = Time.get_unix_time_from_system() + 90.0
	scene.timer_seconds_remaining = 90
	scene.button_close_timer.pressed.emit()
	_check(not scene.timer_window.visible and scene.timer_end_time == 0.0 and scene.timer_seconds_remaining == 0, "timer close cancels the countdown and hides its window")
	_check(scene.timer_label.text == "00:00" and scene.button_clock.disabled and not scene.clock_sprite.visible, "timer close resets timer display and alarm controls")


func _test_timer_reopen_and_alarm(scene) -> void:
	scene.timer_input.text = "2"
	scene._on_button_timer_ok_pressed()
	_check(scene.timer_window.visible and scene.timer_panel.visible and scene.timer_seconds_remaining == 120, "closed timer can start a new countdown")
	scene._finish_timer()
	_check(scene.clock_sprite.visible and scene.clock_sprite.is_playing() and not scene.timer_panel.visible, "timer completion displays its alarm")
	_check(scene.button_close_timer.is_visible_in_tree(), "timer close remains available when countdown panel is hidden")
	scene.button_close_timer.pressed.emit()
	_check(not scene.timer_window.visible and not scene.clock_sprite.visible and not scene.clock_sprite.is_playing() and scene.button_clock.disabled, "close button dismisses and stops the alarm")
	scene.timer_window.show()
	scene.timer_end_time = Time.get_unix_time_from_system() + 60.0
	scene.timer_seconds_remaining = 60
	scene.timer_window.close_requested.emit()
	_check(not scene.timer_window.visible and scene.timer_end_time == 0.0 and scene.timer_seconds_remaining == 0, "native timer close cancels the countdown")


func _close_button_fits(window: Window) -> bool:
	var close_button: TextureButton = window.get_node("Button_close")
	var bounds := Rect2(close_button.position, close_button.size * close_button.scale)
	return bounds.position.x >= 0.0 and bounds.position.y >= 0.0 and bounds.end.x <= window.size.x and bounds.end.y <= window.size.y


func _test_layout_and_wrapping(scene) -> void:
	scene.window_scale = 1.5
	scene._apply_window_scale()
	scene.note_window.show()
	await process_frame
	_check(scene.note_window.size == Vector2i(450, 300) and scene.timer_window.size == Vector2i(450, 120), "popup sizes follow configured window scale")
	_check(scene.note_input.position == Vector2.ZERO and scene.note_input.size == Vector2(300, 200), "note editor fills the scaled note window")
	_check(_close_button_fits(scene.note_window) and _close_button_fits(scene.timer_window), "scaled close buttons stay inside the top-right corners")
	var timer_background: Control = scene.timer_panel.get_node("Panel")
	_check(timer_background.size == Vector2(300, 80) and timer_background.scale == Vector2.ONE, "timer background matches its full window size")
	_check(scene.note_input.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY and scene.note_input.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "note uses smart wrapping at the editor boundary")
	_check(not scene.note_input.context_menu_enabled and not scene.note_input.caret_move_on_right_click, "right dragging does not open a text menu or move the caret")
	_check(scene.note_input.get_theme_stylebox("normal").get_content_margin(SIDE_TOP) >= 28.0, "note text reserves space below the close button")
	var text := "These notes should wrap to the window width while preserving the stored text. ".repeat(12)
	scene.note_input.text = text
	scene.note_window.size = Vector2i(540, 300)
	await process_frame
	await process_frame
	var wide_wraps: int = scene.note_input.get_line_wrap_count(0)
	_check(scene.note_input.size.x == 360.0 and wide_wraps > 0, "wider note window updates the editor width and wraps long text")
	scene.note_window.size = Vector2i(240, 300)
	await process_frame
	await process_frame
	_check(scene.note_input.size.x == 160.0 and scene.note_input.get_line_wrap_count(0) > wide_wraps, "narrowing the note window increases visual line wrapping")
	_check(scene.note_input.text == text and scene.note_input.get_line_count() == 1, "automatic wrapping leaves stored text and explicit newlines unchanged")
	_check(_close_button_fits(scene.note_window), "note close button follows width changes")
	scene.note_input.text = "unbroken".repeat(30)
	await process_frame
	_check(scene.note_input.get_line_wrap_count(0) > 0, "long unbroken text wraps within the note width")
