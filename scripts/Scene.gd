extends Node2D

const IDLE_VARIANTS := ["idle_read", "idle_bass", "idle_watermelon", "idle_cat", "idle_swing", "idle_work"]
const IDLE_VARIANT_WAIT_MIN := 60.0
const IDLE_VARIANT_WAIT_MAX := 90.0
const IDLE_VARIANT_PLAY_MIN := 180.0
const IDLE_VARIANT_PLAY_MAX := 360.0

const IDLE_SLEEP_DELAY := 600.0
const NIGHT_SLEEP_START_HOUR := 23
const NIGHT_SLEEP_END_HOUR := 9
const DINNER_TIME := [Vector2i(12, 00), Vector2i(18, 30)]
const DINNER_DURATION_MINUTES := 30

const TILT_DEADZONE := 300.0
const TILT_FAST_THRESHOLD := 600.0
const STAT_MIN := 0
const STAT_MAX := 3
const STAT_DECAY_INTERVAL := 1800.0
const NOTE_WINDOW_GAP := 0
const BASE_TIMER_WINDOW_SIZE := Vector2i(300, 80)
const BASE_NOTE_WINDOW_SIZE := Vector2i(300, 200)
const NOTEBOOK_DIR := "user://data"
const NOTEBOOK_PATH := "user://data/notebook.txt"
const CONFIG_PATH := "user://data/config.txt"
const TIPS_PATH := "res://data/tips.txt"
const NOTE_SAVE_DELAY := 0.5
const STARTUP_ENTRY_NAME := "MLDeskPetStartup.cmd"
const TRAY_MENU_ID_TOGGLE_VISIBILITY := 1
const TRAY_MENU_ID_QUIT := 2
const SETTING_WINDOW_LEAVE_GRACE_SECONDS := 0.5


var pet_scale := 2.0
var window_scale := 1.0
var clock_size := 1.5
var startup_enabled := false
var has_saved_pet_position := false
var saved_pet_position := Vector2i.ZERO

var drag_offset = Vector2()
var last_mouse_global := Vector2.ZERO
var drag_velocity_x := 0.0

var is_dragging = false
var is_hovering = false

var is_sleeping = false
var is_dinner_time = false
var is_idle_napping = false
var is_idle_variant_playing = false
var is_hand_interaction_playing = false
var is_interactible := true
var mood := 2
var health := 2
var low_mood_acknowledged := false
var low_health_acknowledged := false
var timer_seconds_remaining := 0
var timer_end_time := 0.0
var note_save_timer: Timer
var tip_hide_timer: Timer
var tray_indicator: StatusIndicator
var tray_menu: PopupMenu
var tips_show_time := 4.0
var tip_lines: Array[String] = []

var last_mouse_move_time := 0.0
var last_pet_time := 0.0
var last_feed_time := 0.0
var current_dinner_window := -1
var current_dinner_key := ""
var rewarded_dinner_key := ""
var setting_window_open_time := 0.0

@onready var anim_player: AnimationPlayer = $Milian/AnimationPlayer
@onready var idle_variant_timer: Timer = $Timer_idle_variant
@onready var area_hit: Area2D = $Milian/area_hit
@onready var collision_shape: CollisionShape2D = $Milian/area_hit/collision_hit
@onready var body_node = $Milian/body
@onready var hand_sprite: AnimatedSprite2D = $Milian/body/hand_marker/hand
@onready var status_mood: AnimatedSprite2D = $Milian/body/status_mood
@onready var status_health: AnimatedSprite2D = $Milian/body/status_health
@onready var setting_window: Window = $Window_setting
@onready var setting_ui: Control = $Window_setting/Control
@onready var timer_window: Window = $Window_timer
@onready var timer_panel: Sprite2D = $Window_timer/Window_timer
@onready var timer_label: Label = $Window_timer/Window_timer/Panel/TimerLabel
@onready var button_clock: Button = $Window_timer/Button_clock
@onready var clock_sprite: AnimatedSprite2D = $Window_timer/Clock
@onready var note_window: Window = $Window_note
@onready var note_panel: Sprite2D = $Window_note/Window_note
@onready var note_input: TextEdit = $Window_note/Window_note/TextEdit
@onready var tip_window: Window = $Window_tip
@onready var tip_panel: Sprite2D = $Window_tip/Window_tip
@onready var tip_input: TextEdit = $Window_tip/Window_tip/TextEdit
@onready var menu_panel: Sprite2D = $Window_setting/Control/Window
@onready var timer_setup_panel: Sprite2D = $Window_setting/Control/Window_time_setup
@onready var settings_panel: Sprite2D = $Window_setting/Control/Window_setting
@onready var button_pet: Button = $Window_setting/Control/Window/Button_pet
@onready var button_feed: Button = $Window_setting/Control/Window/Button_feed
@onready var button_timer: Button = $Window_setting/Control/Window/Button_timer
@onready var button_note: Button = $Window_setting/Control/Window/Button_note
@onready var button_setting: Button = $Window_setting/Control/Window/Button_setting
@onready var slider_pet_size: HSlider = $Window_setting/Control/Window_setting/HSlider_pet_size
@onready var checkbox_startup: CheckBox = $Window_setting/Control/Window_setting/CheckBox_startup
@onready var button_timer_ok: Button = $Window_setting/Control/Window_time_setup/Button_timer_ok
@onready var button_timer_cancel: Button = $Window_setting/Control/Window_time_setup/Button_timer_cancel
@onready var timer_input: LineEdit = $Window_setting/Control/Window_time_setup/LineEdit_timer_input


func _ready() -> void:
	_setup_window()
	_setup_setting_window()
	_setup_notebook()
	_setup_tips()
	_load_config()
	_apply_scale()
	_restore_saved_pet_position()
	_setup_system_tray()
	_connect_signals()

	await get_tree().process_frame
	_update_mouse_mask()

	var now = Time.get_unix_time_from_system()
	last_mouse_move_time = now
	last_pet_time = now
	last_feed_time = now
	_update_status_frames()
	_enter_idle_state()
	_schedule_next_idle_variant()
	

func _setup_window() -> void:
	var window = get_window()

	get_viewport().transparent_bg = true
	window.transparent = true
	window.borderless = true
	window.always_on_top = true
	window.unresizable = false

	var base_size = Vector2i(100, 100)
	window.size = base_size * pet_scale

	var usable_rect = DisplayServer.screen_get_usable_rect()
	var target_y = usable_rect.end.y - window.size.y
	window.position = Vector2i(usable_rect.end.x / 2, target_y)


