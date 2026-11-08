extends Node2D

const UserConfig = preload("res://scripts/UserConfig.gd")
const NOTEBOOK_DIR := "user://data"
const NOTEBOOK_PATH := "user://data/notebook.txt"
const CONFIG_PATH := "user://data/config.txt"
const TIPS_PATH := "res://data/tips.txt"
const STARTUP_ENTRY_NAME := "MLDeskPetStartup.cmd"
const TRAY_MENU_ID_TOGGLE_VISIBILITY := 1
const TRAY_MENU_ID_QUIT := 2


# These defaults also keep the pet usable when a config entry is missing or invalid.
var user_config = UserConfig.new()
var idle_variants: Array[String] = []
var idle_variant_wait := Vector2(60.0, 90.0)
var idle_variant_play := Vector2(180.0, 360.0)
var idle_sleep_delay := 600.0
var sleep_time_windows: Array = [[[23, 0], [8, 0]]]
var dinner_time_windows: Array = [[[12, 0], [12, 30]], [[18, 30], [19, 0]]]
var tilt_deadzone := 300.0
var tilt_fast_threshold := 600.0
var stat_min := 0
var stat_max := 3
var stat_low_threshold := 2
var stat_decay_interval := 3600.0
var note_window_gap := 0
var base_pet_window_size := Vector2i(100, 100)
var base_timer_window_size := Vector2i(300, 80)
var base_note_window_size := Vector2i(300, 200)
var note_save_delay := 0.5
var setting_window_leave_grace_seconds := 0.5
var animation_face_anchors: Dictionary = {}
var active_animation_config: Dictionary = {}
var active_face_anchor: Node2D

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
var drag_changes_animation := false
var drag_idle_timer_was_paused := false
var is_hovering = false

var is_sleeping = false
var is_dinner_time = false
var is_idle_napping = false
var is_idle_variant_playing = false
var last_idle_variant := ""
var is_hand_interaction_playing = false
var is_interactible := true
var mood := 3
var health := 3
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
@onready var face_marker: Marker2D = $Milian/body/face_marker
@onready var face_sprite: AnimatedSprite2D = $Milian/body/face_marker/face
@onready var hand_sprite: AnimatedSprite2D = $Milian/body/hand_marker/hand
@onready var status_mood: AnimatedSprite2D = $Milian/body/status_mood
@onready var status_health: AnimatedSprite2D = $Milian/body/status_health
@onready var setting_window: Window = $Window_setting
@onready var setting_ui: Control = $Window_setting/Control
@onready var timer_window: Window = $Window_timer
@onready var timer_panel: Sprite2D = $Window_timer/Window_timer
@onready var timer_label: Label = $Window_timer/Window_timer/Panel/TimerLabel
@onready var button_close_timer: TextureButton = $Window_timer/Button_close
@onready var button_clock: Button = $Window_timer/Button_clock
@onready var clock_sprite: AnimatedSprite2D = $Window_timer/Clock
@onready var note_window: Window = $Window_note
@onready var note_panel: Sprite2D = $Window_note/Window_note
@onready var note_input: TextEdit = $Window_note/Window_note/TextEdit
@onready var button_close_note: TextureButton = $Window_note/Button_close
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
	_load_user_config()
	_setup_window()
	_setup_setting_window()
	_setup_notebook()
	_setup_tips()
	_load_config()
	_apply_scale()
	_restore_saved_pet_position()
	_setup_system_tray()
	_connect_signals()
	anim_player.animation_started.connect(_on_animation_started)

	await get_tree().process_frame
	_update_mouse_mask()

	var now = Time.get_unix_time_from_system()
	last_mouse_move_time = now
	last_pet_time = now
	last_feed_time = now
	_update_status_frames()
	_enter_idle_state()
	_schedule_next_idle_variant()
	

func _load_user_config() -> void:
	user_config.load_file()
	var settings: Dictionary = user_config.settings
	pet_scale = user_config.number(settings, "pet_scale", pet_scale, slider_pet_size.min_value, slider_pet_size.max_value)
	window_scale = user_config.number(settings, "window_scale", window_scale, 0.1)
	clock_size = user_config.number(settings, "clock_size", clock_size, 0.1)
	startup_enabled = user_config.boolean(settings, "startup_enabled", startup_enabled)
	tilt_deadzone = user_config.number(settings, "tilt_deadzone", tilt_deadzone, 0.0)
	tilt_fast_threshold = user_config.number(settings, "tilt_fast_threshold", tilt_fast_threshold, tilt_deadzone)
	# Status frames are supplied by the sprite sheet, so configured bounds must fit it.
	var last_status_frame = mini(status_mood.sprite_frames.get_frame_count(status_mood.animation), status_health.sprite_frames.get_frame_count(status_health.animation)) - 1
	stat_min = int(user_config.number(settings, "stat_min", stat_min, 0, last_status_frame))
	stat_max = int(user_config.number(settings, "stat_max", stat_max, stat_min, last_status_frame))
	stat_low_threshold = int(user_config.number(settings, "stat_low_threshold", stat_low_threshold, stat_min, stat_max))
	stat_decay_interval = user_config.number(settings, "stat_decay_interval_seconds", stat_decay_interval, 0.1)
	mood = int(user_config.number(settings, "initial_mood", mood, stat_min, stat_max))
	health = int(user_config.number(settings, "initial_health", health, stat_min, stat_max))
	note_window_gap = int(user_config.number(settings, "note_window_gap", note_window_gap))
	base_pet_window_size = user_config.size_value(settings, "pet_window_size", base_pet_window_size)
	base_timer_window_size = user_config.size_value(settings, "timer_window_size", base_timer_window_size)
	base_note_window_size = user_config.size_value(settings, "note_window_size", base_note_window_size)
	note_save_delay = user_config.number(settings, "note_save_delay_seconds", note_save_delay, 0.01)
	tips_show_time = user_config.number(settings, "tips_show_seconds", tips_show_time, 0.01)
	setting_window_leave_grace_seconds = user_config.number(settings, "setting_window_leave_grace_seconds", setting_window_leave_grace_seconds, 0.0)
	var idle_config: Dictionary = user_config.state("idle")
	idle_variant_wait = user_config.range_value(idle_config, "variant_wait_seconds", idle_variant_wait, 0.01)
	idle_variant_play = user_config.range_value(idle_config, "variant_play_seconds", idle_variant_play, 0.01)
	idle_sleep_delay = user_config.number(user_config.state("idle_nap"), "inactivity_seconds", idle_sleep_delay, 0.0)
	var sleep_config: Dictionary = user_config.state("sleep")
	sleep_time_windows = user_config.time_windows({"windows": [sleep_config.get("time_window", sleep_time_windows[0])]}, "windows", sleep_time_windows)
	dinner_time_windows = user_config.time_windows(user_config.state("dinner"), "time_windows", dinner_time_windows)

	idle_variants.clear()
	animation_face_anchors.clear()
	var animation_names = Array(anim_player.get_animation_list())
	animation_names.append_array(hand_sprite.sprite_frames.get_animation_names())
	for animation_name in animation_names:
		if animation_name == "RESET":
			continue
		var config: Dictionary = user_config.state(animation_name)
		if config.get("type", "") == "idle_variant" and user_config.boolean(config, "enabled", true):
			idle_variants.append(animation_name)
		var anchor_name = config.get("face_anchor", "face")
		var anchor: Node2D = face_marker
		if anchor_name is String and anchor_name != "face":
			var anchor_path = anchor_name
			if body_node.has_node(anchor_name + "_marker"):
				anchor_path = anchor_name + "_marker"
			var configured_anchor = body_node.get_node_or_null(anchor_path)
			if configured_anchor is Node2D and configured_anchor != face_sprite and not face_sprite.is_ancestor_of(configured_anchor):
				anchor = configured_anchor
			else:
				push_warning("Unknown face anchor '%s' for %s; using face." % [anchor_name, animation_name])
		animation_face_anchors[animation_name] = anchor
	# Missing or malformed animation settings keep the existing animation set.
	if not user_config.animations_valid:
		for animation_name in anim_player.get_animation_list():
			if animation_name.begins_with("idle_") and animation_name != "idle_nap" and not animation_name.ends_with("_enter"):
				idle_variants.append(animation_name)


func _on_animation_started(animation_name: StringName) -> void:
	if is_hand_interaction_playing:
		animation_name = hand_sprite.animation
	active_animation_config = user_config.state(animation_name)
	active_face_anchor = animation_face_anchors.get(animation_name, face_marker)
	_update_face()