func _setup_setting_window() -> void:
	setting_window.hide()
	setting_window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	setting_window.transparent_bg = true
	setting_window.transparent = true
	setting_window.borderless = true
	setting_window.always_on_top = true
	setting_window.unresizable = true
	timer_window.hide()
	timer_window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	timer_window.transparent_bg = true
	timer_window.transparent = true
	timer_window.borderless = true
	timer_window.always_on_top = true
	timer_window.unresizable = true
	timer_panel.show()
	button_clock.disabled = true
	note_window.hide()
	note_window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	note_window.transparent_bg = true
	note_window.transparent = true
	note_window.borderless = true
	note_window.always_on_top = true
	note_window.unresizable = true
	tip_window.hide()
	tip_window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	tip_window.transparent_bg = true
	tip_window.transparent = true
	tip_window.borderless = true
	tip_window.always_on_top = true
	tip_window.unresizable = true
	tip_input.editable = false
	_apply_window_scale()
	slider_pet_size.value = pet_scale
	checkbox_startup.button_pressed = startup_enabled
	hand_sprite.hide()
	clock_sprite.hide()
	timer_setup_panel.hide()
	settings_panel.hide()
	menu_panel.show()
	_update_setting_window_clip()
	_update_menu_buttons()


func _setup_notebook() -> void:
	DirAccess.make_dir_recursive_absolute(NOTEBOOK_DIR)
	if not FileAccess.file_exists(NOTEBOOK_PATH):
		var file = FileAccess.open(NOTEBOOK_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string("")
	if not FileAccess.file_exists(CONFIG_PATH):
		var config_file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
		if config_file != null:
			config_file.store_string(
				"pet_scale=%s\nstartup_enabled=%s\npet_position_x=%s\npet_position_y=%s\n"
				% [str(pet_scale), str(startup_enabled), str(get_window().position.x), str(get_window().position.y)]
			)

	note_save_timer = Timer.new()
	note_save_timer.one_shot = true
	note_save_timer.wait_time = NOTE_SAVE_DELAY
	add_child(note_save_timer)
	if not note_save_timer.timeout.is_connected(_save_note_text):
		note_save_timer.timeout.connect(_save_note_text)


func _setup_tips() -> void:
	_load_tips()

	tip_hide_timer = Timer.new()
	tip_hide_timer.one_shot = true
	tip_hide_timer.wait_time = tips_show_time
	add_child(tip_hide_timer)
	if not tip_hide_timer.timeout.is_connected(_hide_tip_window):
		tip_hide_timer.timeout.connect(_hide_tip_window)


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return

	var loaded_position_x = 0
	var loaded_position_y = 0
	var loaded_position_x_valid = false
	var loaded_position_y_valid = false

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue

		var parts = line.split("=", false, 1)
		if parts.size() != 2:
			continue

		if parts[0] == "pet_scale" and parts[1].is_valid_float():
			pet_scale = clampf(float(parts[1]), slider_pet_size.min_value, slider_pet_size.max_value)
			slider_pet_size.value = pet_scale
		elif parts[0] == "startup_enabled":
			startup_enabled = parts[1].to_lower() == "true"
			checkbox_startup.button_pressed = startup_enabled
		elif parts[0] == "pet_position_x" and parts[1].is_valid_int():
			loaded_position_x = int(parts[1])
			loaded_position_x_valid = true
		elif parts[0] == "pet_position_y" and parts[1].is_valid_int():
			loaded_position_y = int(parts[1])
			loaded_position_y_valid = true

	if loaded_position_x_valid and loaded_position_y_valid:
		has_saved_pet_position = true
		saved_pet_position = Vector2i(loaded_position_x, loaded_position_y)

	_apply_startup_setting()


func _save_config() -> void:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file != null:
		var window = get_window()
		file.store_string(
			"pet_scale=%s\nstartup_enabled=%s\npet_position_x=%s\npet_position_y=%s\n"
			% [str(pet_scale), str(startup_enabled), str(window.position.x), str(window.position.y)]
		)


func _apply_scale() -> void:
	$Milian.scale = Vector2(pet_scale, pet_scale)
	var window = get_window()
	var current_position = window.position
	window.size = Vector2i(Vector2(100, 100) * pet_scale)
	window.position = _clamp_pet_position(current_position)


func _restore_saved_pet_position() -> void:
	if not has_saved_pet_position:
		return

	get_window().position = _clamp_pet_position(saved_pet_position)


func _clamp_pet_position(position: Vector2i) -> Vector2i:
	var usable_rect = DisplayServer.screen_get_usable_rect()
	var window = get_window()
	var max_x = max(usable_rect.position.x, usable_rect.end.x - window.size.x)
	var max_y = max(usable_rect.position.y, usable_rect.end.y - window.size.y)
	return Vector2i(
		clampi(position.x, usable_rect.position.x, max_x),
		clampi(position.y, usable_rect.position.y, max_y)
	)


func _on_slider_pet_size_value_changed(value: float) -> void:
	pet_scale = value
	_apply_scale()
	_reposition_popup_windows()
	_update_mouse_mask()
	_save_config()


func _on_checkbox_startup_toggled(toggled_on: bool) -> void:
	startup_enabled = toggled_on
	_save_config()
	_apply_startup_setting()


func _exit_tree() -> void:
	_save_config()
	_save_note_text()

func _apply_window_scale() -> void:
	var scale_vec = Vector2(window_scale, window_scale)
	setting_ui.scale = scale_vec
	timer_panel.scale = scale_vec
	note_panel.scale = scale_vec
	tip_panel.scale = scale_vec
	clock_sprite.scale = scale_vec * clock_size

	setting_window.size = Vector2i(Vector2(setting_ui.size) * window_scale)
	timer_window.size = Vector2i(Vector2(BASE_TIMER_WINDOW_SIZE) * window_scale)
	note_window.size = Vector2i(Vector2(BASE_NOTE_WINDOW_SIZE) * window_scale)
	tip_window.size = Vector2i(Vector2(BASE_NOTE_WINDOW_SIZE) * window_scale)


func _connect_signals() -> void:
	if not idle_variant_timer.timeout.is_connected(_on_timer_idle_variant_timeout):
		idle_variant_timer.timeout.connect(_on_timer_idle_variant_timeout)
	if not button_pet.pressed.is_connected(_on_button_pet_pressed):
		button_pet.pressed.connect(_on_button_pet_pressed)
	if not button_feed.pressed.is_connected(_on_button_feed_pressed):
		button_feed.pressed.connect(_on_button_feed_pressed)
	if not button_timer.pressed.is_connected(_on_button_timer_pressed):
		button_timer.pressed.connect(_on_button_timer_pressed)
	if not button_note.pressed.is_connected(_on_button_note_pressed):
		button_note.pressed.connect(_on_button_note_pressed)
	if not note_input.text_changed.is_connected(_on_note_input_text_changed):
		note_input.text_changed.connect(_on_note_input_text_changed)
	if not button_setting.pressed.is_connected(_on_button_setting_pressed):
		button_setting.pressed.connect(_on_button_setting_pressed)
	if not slider_pet_size.value_changed.is_connected(_on_slider_pet_size_value_changed):
		slider_pet_size.value_changed.connect(_on_slider_pet_size_value_changed)
	if not checkbox_startup.toggled.is_connected(_on_checkbox_startup_toggled):
		checkbox_startup.toggled.connect(_on_checkbox_startup_toggled)
	if not button_timer_ok.pressed.is_connected(_on_button_timer_ok_pressed):
		button_timer_ok.pressed.connect(_on_button_timer_ok_pressed)
	if not button_timer_cancel.pressed.is_connected(_on_button_timer_cancel_pressed):
		button_timer_cancel.pressed.connect(_on_button_timer_cancel_pressed)
	if not button_clock.pressed.is_connected(_on_button_clock_pressed):
		button_clock.pressed.connect(_on_button_clock_pressed)
	if not get_window().close_requested.is_connected(_on_main_window_close_requested):
		get_window().close_requested.connect(_on_main_window_close_requested)


func ANIMATION():
	pass


func _play_anim(name: String) -> void:
	if not anim_player.has_animation(name):
		return
	if anim_player.current_animation == name and anim_player.is_playing():
		return
	anim_player.play(name)


func _play_interaction_variant_anim(name: String) -> void:
	if is_sleeping:
		var sleep_name = name + "_sleep"
		if anim_player.has_animation(sleep_name):
			_play_anim(sleep_name)
			return
	if is_dinner_time:
		var dinner_name = name + "_dinner"
		if anim_player.has_animation(dinner_name):
			_play_anim(dinner_name)
			return

	_play_anim(name)


func _play_anim_with_transition(name: String) -> void:
	var enter_anim = name + "_enter"

	if anim_player.has_animation(enter_anim):
		anim_player.play(enter_anim)
		await anim_player.animation_finished

	if anim_player.has_animation(name):
		anim_player.play(name)


func UPDATE():
	pass


func _process(_delta: float) -> void:
	_update_hover_state()
	_update_sleep_state()
	_update_dinner_state()
	_update_stats_decay()
	_update_timer_countdown()
	_close_setting_window_if_mouse_left()
	_refresh_interactible()


func INTERACTION():
	pass


func _input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _is_mouse_on_popup_window(timer_window) or _is_mouse_on_popup_window(note_window):
			return

		if clock_sprite.visible and _is_mouse_on_clock():
			_dismiss_clock_alarm()
			return

		if setting_window.visible and (
			event.button_index == MOUSE_BUTTON_LEFT
			or event.button_index == MOUSE_BUTTON_RIGHT
		):
			_hide_setting_window()
			return

	if event is InputEventMouseMotion:
		_mark_mouse_active()
		_update_hover_state()

		if is_dragging:
			var mouse_global = Vector2(DisplayServer.mouse_get_position())
			var new_pos = mouse_global - drag_offset
			var previous_pos = Vector2(DisplayServer.window_get_position())
			DisplayServer.window_set_position(Vector2i(new_pos))
			var pet_delta = new_pos - previous_pos

			if timer_window.visible:
				timer_window.position += Vector2i(pet_delta)
			if note_window.visible:
				note_window.position += Vector2i(pet_delta)
			if tip_window.visible:
				tip_window.position += Vector2i(pet_delta)

			drag_velocity_x = event.velocity.x
			_update_drag_tilt()

			last_mouse_global = mouse_global

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_mouse_on_popup_window(timer_window) or _is_mouse_on_popup_window(note_window):
				return
			if _is_mouse_on_pet():
				_start_drag()
		else:
			if is_dragging:
				_stop_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		if _is_mouse_on_popup_window(timer_window) or _is_mouse_on_popup_window(note_window):
			return
		if _is_mouse_on_pet():
			_show_random_tip()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _is_mouse_on_popup_window(timer_window) or _is_mouse_on_popup_window(note_window):
			return
		if _is_mouse_on_pet():
			_show_setting_window_at_mouse()

func _update_hover_state() -> void:
	if _is_feed_success_playing():
		return

	if is_dinner_time:
		return

	if is_idle_variant_playing:
		return

	var hover_now = _is_mouse_on_pet()

	if hover_now == is_hovering:
		return

	is_hovering = hover_now

	if is_dragging or is_sleeping or is_idle_napping:
		return

	if is_hovering:
		is_idle_variant_playing = false
		idle_variant_timer.stop()
		if _is_any_status_low():
			_enter_idle_state()
		else:
			_play_anim("hover")
	else:
		_enter_idle_state()
		_schedule_next_idle_variant()

func _update_drag_tilt() -> void:
	if not is_dragging:
		return

	if abs(drag_velocity_x) <= TILT_DEADZONE:
		_play_interaction_variant_anim("click")
		return

	if drag_velocity_x < 0.0:
		if abs(drag_velocity_x) >= TILT_FAST_THRESHOLD:
			_play_interaction_variant_anim("tilt_left_fast")
		else:
			_play_interaction_variant_anim("tilt_left_slow")
	else:
		if abs(drag_velocity_x) >= TILT_FAST_THRESHOLD:
			_play_interaction_variant_anim("tilt_right_fast")
		else:
			_play_interaction_variant_anim("tilt_right_slow")
			
func _is_mouse_on_pet() -> bool:
	var shape = collision_shape.shape
	if shape is RectangleShape2D:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position()) - Vector2(DisplayServer.window_get_position())
		var local_mouse = collision_shape.global_transform.affine_inverse() * mouse_pos
		var half_size = shape.size * 0.5

		return (
			local_mouse.x >= -half_size.x
			and local_mouse.x <= half_size.x
			and local_mouse.y >= -half_size.y
			and local_mouse.y <= half_size.y
		)

	return false