func _update_face() -> void:
	var face_type = active_animation_config.get("face_type", "custom")
	face_sprite.visible = face_type != "none"
	if not face_sprite.visible:
		return
	if active_face_anchor == null or active_face_anchor == face_marker:
		face_sprite.position = Vector2.ZERO
	else:
		face_sprite.global_position = active_face_anchor.global_position
	if face_type == "neutral":
		face_sprite.frame = 0
	elif face_type == "blink":
		face_sprite.frame = mini(2, face_sprite.sprite_frames.get_frame_count(face_sprite.animation) - 1)


func _state_allows_interaction(key: String, fallback: bool = true) -> bool:
	if not user_config.boolean(user_config.state(anim_player.current_animation), key, fallback):
		return false
	return not is_hand_interaction_playing or user_config.boolean(user_config.state(hand_sprite.animation), key, true)


func _setup_window() -> void:
	var window = get_window()

	get_viewport().transparent_bg = true
	window.transparent = true
	window.borderless = true
	window.always_on_top = true
	window.unresizable = false

	window.size = Vector2i(Vector2(base_pet_window_size) * pet_scale)

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
	note_save_timer.wait_time = note_save_delay
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
	window.size = Vector2i(Vector2(base_pet_window_size) * pet_scale)
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
	timer_window.size = Vector2i(Vector2(base_timer_window_size) * window_scale)
	note_window.size = Vector2i(Vector2(base_note_window_size) * window_scale)
	tip_window.size = Vector2i(Vector2(base_note_window_size) * window_scale)
	_layout_popup_windows()


func _layout_popup_windows() -> void:
	var scale_vec = Vector2(window_scale, window_scale)
	var timer_background: Control = timer_panel.get_node("Panel")
	timer_background.scale = Vector2.ONE
	timer_background.size = Vector2(timer_window.size) / window_scale
	button_clock.scale = Vector2.ONE
	button_clock.size = Vector2(timer_window.size)
	note_input.position = Vector2.ZERO
	note_input.size = Vector2(note_window.size) / window_scale
	for popup_window in [timer_window, note_window]:
		var close_button: TextureButton = popup_window.get_node("Button_close")
		close_button.scale = scale_vec
		close_button.position = Vector2(popup_window.size.x - 24.0 * window_scale, 4.0 * window_scale)


func _connect_signals() -> void:
	if not button_close_timer.pressed.is_connected(_close_timer_window):
		button_close_timer.pressed.connect(_close_timer_window)
	if not button_close_note.pressed.is_connected(_hide_note_window):
		button_close_note.pressed.connect(_hide_note_window)
	if not timer_window.close_requested.is_connected(_close_timer_window):
		timer_window.close_requested.connect(_close_timer_window)
	if not note_window.close_requested.is_connected(_hide_note_window):
		note_window.close_requested.connect(_hide_note_window)
	for popup_window in [timer_window, note_window]:
		if not popup_window.size_changed.is_connected(_layout_popup_windows):
			popup_window.size_changed.connect(_layout_popup_windows)
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
	# Apply face overrides after AnimationPlayer has evaluated its authored tracks.
	_update_face.call_deferred()
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
	if is_dragging:
		return
	if not _state_allows_interaction("hover_interactable", not (is_dinner_time or is_idle_variant_playing or _is_feed_success_playing())):
		return

	var hover_now = _is_mouse_on_pet()

	if hover_now == is_hovering:
		return

	is_hovering = hover_now

	if is_sleeping or is_idle_napping:
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
	if not is_dragging or not drag_changes_animation:
		return

	if abs(drag_velocity_x) <= tilt_deadzone:
		_play_interaction_variant_anim("click")
		return

	if drag_velocity_x < 0.0:
		if abs(drag_velocity_x) >= tilt_fast_threshold:
			_play_interaction_variant_anim("tilt_left_fast")
		else:
			_play_interaction_variant_anim("tilt_left_slow")
	else:
		if abs(drag_velocity_x) >= tilt_fast_threshold:
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

	if Time.get_unix_time_from_system() - setting_window_open_time < setting_window_leave_grace_seconds:
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
	_on_animation_started(anim_player.current_animation)
	hand_sprite.frame = 0
	hand_sprite.show()
	hand_sprite.play(animation_name)
	_update_menu_buttons()
	_finish_hand_interaction.call_deferred(animation_name, blocked_button)


func _play_feed_success() -> void:
	if not anim_player.has_animation("feed_success"):
		return

	low_health_acknowledged = true
	_play_anim("feed_success")
	_refresh_interactible()
	_finish_feed_success.call_deferred()


func _finish_feed_success() -> void:
	await anim_player.animation_finished

	if _is_feed_success_playing():
		return

	_refresh_interactible()

	if not is_sleeping:
		_change_health(int(user_config.number(user_config.state("feed_success"), "health_gain", 3, 0)))
		last_feed_time = Time.get_unix_time_from_system()

	if is_dragging:
		return
	if is_sleeping:
		_enter_night_sleep_state()
		return
	if is_idle_napping:
		_enter_idle_nap_state()
		return

	is_hovering = false
	_enter_idle_state()
	_update_hover_state()
	_schedule_next_idle_variant()


func _finish_hand_interaction(animation_name: String, blocked_button: Button) -> void:
	await get_tree().create_timer(_get_hand_animation_duration(animation_name)).timeout

	hand_sprite.stop()
	hand_sprite.hide()
	is_hand_interaction_playing = false
	_on_animation_started(anim_player.current_animation)
	blocked_button.disabled = false
	if animation_name == "pet" and not is_sleeping:
		_change_mood(int(user_config.number(user_config.state("pet"), "mood_gain", 3, 0)))
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

	while mood > stat_min and now - last_pet_time >= stat_decay_interval:
		last_pet_time += stat_decay_interval
		_change_mood(-1)

	while health > stat_min and now - last_feed_time >= stat_decay_interval:
		last_feed_time += stat_decay_interval
		_change_health(-1)