func _is_mouse_on_popup_window(popup_window: Window) -> bool:
	if popup_window == null or not popup_window.visible:
		return false

	var mouse_screen = Vector2(DisplayServer.mouse_get_position())
	var popup_rect = Rect2(Vector2(popup_window.position), Vector2(popup_window.size))
	return popup_rect.has_point(mouse_screen)


func _is_mouse_on_setting_window() -> bool:
	if setting_window == null or not setting_window.visible:
		return false

	var active_panel := _get_active_setting_panel()
	if active_panel == null:
		return false

	var mouse_screen = Vector2(DisplayServer.mouse_get_position())
	var clip_rect := _get_setting_panel_clip_rect(active_panel)
	var popup_rect = Rect2(Vector2(setting_window.position) + clip_rect.position, clip_rect.size)
	return popup_rect.has_point(mouse_screen)


func _close_setting_window_if_mouse_left() -> void:
	if not setting_window.visible:
		return

	if Time.get_unix_time_from_system() - setting_window_open_time < SETTING_WINDOW_LEAVE_GRACE_SECONDS:
		return

	if _is_mouse_on_setting_window():
		return

	_hide_setting_window()


func _update_mouse_mask() -> void:
	var shape = collision_shape.shape
	var polygons: Array[PackedVector2Array] = []

	if shape is RectangleShape2D:
		var half_size = shape.size * 0.5
		var xf = collision_shape.global_transform

		var poly := PackedVector2Array([
			xf * Vector2(-half_size.x, -half_size.y),
			xf * Vector2(half_size.x, -half_size.y),
			xf * Vector2(half_size.x, half_size.y),
			xf * Vector2(-half_size.x, half_size.y),
		])

		polygons.append(poly)

	DisplayServer.window_set_mouse_passthrough(polygons)