func _change_mood(amount: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(mood + amount, stat_min, stat_max)
	if next_value == mood:
		return

	if next_value < stat_low_threshold and next_value < mood:
		low_mood_acknowledged = false
	elif next_value >= stat_low_threshold:
		low_mood_acknowledged = false

	mood = next_value
	_update_status_frames()
	_refresh_base_anim_state()


func _change_health(amount: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(health + amount, stat_min, stat_max)
	if next_value == health:
		return

	if next_value < stat_low_threshold and next_value < health:
		low_health_acknowledged = false
	elif next_value >= stat_low_threshold:
		low_health_acknowledged = false

	health = next_value
	_update_status_frames()
	_refresh_base_anim_state()


func _set_mood(value: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(value, stat_min, stat_max)
	if next_value == mood:
		return

	if next_value < stat_low_threshold and next_value < mood:
		low_mood_acknowledged = false
	elif next_value >= stat_low_threshold:
		low_mood_acknowledged = false

	mood = next_value
	_update_status_frames()
	_refresh_base_anim_state()


func _set_health(value: int, allow_while_sleeping: bool = false) -> void:
	if is_sleeping and not allow_while_sleeping:
		return

	var next_value = clampi(value, stat_min, stat_max)
	if next_value == health:
		return

	if next_value < stat_low_threshold and next_value < health:
		low_health_acknowledged = false
	elif next_value >= stat_low_threshold:
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
		timer_pos.y - note_window.size.y - note_window_gap,
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
		timer_pos.y + timer_size.y + note_window_gap -100,
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
	_close_timer_window()


func _close_timer_window() -> void:
	timer_end_time = 0.0
	timer_seconds_remaining = 0
	_update_timer_label()
	button_clock.disabled = true
	clock_sprite.hide()
	clock_sprite.stop()
	clock_sprite.frame = 0
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
	# Mouse actions always work; this flag only controls the drag's visual reaction.
	drag_changes_animation = _state_allows_interaction("click_interactable", not is_idle_variant_playing)
	drag_idle_timer_was_paused = idle_variant_timer.paused
	is_dragging = true
	drag_velocity_x = 0.0
	last_mouse_global = Vector2(DisplayServer.mouse_get_position())
	_mark_mouse_active()
	if drag_changes_animation:
		is_hovering = true
		is_idle_variant_playing = false
		idle_variant_timer.stop()
		_play_interaction_variant_anim("click")
	else:
		# Keep the existing animation and resume its remaining duration after dragging.
		idle_variant_timer.paused = true

	_refresh_interactible()
	drag_offset = Vector2(DisplayServer.mouse_get_position()) - Vector2(DisplayServer.window_get_position())

func _stop_drag() -> void:
	is_dragging = false
	if not drag_changes_animation:
		idle_variant_timer.paused = drag_idle_timer_was_paused
		# A one-shot animation may have finished naturally while it was carried.
		if not anim_player.is_playing():
			is_hovering = false
			_refresh_base_anim_state()
			_update_hover_state()
		_refresh_interactible()
		return
	drag_changes_animation = false
	is_hovering = false

	if is_sleeping:
		_enter_night_sleep_state()
	elif is_idle_napping:
		_enter_idle_nap_state()
	else:
		_enter_idle_state()
		_update_hover_state()
		_schedule_next_idle_variant()
	_refresh_interactible()

func IDLE():
	pass


func _schedule_next_idle_variant() -> void:
	if not _can_play_idle_variant():
		return

	is_idle_variant_playing = false
	idle_variant_timer.start(randf_range(idle_variant_wait.x, idle_variant_wait.y))


func _get_idle_variant_candidates() -> Array[String]:
	var candidates: Array[String] = idle_variants.duplicate()
	if candidates.size() > 1:
		candidates.erase(last_idle_variant)
	return candidates


func _get_idle_variant_duration(animation_name: String) -> float:
	var config: Dictionary = user_config.state(animation_name)
	if config.get("repeat_count") != null:
		var repeats: Vector2 = user_config.range_value(config, "repeat_count", Vector2.ZERO, 1.0)
		if repeats != Vector2.ZERO:
			var count = randi_range(int(ceil(repeats.x)), maxi(int(ceil(repeats.x)), int(floor(repeats.y))))
			var animation = anim_player.get_animation(animation_name)
			return maxf(0.01, animation.length * count / maxf(absf(anim_player.speed_scale), 0.001))
	var play_seconds: Vector2 = user_config.range_value(config, "play_seconds", idle_variant_play, 0.01)
	return randf_range(play_seconds.x, play_seconds.y)


func _on_timer_idle_variant_timeout() -> void:
	if not _can_play_idle_variant():
		return

	if not is_idle_variant_playing:
		var candidates = _get_idle_variant_candidates()
		if candidates.is_empty():
			return

		var next_anim = candidates[randi() % candidates.size()]
		is_idle_variant_playing = true
		last_idle_variant = next_anim
		_play_anim(next_anim)

		idle_variant_timer.start(_get_idle_variant_duration(next_anim))
	else:
		is_idle_variant_playing = false
		# Hover may have changed while this variant disabled hover reactions.
		is_hovering = false
		_enter_idle_state()
		_update_hover_state()
		_refresh_base_anim_state()


func _can_play_idle_variant() -> bool:
	return not idle_variants.is_empty() and not is_dragging and not is_hovering and not is_sleeping and not is_dinner_time and not is_idle_napping and not _is_feed_success_playing()


func SLEEP():
	pass


func _get_current_dinner_window() -> int:
	var dt = Time.get_datetime_dict_from_system()
	var minutes = int(dt.hour) * 60 + int(dt.minute)

	for index in range(dinner_time_windows.size()):
		if _is_in_time_window(minutes, dinner_time_windows[index]):
			return index

	return -1


func _is_in_time_window(minutes: int, time_window: Array) -> bool:
	var start_minutes = int(time_window[0][0]) * 60 + int(time_window[0][1])
	var end_minutes = int(time_window[1][0]) * 60 + int(time_window[1][1])
	if start_minutes < end_minutes:
		return minutes >= start_minutes and minutes < end_minutes
	if start_minutes > end_minutes:
		return minutes >= start_minutes or minutes < end_minutes
	return false


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
		_set_health(stat_max)
		last_feed_time = Time.get_unix_time_from_system()

	_refresh_base_anim_state()


func _is_night_sleep_time() -> bool:
	var dt = Time.get_datetime_dict_from_system()
	var minutes = int(dt.hour) * 60 + int(dt.minute)
	for time_window in sleep_time_windows:
		if _is_in_time_window(minutes, time_window):
			return true
	return false


func _update_sleep_state() -> void:
	var should_night_sleep = _is_night_sleep_time()
	var now = Time.get_unix_time_from_system()
	var inactive_seconds = now - last_mouse_move_time
	var should_idle_nap = inactive_seconds >= idle_sleep_delay

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
	_set_mood(stat_max, true)
	var now = Time.get_unix_time_from_system()
	last_pet_time = now
	last_feed_time = now
	_refresh_interactible()

	var inactive_seconds = Time.get_unix_time_from_system() - last_mouse_move_time

	if inactive_seconds >= idle_sleep_delay and not is_dinner_time:
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
	if health < stat_low_threshold and not low_health_acknowledged:
		return "low_health"
	if mood < stat_low_threshold and not low_mood_acknowledged:
		return "low_mood"
	return ""


func _is_any_status_low() -> bool:
	return health < stat_low_threshold or mood < stat_low_threshold


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