func _get_active_setting_panel() -> Node2D:
	if settings_panel.visible:
		return settings_panel
	if timer_setup_panel.visible:
		return timer_setup_panel
	if menu_panel.visible:
		return menu_panel
	return null


func _get_setting_panel_clip_rect(panel: Node2D) -> Rect2:
	var frame := panel.get_node_or_null("Panel") as Control
	if frame == null:
		return Rect2(Vector2.ZERO, Vector2(setting_window.size))

	return Rect2(
		(panel.position + frame.position) * window_scale,
		frame.size * window_scale
	)


func _update_setting_window_clip(keep_mouse_inside := false) -> void:
	if setting_window == null:
		return

	if not setting_window.visible:
		return

	var active_panel := _get_active_setting_panel()
	if active_panel == null:
		_clear_setting_window_mouse_passthrough()
		return

	var clip_rect := _get_setting_panel_clip_rect(active_panel)
	var clip_end := clip_rect.end.ceil()
	setting_window.size = Vector2i(
		max(1, int(clip_end.x)),
		max(1, int(clip_end.y))
	)
	if keep_mouse_inside:
		_nudge_setting_window_to_mouse()

	var polygons: Array[PackedVector2Array] = [
		PackedVector2Array([
			clip_rect.position,
			Vector2(clip_rect.end.x, clip_rect.position.y),
			clip_rect.end,
			Vector2(clip_rect.position.x, clip_rect.end.y),
		])
	]
	DisplayServer.window_set_mouse_passthrough(polygons, setting_window.get_window_id())


func _nudge_setting_window_to_mouse() -> void:
	var mouse_screen = Vector2(DisplayServer.mouse_get_position())
	var position := Vector2(setting_window.position)
	var size := Vector2(setting_window.size)
	var next_position := position

	if mouse_screen.x < position.x:
		next_position.x = mouse_screen.x
	elif mouse_screen.x >= position.x + size.x:
		next_position.x = mouse_screen.x - size.x + 1.0

	if mouse_screen.y < position.y:
		next_position.y = mouse_screen.y
	elif mouse_screen.y >= position.y + size.y:
		next_position.y = mouse_screen.y - size.y + 1.0

	var usable_rect = DisplayServer.screen_get_usable_rect()
	next_position.x = clampf(
		next_position.x,
		float(usable_rect.position.x),
		float(max(usable_rect.position.x, usable_rect.end.x - setting_window.size.x))
	)
	next_position.y = clampf(
		next_position.y,
		float(usable_rect.position.y),
		float(max(usable_rect.position.y, usable_rect.end.y - setting_window.size.y))
	)

	setting_window.position = Vector2i(next_position.round())


func _clear_setting_window_mouse_passthrough() -> void:
	var polygons: Array[PackedVector2Array] = []
	DisplayServer.window_set_mouse_passthrough(polygons, setting_window.get_window_id())


func _hide_setting_window() -> void:
	if setting_window.visible:
		_clear_setting_window_mouse_passthrough()
	setting_window.hide()


func _show_setting_window_at_mouse() -> void:
	var usable_rect = DisplayServer.screen_get_usable_rect()
	var mouse_screen = Vector2(DisplayServer.mouse_get_position())
	menu_panel.show()
	timer_setup_panel.hide()
	settings_panel.hide()
	setting_window_open_time = Time.get_unix_time_from_system()
	setting_window.show()
	_update_setting_window_clip()
	var popup_size = setting_window.size
	var max_x = max(usable_rect.position.x, usable_rect.end.x - popup_size.x)
	var max_y = max(usable_rect.position.y, usable_rect.end.y - popup_size.y)

	var clamped_x = clampi(
		int(round(mouse_screen.x)),
		usable_rect.position.x,
		max_x
	)
	var clamped_y = clampi(
		int(round(mouse_screen.y)),
		usable_rect.position.y,
		max_y
	)

	setting_window.position = Vector2i(clamped_x, clamped_y)
	_update_setting_window_clip()


func _refresh_interactible() -> void:
	var next_interactible = not is_sleeping \
		and not is_idle_napping \
		and not is_dragging \
		and not is_hand_interaction_playing \
		and not _is_feed_success_playing() \
		and anim_player.current_animation != "click"

	if next_interactible == is_interactible:
		return

	is_interactible = next_interactible
	_update_menu_buttons()


func _update_menu_buttons() -> void:
	if not is_interactible:
		button_pet.disabled = true
		button_feed.disabled = true
		return

	if is_hand_interaction_playing:
		button_pet.disabled = hand_sprite.animation == "feed_ignore"
		button_feed.disabled = hand_sprite.animation == "pet"
		return

	button_pet.disabled = not is_interactible
	button_feed.disabled = not is_interactible


func _on_button_pet_pressed() -> void:
	if not is_interactible:
		return

	menu_panel.hide()
	_hide_setting_window()
	_play_hand_interaction("pet", button_feed)


func _on_button_feed_pressed() -> void:
	if not is_interactible:
		return

	menu_panel.hide()
	_hide_setting_window()

	if is_idle_variant_playing or is_dinner_time:
		_play_hand_interaction("feed_ignore", button_pet)
		return

	_play_feed_success()


func _on_button_setting_pressed() -> void:
	menu_panel.hide()
	timer_setup_panel.hide()
	settings_panel.show()
	setting_window_open_time = Time.get_unix_time_from_system()
	_update_setting_window_clip(true)


func _on_button_timer_pressed() -> void:
	menu_panel.hide()
	settings_panel.hide()
	timer_setup_panel.show()
	setting_window_open_time = Time.get_unix_time_from_system()
	_update_setting_window_clip(true)
	_grab_focus_next_frame(timer_input, true)


func _on_button_note_pressed() -> void:
	if note_window.visible:
		_hide_note_window()
		return

	_hide_setting_window()
	_position_note_window()
	_load_note_text()
	note_window.show()
	_grab_focus_next_frame(note_input)


func _on_note_input_text_changed() -> void:
	if note_save_timer != null:
		note_save_timer.start()


func _save_note_text() -> void:
	var file = FileAccess.open(NOTEBOOK_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(note_input.text)


func _load_note_text() -> void:
	if not FileAccess.file_exists(NOTEBOOK_PATH):
		note_input.text = ""
		return

	var file = FileAccess.open(NOTEBOOK_PATH, FileAccess.READ)
	if file == null:
		return

	note_input.text = file.get_as_text()


func _hide_note_window() -> void:
	if note_save_timer != null:
		note_save_timer.stop()
	_save_note_text()
	note_window.hide()


func _show_random_tip() -> void:
	if tip_lines.is_empty():
		_load_tips()

	var tip_text = "No tips available."
	if not tip_lines.is_empty():
		tip_text = tip_lines[randi() % tip_lines.size()]

	tip_input.text = tip_text
	if not tip_window.visible:
		_position_tip_window()
	tip_window.show()
	tip_hide_timer.start(tips_show_time)


func _hide_tip_window() -> void:
	tip_window.hide()


func _load_tips() -> void:
	tip_lines = []

	if not FileAccess.file_exists(TIPS_PATH):
		return

	var file = FileAccess.open(TIPS_PATH, FileAccess.READ)
	if file == null:
		return

	var text = file.get_as_text()
	tip_lines = _parse_tip_lines(text)


func _parse_tip_lines(text: String) -> Array[String]:
	var lines: Array[String] = []

	for raw_line in text.split("\n"):
		var line = raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			continue
		lines.append(line)

	return lines


func _setup_system_tray() -> void:
	if OS.get_name() != "Windows" and OS.get_name() != "macOS":
		return

	tray_menu = PopupMenu.new()
	tray_menu.name = "TrayMenu"
	tray_menu.add_item("Hide Pet", TRAY_MENU_ID_TOGGLE_VISIBILITY)
	tray_menu.add_separator()
	tray_menu.add_item("Quit", TRAY_MENU_ID_QUIT)
	add_child(tray_menu)
	if not tray_menu.id_pressed.is_connected(_on_tray_menu_id_pressed):
		tray_menu.id_pressed.connect(_on_tray_menu_id_pressed)

	tray_indicator = StatusIndicator.new()
	tray_indicator.name = "TrayIndicator"
	var tray_icon = load("res://ui/project_icon_16x.png")
	if tray_icon is Texture2D:
		tray_indicator.icon = tray_icon
	tray_indicator.tooltip = "ML Desk"
	tray_indicator.visible = true
	add_child(tray_indicator)
	tray_indicator.menu = tray_indicator.get_path_to(tray_menu)


func _on_tray_menu_id_pressed(id: int) -> void:
	match id:
		TRAY_MENU_ID_TOGGLE_VISIBILITY:
			if get_window().visible:
				_hide_to_tray()
			else:
				_show_from_tray()
		TRAY_MENU_ID_QUIT:
			_save_config()
			get_tree().quit()


func _on_main_window_close_requested() -> void:
	_hide_to_tray()


func _hide_to_tray() -> void:
	_save_config()
	get_window().hide()
	_hide_setting_window()
	timer_window.hide()
	note_window.hide()
	_update_tray_menu_label()


func _show_from_tray() -> void:
	get_window().show()
	DisplayServer.window_move_to_foreground()
	_update_tray_menu_label()


func _update_tray_menu_label() -> void:
	if tray_menu == null:
		return

	var item_index = tray_menu.get_item_index(TRAY_MENU_ID_TOGGLE_VISIBILITY)
	if item_index == -1:
		return

	if get_window().visible:
		tray_menu.set_item_text(item_index, "Hide Pet")
	else:
		tray_menu.set_item_text(item_index, "Show Pet")


func _grab_focus_next_frame(control: Control, select_all: bool = false) -> void:
	_grab_focus_next_frame_impl.call_deferred(control, select_all)


func _grab_focus_next_frame_impl(control: Control, select_all: bool = false) -> void:
	await get_tree().process_frame
	if control == null or not is_instance_valid(control):
		return
	if not control.is_visible_in_tree():
		return

	control.grab_focus()
	if select_all and control is LineEdit:
		(control as LineEdit).select_all()


func _apply_startup_setting() -> void:
	var startup_entry_path = _get_startup_entry_path()
	if startup_entry_path.is_empty():
		return

	if startup_enabled:
		_write_startup_entry(startup_entry_path)
	else:
		_remove_startup_entry(startup_entry_path)


func _get_startup_entry_path() -> String:
	var appdata = OS.get_environment("APPDATA")
	if appdata.is_empty():
		return ""

	return appdata.path_join("Microsoft\\Windows\\Start Menu\\Programs\\Startup").path_join(STARTUP_ENTRY_NAME)


func _write_startup_entry(startup_entry_path: String) -> void:
	var executable_path = OS.get_executable_path()
	if executable_path.is_empty():
		return

	var launcher_contents = "@echo off\r\nstart \"\" \"%s\"\r\n" % executable_path
	var existing_contents = ""
	if FileAccess.file_exists(startup_entry_path):
		var existing_file = FileAccess.open(startup_entry_path, FileAccess.READ)
		if existing_file != null:
			existing_contents = existing_file.get_as_text()

	if existing_contents == launcher_contents:
		return

	var launcher_file = FileAccess.open(startup_entry_path, FileAccess.WRITE)
	if launcher_file != null:
		launcher_file.store_string(launcher_contents)


func _remove_startup_entry(startup_entry_path: String) -> void:
	if FileAccess.file_exists(startup_entry_path):
		DirAccess.remove_absolute(startup_entry_path)


func _on_button_timer_ok_pressed() -> void:
	var minutes_text = timer_input.text.strip_edges()
	if minutes_text.is_empty():
		return

	if not minutes_text.is_valid_int():
		return

	var minutes = int(minutes_text)
	if minutes <= 0:
		return

	timer_end_time = Time.get_unix_time_from_system() + minutes * 60.0
	timer_seconds_remaining = minutes * 60
	menu_panel.hide()
	settings_panel.hide()
	timer_setup_panel.hide()
	_hide_setting_window()
	timer_panel.show()
	button_clock.disabled = true
	clock_sprite.hide()
	clock_sprite.stop()
	timer_window.show()
	_update_timer_label()
	_position_timer_window_over_pet()
	if tip_window.visible:
		_position_tip_window()


func _on_button_timer_cancel_pressed() -> void:
	timer_setup_panel.hide()
	settings_panel.hide()
	menu_panel.show()
	setting_window_open_time = Time.get_unix_time_from_system()
	_update_setting_window_clip(true)


func _on_button_clock_pressed() -> void:
	if button_clock.disabled:
		return

	_dismiss_clock_alarm()


func _play_hand_interaction(animation_name: String, blocked_button: Button) -> void:
	if is_hand_interaction_playing:
		return

	is_hand_interaction_playing = true
	_refresh_interactible()
	blocked_button.disabled = true
	hand_sprite.animation = animation_name
	hand_sprite.frame = 0
	hand_sprite.show()
	hand_sprite.play(animation_name)
	_update_menu_buttons()
	_finish_hand_interaction.call_deferred(animation_name, blocked_button)


func _play_feed_success() -> void:
	if not anim_player.has_animation("feed_success"):
		return

	low_health_acknowledged = true
	anim_player.play("feed_success")
	_refresh_interactible()
	_finish_feed_success.call_deferred()


func _finish_feed_success() -> void:
	await anim_player.animation_finished

	if _is_feed_success_playing():
		return

	_refresh_interactible()

	if not is_sleeping:
		_change_health(2)
		last_feed_time = Time.get_unix_time_from_system()

	if is_dragging:
		return
	if is_sleeping:
		_enter_night_sleep_state()
		return
	if is_idle_napping:
		_enter_idle_nap_state()
		return

	is_hovering = _is_mouse_on_pet()

	if is_hovering and not _is_any_status_low() and not is_dinner_time:
		_play_anim("hover")
		return

	_enter_idle_state()
	_schedule_next_idle_variant()


func _finish_hand_interaction(animation_name: String, blocked_button: Button) -> void:
	await get_tree().create_timer(_get_hand_animation_duration(animation_name)).timeout

	hand_sprite.stop()
	hand_sprite.hide()
	is_hand_interaction_playing = false
	blocked_button.disabled = false
	if animation_name == "pet" and not is_sleeping:
		_change_mood(2)
		low_mood_acknowledged = true
		last_pet_time = Time.get_unix_time_from_system()
	_refresh_interactible()
	_refresh_base_anim_state()


func _get_hand_animation_duration(animation_name: String) -> float:
	var frames = hand_sprite.sprite_frames.get_frame_count(animation_name)
	var speed = hand_sprite.sprite_frames.get_animation_speed(animation_name)

	if speed <= 0.0:
		return 0.0

	return float(frames) / speed


func _update_stats_decay() -> void:
	if is_sleeping:
		return

	var now = Time.get_unix_time_from_system()

	while mood > STAT_MIN and now - last_pet_time >= STAT_DECAY_INTERVAL:
		last_pet_time += STAT_DECAY_INTERVAL
		_change_mood(-1)

	while health > STAT_MIN and now - last_feed_time >= STAT_DECAY_INTERVAL:
		last_feed_time += STAT_DECAY_INTERVAL
		_change_health(-1)


func _change_mood(amount: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(mood + amount, STAT_MIN, STAT_MAX)
	if next_value == mood:
		return

	if next_value < 2 and next_value < mood:
		low_mood_acknowledged = false
	elif next_value >= 2:
		low_mood_acknowledged = false

	mood = next_value
	_update_status_frames()
	_refresh_base_anim_state()


func _change_health(amount: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(health + amount, STAT_MIN, STAT_MAX)
	if next_value == health:
		return

	if next_value < 2 and next_value < health:
		low_health_acknowledged = false
	elif next_value >= 2:
		low_health_acknowledged = false

	health = next_value
	_update_status_frames()
	_refresh_base_anim_state()


func _set_mood(value: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(value, STAT_MIN, STAT_MAX)
	if next_value == mood:
		return

	if next_value < 2 and next_value < mood:
		low_mood_acknowledged = false
	elif next_value >= 2:
		low_mood_acknowledged = false

	mood = next_value
	_update_status_frames()
	_refresh_base_anim_state()


func _set_health(value: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(value, STAT_MIN, STAT_MAX)
	if next_value == health:
		return

	if next_value < 2 and next_value < health:
		low_health_acknowledged = false
	elif next_value >= 2:
		low_health_acknowledged = false

	health = next_value
	_update_status_frames()
	_refresh_base_anim_state()


func _update_status_frames() -> void:
	status_mood.frame = mood
	status_health.frame = health


func _update_timer_countdown() -> void:
	if not timer_window.visible or not timer_panel.visible or timer_end_time <= 0.0:
		return

	timer_seconds_remaining = maxi(0, int(ceil(timer_end_time - Time.get_unix_time_from_system())))
	_update_timer_label()

	if timer_seconds_remaining == 0:
		_finish_timer()


func _update_timer_label() -> void:
	var minutes = timer_seconds_remaining / 60
	var seconds = timer_seconds_remaining % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _position_timer_window_over_pet() -> void:
	timer_window.position = _get_timer_window_position(timer_window.size)


func _position_note_window() -> void:
	var timer_pos = timer_window.position
	if not timer_window.visible:
		timer_pos = _get_timer_window_position(timer_window.size)

	var usable_rect = DisplayServer.screen_get_usable_rect()
	var clamped_x = clampi(
		timer_pos.x,
		usable_rect.position.x,
		usable_rect.end.x - note_window.size.x
	)
	var clamped_y = clampi(
		timer_pos.y - note_window.size.y - NOTE_WINDOW_GAP,
		usable_rect.position.y,
		usable_rect.end.y - note_window.size.y
	)

	note_window.position = Vector2i(clamped_x, clamped_y)


func _position_tip_window() -> void:
	var timer_pos = timer_window.position
	var timer_size = timer_window.size
	if not timer_window.visible:
		timer_pos = _get_timer_window_position(timer_size)

	var usable_rect = DisplayServer.screen_get_usable_rect()
	var clamped_x = clampi(
		timer_pos.x,
		usable_rect.position.x,
		usable_rect.end.x - tip_window.size.x
	)
	var clamped_y = clampi(
		timer_pos.y + timer_size.y + NOTE_WINDOW_GAP -100,
		usable_rect.position.y,
		usable_rect.end.y - tip_window.size.y
	)

	tip_window.position = Vector2i(clamped_x, clamped_y)


func _reposition_popup_windows() -> void:
	if timer_window.visible:
		_position_timer_window_over_pet()

	if note_window.visible:
		_position_note_window()

	if tip_window.visible:
		_position_tip_window()


func _get_timer_window_position(popup_size: Vector2i) -> Vector2i:
	var usable_rect = DisplayServer.screen_get_usable_rect()
	var pet_center_screen = Vector2(get_window().position)

	var clamped_x = clampi(
		int(round(pet_center_screen.x + 50 * pet_scale - 150)),
		usable_rect.position.x,
		usable_rect.end.x - popup_size.x
	)
	var clamped_y = clampi(
		int(round(pet_center_screen.y - 50)),
		usable_rect.position.y,
		usable_rect.end.y - popup_size.y
	)

	return Vector2i(clamped_x, clamped_y)


func _finish_timer() -> void:
	timer_end_time = 0.0
	timer_seconds_remaining = 0
	_update_timer_label()
	_position_clock_over_pet()
	timer_panel.hide()
	button_clock.disabled = false
	clock_sprite.show()
	clock_sprite.play("timeup")
	_update_mouse_mask()


func _dismiss_clock_alarm() -> void:
	button_clock.disabled = true
	clock_sprite.hide()
	clock_sprite.stop()
	clock_sprite.play("idle")
	timer_window.hide()


func _position_clock_over_pet() -> void:
	_position_timer_window_over_pet()
	clock_sprite.position = Vector2(timer_window.size.x * 0.5, timer_window.size.y * 0.5)


func _is_mouse_on_clock() -> bool:
	if not clock_sprite.visible:
		return false

	var clock_texture = clock_sprite.sprite_frames.get_frame_texture(
		clock_sprite.animation,
		clock_sprite.frame
	)
	var clock_frame_size = clock_texture.get_size() * clock_sprite.scale
	var local_mouse = clock_sprite.to_local(get_global_mouse_position())
	var half_size = clock_frame_size * 0.5

	return (
		local_mouse.x >= -half_size.x
		and local_mouse.x <= half_size.x
		and local_mouse.y >= -half_size.y
		and local_mouse.y <= half_size.y
	)


func _start_drag() -> void:
	is_dragging = true
	is_hovering = true
	is_idle_variant_playing = false
	drag_velocity_x = 0.0
	last_mouse_global = Vector2(DisplayServer.mouse_get_position())
	_mark_mouse_active()
	idle_variant_timer.stop()
	_refresh_interactible()

	_play_interaction_variant_anim("click")
	drag_offset = Vector2(DisplayServer.mouse_get_position()) - Vector2(DisplayServer.window_get_position())

func _stop_drag() -> void:
	is_dragging = false
	_refresh_interactible()
	_update_hover_state()

	if is_sleeping:
		_enter_night_sleep_state()
	elif is_idle_napping:
		_enter_idle_nap_state()
	elif is_hovering and not _is_any_status_low() and not is_dinner_time:
		_play_anim("hover")
	else:
		_enter_idle_state()
		_schedule_next_idle_variant()

func IDLE():
	pass


func _schedule_next_idle_variant() -> void:
	if not _can_play_idle_variant():
		return

	is_idle_variant_playing = false
	idle_variant_timer.start(randf_range(IDLE_VARIANT_WAIT_MIN, IDLE_VARIANT_WAIT_MAX))


func _on_timer_idle_variant_timeout() -> void:
	if not _can_play_idle_variant():
		return

	if not is_idle_variant_playing:
		is_idle_variant_playing = true

		var candidates = IDLE_VARIANTS.duplicate()
		var current_anim = anim_player.current_animation

		if current_anim in candidates and candidates.size() > 1:
			candidates.erase(current_anim)

		var next_anim = candidates[randi() % candidates.size()]
		_play_anim(next_anim)

		idle_variant_timer.start(randf_range(IDLE_VARIANT_PLAY_MIN, IDLE_VARIANT_PLAY_MAX))
	else:
		_refresh_base_anim_state()
		_schedule_next_idle_variant()


func _can_play_idle_variant() -> bool:
	return not is_dragging and not is_hovering and not is_sleeping and not is_dinner_time and not is_idle_napping and not _is_feed_success_playing()


func SLEEP():
	pass


func _get_current_dinner_window() -> int:
	var dt = Time.get_datetime_dict_from_system()
	var minutes = int(dt.hour) * 60 + int(dt.minute)

	for index in range(DINNER_TIME.size()):
		var dinner_start = DINNER_TIME[index]
		var start_minutes = dinner_start.x * 60 + dinner_start.y
		var end_minutes = start_minutes + DINNER_DURATION_MINUTES
		if minutes >= start_minutes and minutes < end_minutes:
			return index

	return -1


func _get_dinner_key(dinner_window: int) -> String:
	if dinner_window == -1:
		return ""

	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d-%d" % [dt.year, dt.month, dt.day, dinner_window]


func _update_dinner_state() -> void:
	var next_dinner_window = _get_current_dinner_window()

	if next_dinner_window != -1:
		current_dinner_window = next_dinner_window
		current_dinner_key = _get_dinner_key(next_dinner_window)
		if not is_dinner_time:
			_enter_dinner_state()
		return

	if is_dinner_time:
		_exit_dinner_state()

	current_dinner_window = -1
	current_dinner_key = ""


func _enter_dinner_state() -> void:
	if is_sleeping:
		return

	is_dinner_time = true
	is_idle_napping = false
	is_idle_variant_playing = false
	is_hovering = false

	idle_variant_timer.stop()
	_refresh_interactible()

	if not is_dragging and not _is_feed_success_playing():
		_play_anim("dinner")


func _exit_dinner_state() -> void:
	var finished_dinner_key = current_dinner_key
	is_dinner_time = false
	_refresh_interactible()

	if not finished_dinner_key.is_empty() and rewarded_dinner_key != finished_dinner_key:
		rewarded_dinner_key = finished_dinner_key
		_set_health(STAT_MAX)
		last_feed_time = Time.get_unix_time_from_system()

	_refresh_base_anim_state()


func _is_night_sleep_time() -> bool:
	var dt = Time.get_datetime_dict_from_system()
	var hour = dt.hour
	return hour >= NIGHT_SLEEP_START_HOUR or hour < NIGHT_SLEEP_END_HOUR


func _update_sleep_state() -> void:
	var should_night_sleep = _is_night_sleep_time()
	var now = Time.get_unix_time_from_system()
	var inactive_seconds = now - last_mouse_move_time
	var should_idle_nap = inactive_seconds >= IDLE_SLEEP_DELAY

	if should_night_sleep:
		if not is_sleeping:
			_enter_night_sleep_state()
		return

	if is_sleeping and not should_night_sleep:
		_exit_night_sleep_state()

	if should_idle_nap and not is_idle_napping and not is_dragging and not _is_any_status_low() and not is_dinner_time:
		_enter_idle_nap_state()
	elif not should_idle_nap and is_idle_napping:
		_exit_idle_nap_state()


func _mark_mouse_active() -> void:
	last_mouse_move_time = Time.get_unix_time_from_system()

	if is_idle_napping and not is_sleeping and not is_dragging:
		_exit_idle_nap_state()


func _enter_night_sleep_state() -> void:
	is_sleeping = true
	is_dinner_time = false
	is_idle_napping = false
	is_idle_variant_playing = false
	is_hovering = false

	var now = Time.get_unix_time_from_system()
	last_pet_time = now
	last_feed_time = now
	idle_variant_timer.stop()
	_refresh_interactible()

	if anim_player.has_animation("sleep_enter"):
		_play_anim_with_transition("sleep")
	else:
		_play_anim("sleep")


func _exit_night_sleep_state() -> void:
	is_sleeping = false
	_set_mood(STAT_MAX, true)
	var now = Time.get_unix_time_from_system()
	last_pet_time = now
	last_feed_time = now
	_refresh_interactible()

	var inactive_seconds = Time.get_unix_time_from_system() - last_mouse_move_time

	if inactive_seconds >= IDLE_SLEEP_DELAY and not is_dinner_time:
		_enter_idle_nap_state()
	elif is_hovering and not _is_any_status_low() and not is_dinner_time:
		_play_anim("hover")
	else:
		_enter_idle_state()
		_schedule_next_idle_variant()


func _enter_idle_nap_state() -> void:
	if is_sleeping:
		return
	if is_dinner_time:
		_refresh_base_anim_state()
		return
	if _is_any_status_low():
		_refresh_base_anim_state()
		return

	is_idle_napping = true
	is_idle_variant_playing = false
	is_hovering = false

	idle_variant_timer.stop()
	_refresh_interactible()

	if anim_player.has_animation("idle_nap_enter"):
		_play_anim_with_transition("idle_nap")
	else:
		_play_anim("idle_nap")


func _exit_idle_nap_state() -> void:
	is_idle_napping = false
	_refresh_interactible()
	_update_hover_state()

	if is_hovering and not _is_any_status_low() and not is_dinner_time:
		_play_anim("hover")
	else:
		_enter_idle_state()
		_schedule_next_idle_variant()


func _enter_idle_state() -> void:
	if _is_feed_success_playing():
		return

	if not is_dragging and not is_sleeping and not is_idle_napping:
		if is_dinner_time:
			_play_anim("dinner")
			return
		if is_hovering and not _is_any_status_low():
			return
		var low_anim = _get_low_state_animation()
		if not low_anim.is_empty():
			_play_anim(low_anim)
		elif _is_any_status_low():
			return
		else:
			_play_anim("idle")


func _is_feed_success_playing() -> bool:
	return anim_player.is_playing() and anim_player.current_animation == "feed_success"


func _get_low_state_animation() -> String:
	if health < 2 and not low_health_acknowledged:
		return "low_health"
	if mood < 2 and not low_mood_acknowledged:
		return "low_mood"
	return ""


func _is_any_status_low() -> bool:
	return health < 2 or mood < 2


func _refresh_base_anim_state() -> void:
	if is_dinner_time:
		if not is_dragging and not is_sleeping and not _is_feed_success_playing():
			if is_idle_napping:
				is_idle_napping = false
				_refresh_interactible()
			_play_anim("dinner")
		return

	if is_dragging or is_hovering or is_sleeping or is_idle_napping:
		if is_idle_napping and _is_any_status_low() and not is_sleeping and not is_dragging:
			is_idle_napping = false
			_refresh_interactible()
		elif is_hovering and _is_any_status_low() and not is_sleeping and not is_dragging:
			pass
		else:
			return
	if is_hovering and not _is_any_status_low() and not is_dinner_time:
		return
	if is_idle_variant_playing:
		return
	if _is_feed_success_playing():
		return

	_enter_idle_state()
	_schedule_next_idle_variant()
