extends SceneTree

# Run with: godot --headless --path . --script res://tests/test_user_config.gd
# Most checks run outside the tree. The frame smoke substitutes display and
# persistence hooks, avoiding personal files and Windows startup registration.
const UserConfig = preload("res://scripts/UserConfig.gd")

class SmokeScene:
	extends "res://scripts/Scene.gd"
	var mouse_on_pet := false
	var right_click_count := 0
	var middle_click_count := 0
	func _setup_window() -> void:
		pass
	func _setup_notebook() -> void:
		pass
	func _load_config() -> void:
		pass
	func _save_config() -> void:
		pass
	func _save_note_text() -> void:
		pass
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
	func _is_mouse_on_pet() -> bool:
		return mouse_on_pet
	func _show_setting_window_at_mouse() -> void:
		right_click_count += 1
	func _show_random_tip() -> void:
		middle_click_count += 1

var checks := 0
var failures := 0
var fixture_path := "res://tests/.user_config_fixture_%d.json" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_numbers_and_booleans()
	_test_ranges_and_sizes()
	_test_schedules()
	_test_loader()
	_test_scene_integration()
	await _test_frame_smoke()
	if FileAccess.file_exists(fixture_path):
		_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path)) == OK, "remove temporary config fixture")
	print("User config: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _test_numbers_and_booleans() -> void:
	var config = UserConfig.new()
	_check(config.number({}, "value", 7.0) == 7.0, "missing numeric value uses default")
	_check(config.number({"value": 2}, "value", 7.0) == 2.0, "integer numeric value")
	_check(config.number({"value": 2.5}, "value", 7.0) == 2.5, "floating numeric value")
	_check(config.number({"value": -4}, "value", 7.0, 0.5, 3.0) == 0.5, "numeric minimum")
	_check(config.number({"value": 20}, "value", 7.0, 0.5, 3.0) == 3.0, "numeric maximum")
	_check(config.number({}, "value", 7.0, 0.5, 3.0) == 3.0, "numeric fallback respects bounds")
	for invalid in ["2", true, null, [], {}, INF, -INF, NAN]:
		_check(config.number({"value": invalid}, "value", 7.0) == 7.0, "invalid numeric value uses default: %s" % str(invalid))
	_check(config.boolean({}, "value", true), "missing boolean uses default")
	_check(config.boolean({"value": true}, "value", false), "JSON true enables a flag")
	_check(not config.boolean({"value": false}, "value", true), "JSON false disables a flag")
	for invalid in ["false", "true", 0, 1, null, [], {}]:
		_check(config.boolean({"value": invalid}, "value", true), "non-boolean flag uses default: %s" % str(invalid))


func _test_ranges_and_sizes() -> void:
	var config = UserConfig.new()
	var fallback := Vector2(60.0, 90.0)
	_check(config.range_value({}, "range", fallback) == fallback, "missing range uses default")
	_check(config.range_value({"range": null}, "range", fallback) == fallback, "null range uses default")
	_check(config.range_value({"range": [50, 100]}, "range", fallback) == Vector2(50, 100), "JSON array range")
	_check(config.range_value({"range": [100, 50]}, "range", fallback) == Vector2(50, 100), "reversed range is normalized")
	_check(config.range_value({"range": [-10, 3]}, "range", fallback, 1.0) == Vector2(1, 3), "range minimum is enforced")
	for invalid in ["[50, 100]", [], [1], [1, 2, 3], [1, "2"], [false, 2], [1, INF]]:
		_check(config.range_value({"range": invalid}, "range", fallback) == fallback, "invalid range uses default: %s" % str(invalid))
	var default_size := Vector2i(300, 80)
	_check(config.size_value({}, "size", default_size) == default_size, "missing size uses default")
	_check(config.size_value({"size": [120, 90]}, "size", default_size) == Vector2i(120, 90), "positive integer dimensions")
	_check(config.size_value({"size": [120.0, 90.0]}, "size", default_size) == Vector2i(120, 90), "JSON whole-number dimensions")
	for invalid in [null, [], [1], [1, 2, 3], [0, 90], [-1, 90], [1.5, 90], [true, 90], ["120", 90], [INF, 90], [2147483648.0, 90]]:
		_check(config.size_value({"size": invalid}, "size", default_size) == default_size, "invalid size uses default: %s" % str(invalid))


func _test_schedules() -> void:
	var config = UserConfig.new()
	var fallback := [[[12, 0], [12, 30]]]
	var windows := [[[23, 0], [8, 0]], [[12, 0], [12, 30]]]
	_check(config.time_windows({}, "windows", fallback) == fallback, "missing schedule uses default")
	_check(config.time_windows({"windows": windows}, "windows", fallback) == windows, "daytime and overnight schedules accepted")
	_check(config.time_windows({"windows": []}, "windows", fallback).is_empty(), "empty schedule disables its windows")
	var json_windows := [[[23.0, 0.0], [8.0, 0.0]]]
	_check(config.time_windows({"windows": json_windows}, "windows", fallback) == json_windows, "JSON whole-number clock values accepted")
	for invalid in [null, {}, "12:00", [[12, 0]], [[[12, 0]]], [[[24, 0], [8, 0]]], [[[23, 60], [8, 0]]], [[[-1, 0], [8, 0]]], [[[12.5, 0], [8, 0]]], [[[true, 0], [8, 0]]], [[["23", 0], [8, 0]]], [[[23, 0, 0], [8, 0]]]]:
		_check(config.time_windows({"windows": invalid}, "windows", fallback) == fallback, "invalid schedule uses default: %s" % str(invalid))


func _write_fixture(contents: String) -> bool:
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	_check(file != null, "create temporary config fixture")
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true


func _test_loader() -> void:
	var config = UserConfig.new()
	_check(config.load_file(), "bundled user config loads")
	_check(not config.settings.is_empty() and not config.animations.is_empty(), "bundled config contains settings and states")
	_check(config.animations_valid, "bundled config explicitly defines animations")
	_check(not config.load_file(fixture_path + ".missing"), "missing config reports failure")
	_check(config.settings.is_empty() and config.animations.is_empty(), "missing file clears previously loaded values")
	_check(not config.animations_valid, "missing file permits automatic fallback discovery")
	if not _write_fixture('{"settings":{"pet_scale":1.4},"animations":{"idle_work":{"type":"idle_variant","repeat_count":[50,100],"click_interactable":true}}}'):
		return
	_check(config.load_file(fixture_path), "valid object loads")
	_check(is_equal_approx(config.settings.get("pet_scale", 0.0), 1.4), "loader retains numeric settings")
	_check(config.range_value(config.state("idle_work"), "repeat_count", Vector2.ZERO) == Vector2(50, 100), "loader retains per-state repeat count")
	_check(config.boolean(config.state("idle_work"), "click_interactable", false), "loader retains real boolean")
	_check(config.state("missing_state").is_empty(), "missing state supplies empty defaults")
	if not _write_fixture('{"settings":'):
		return
	_check(not config.load_file(fixture_path), "malformed JSON reports failure")
	_check(config.settings.is_empty() and config.animations.is_empty(), "malformed JSON clears previously loaded values")
	if not _write_fixture('[]'):
		return
	_check(not config.load_file(fixture_path), "array root is rejected")
	if not _write_fixture('{"settings":{"pet_scale":1.6}}'):
		return
	_check(config.load_file(fixture_path), "partial config loads")
	_check(config.settings.get("pet_scale") == 1.6 and config.animations.is_empty(), "partial config defaults missing section")
	_check(not config.animations_valid, "omitted animations permit fallback discovery")
	if not _write_fixture('{"animations":{}}'):
		return
	_check(config.load_file(fixture_path) and config.animations_valid, "explicit empty animations can disable automatic variants")
	if not _write_fixture('{"settings":[],"animations":[]}'):
		return
	_check(config.load_file(fixture_path), "bad sections do not reject a valid JSON object")
	_check(config.settings.is_empty() and config.animations.is_empty(), "invalid section types use empty defaults")
	_check(not config.animations_valid, "invalid animation section permits fallback discovery")
	if not _write_fixture('{"animations":{"idle_work":false}}'):
		return
	_check(config.load_file(fixture_path), "individual bad state does not reject JSON object")
	_check(config.state("idle_work").is_empty(), "invalid state type uses empty defaults")


func _test_scene_integration() -> void:
	var packed_scene = load("res://map/Scene.tscn")
	_check(packed_scene is PackedScene, "main scene loads")
	if not packed_scene is PackedScene:
		return
	var scene = packed_scene.instantiate()
	scene.anim_player = scene.get_node("Milian/AnimationPlayer")
	scene.idle_variant_timer = scene.get_node("Timer_idle_variant")
	scene.body_node = scene.get_node("Milian/body")
	scene.face_marker = scene.get_node("Milian/body/face_marker")
	scene.face_sprite = scene.get_node("Milian/body/face_marker/face")
	scene.hand_sprite = scene.get_node("Milian/body/hand_marker/hand")
	scene.status_mood = scene.get_node("Milian/body/status_mood")
	scene.status_health = scene.get_node("Milian/body/status_health")
	scene.slider_pet_size = scene.get_node("Window_setting/Control/Window_setting/HSlider_pet_size")
	scene._load_user_config()
	_check(not scene.is_inside_tree(), "config inspection avoids application startup")
	_check(scene.idle_variant_wait.x > 0 and scene.idle_variant_wait.y >= scene.idle_variant_wait.x, "loaded idle wait is usable")
	for animation_name in scene.anim_player.get_animation_list():
		if animation_name == "RESET":
			continue
		var state: Dictionary = scene.user_config.state(animation_name)
		_check(not state.is_empty(), "bundled config describes state " + animation_name)
		for key in ["type", "click_interactable", "hover_interactable", "face_type", "face_anchor"]:
			_check(state.has(key), "%s has %s" % [animation_name, key])
		_check(scene.animation_face_anchors.has(animation_name), "face anchor resolves for " + animation_name)
	_test_variant_candidates_and_duration(scene)
	_test_state_interaction_and_face(scene)
	_test_clock_boundaries(scene)
	scene.free()


func _test_variant_candidates_and_duration(scene) -> void:
	scene.idle_variants.assign(["idle_work"])
	scene.last_idle_variant = "idle_work"
	_check(scene._get_idle_variant_candidates() == ["idle_work"], "single enabled variant can repeat")
	scene.idle_variants.assign(["idle_work", "idle_read"])
	_check(scene._get_idle_variant_candidates() == ["idle_read"], "multiple variants avoid immediate repetition")
	scene.idle_variants.clear()
	_check(scene._get_idle_variant_candidates().is_empty(), "disabled variants leave no candidates")
	_check(not scene._can_play_idle_variant(), "empty variant set does not schedule playback")
	scene.idle_variant_play = Vector2(17, 17)
	scene.user_config.animations = {"idle_work": {"repeat_count": null}}
	_check(scene._get_idle_variant_duration("idle_work") == 17.0, "null repeat count uses configured default seconds")
	scene.user_config.animations["idle_work"] = {"play_seconds": [7, 7]}
	_check(scene._get_idle_variant_duration("idle_work") == 7.0, "per-state seconds override default duration")
	scene.user_config.animations["idle_work"] = {"repeat_count": [3, 3], "play_seconds": [7, 7]}
	var cycle_seconds: float = scene.anim_player.get_animation("idle_work").length
	_check(is_equal_approx(scene._get_idle_variant_duration("idle_work"), cycle_seconds * 3), "repeat count takes precedence over seconds")
	scene.anim_player.speed_scale = 2.0
	_check(is_equal_approx(scene._get_idle_variant_duration("idle_work"), cycle_seconds * 1.5), "repeat duration accounts for playback speed")
	scene.anim_player.speed_scale = -2.0
	_check(is_equal_approx(scene._get_idle_variant_duration("idle_work"), cycle_seconds * 1.5), "reverse playback uses absolute speed")
	scene.anim_player.speed_scale = 1.0
	scene.user_config.animations["idle_work"] = {"repeat_count": [100, 50]}
	for index in range(12):
		var cycles: float = scene._get_idle_variant_duration("idle_work") / cycle_seconds
		_check(cycles >= 50 and cycles <= 100 and is_equal_approx(cycles, roundf(cycles)), "repeat range selects whole cycles within normalized bounds")
	scene.user_config.animations["idle_work"] = {"repeat_count": "[50,100]", "play_seconds": [9, 9]}
	_check(scene._get_idle_variant_duration("idle_work") == 9.0, "invalid repeat value falls back to seconds")


func _test_state_interaction_and_face(scene) -> void:
	scene.user_config.animations = {"idle_work": {"click_interactable": true, "hover_interactable": false}}
	scene.anim_player.play("idle_work")
	_check(scene._state_allows_interaction("click_interactable", false), "variant can explicitly enable click animation changes")
	_check(not scene._state_allows_interaction("hover_interactable", true), "variant can disable hover animation changes")
	scene.user_config.animations["idle_work"]["click_interactable"] = false
	_check(not scene._state_allows_interaction("click_interactable", true), "state can explicitly disable click animation changes")
	scene.user_config.animations.clear()
	_check(scene._state_allows_interaction("click_interactable", true), "missing state can retain enabled interaction fallback")
	_check(not scene._state_allows_interaction("click_interactable", false), "missing state can retain disabled interaction fallback")
	scene.active_face_anchor = scene.face_marker
	scene.face_marker.position = Vector2(7, 11)
	scene.face_sprite.frame = 4
	scene.active_animation_config = {"face_type": "custom"}
	scene._update_face()
	_check(scene.face_sprite.visible and scene.face_sprite.frame == 4, "custom face preserves authored expression")
	_check(scene.face_marker.position == Vector2(7, 11), "custom face preserves authored marker offset")
	scene.active_animation_config = {"face_type": "none"}
	scene._update_face()
	_check(not scene.face_sprite.visible, "none face hides the overlay")
	scene.active_animation_config = {"face_type": "neutral"}
	scene._update_face()
	_check(scene.face_sprite.visible and scene.face_sprite.frame == 0, "neutral face restores overlay with neutral expression")
	scene.active_animation_config = {"face_type": "blink"}
	scene._update_face()
	_check(scene.face_sprite.frame == 2, "blink face selects blink expression")


func _test_clock_boundaries(scene) -> void:
	var daytime := [[12, 0], [12, 30]]
	_check(not scene._is_in_time_window(11 * 60 + 59, daytime), "daytime window excludes time before start")
	_check(scene._is_in_time_window(12 * 60, daytime), "daytime window includes start")
	_check(scene._is_in_time_window(12 * 60 + 29, daytime), "daytime window includes final minute")
	_check(not scene._is_in_time_window(12 * 60 + 30, daytime), "daytime window excludes end")
	var overnight := [[23, 0], [8, 0]]
	_check(scene._is_in_time_window(23 * 60, overnight), "overnight window includes start")
	_check(scene._is_in_time_window(0, overnight), "overnight window spans midnight")
	_check(scene._is_in_time_window(7 * 60 + 59, overnight), "overnight window includes time before end")
	_check(not scene._is_in_time_window(8 * 60, overnight), "overnight window excludes end")
	_check(not scene._is_in_time_window(22 * 60 + 59, overnight), "overnight window excludes afternoon")
	_check(not scene._is_in_time_window(12 * 60, [[12, 0], [12, 0]]), "equal clock endpoints disable a window")


func _test_frame_smoke() -> void:
	var scene = load("res://map/Scene.tscn").instantiate()
	scene.set_script(SmokeScene)
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(scene.anim_player.current_animation == "idle", "ready enters idle with automatic node bindings")
	scene.idle_variant_timer.stop()
	scene.user_config.animations["idle_work"]["face_type"] = "neutral"
	scene.user_config.animations["idle_work"]["hover_interactable"] = false
	scene.is_idle_variant_playing = true
	scene._play_anim("idle_work")
	scene.anim_player.seek(0.56, true)
	_check(scene.face_sprite.frame == 2, "smoke reaches authored blink key before deferred override")
	await process_frame
	await process_frame
	_check(scene.face_sprite.frame == 0, "neutral override wins after animation tracks during frame")
	scene.mouse_on_pet = true
	scene._update_hover_state()
	_check(not scene.is_hovering and scene.is_idle_variant_playing, "disabled hover preserves running variant")
	scene.user_config.animations["idle_work"]["hover_interactable"] = true
	scene._update_hover_state()
	_check(scene.is_hovering and not scene.is_idle_variant_playing and scene.anim_player.current_animation == "hover", "enabled hover interrupts variant")
	scene.user_config.animations["hover"]["hover_interactable"] = false
	scene.mouse_on_pet = false
	scene._update_hover_state()
	_check(scene.is_hovering and scene.anim_player.current_animation == "hover", "disabled hover preserves the existing animation when pointer leaves")
	await _test_mouse_animation_controls(scene)
	scene.user_config.animations["feed_ignore"]["click_interactable"] = false
	scene.is_hand_interaction_playing = true
	scene.hand_sprite.animation = "feed_ignore"
	_check(not scene._state_allows_interaction("click_interactable", true), "active hand animation also controls click animation changes")
	scene.is_hand_interaction_playing = false
	scene.queue_free()
	await process_frame


func _test_mouse_animation_controls(scene) -> void:
	scene.is_hovering = false
	scene.is_idle_variant_playing = true
	scene.mouse_on_pet = true
	scene.user_config.animations["idle_work"]["click_interactable"] = false
	scene.user_config.animations["idle_work"]["hover_interactable"] = false
	scene._play_anim("idle_work")
	scene.idle_variant_timer.paused = false
	scene.idle_variant_timer.start(30.0)
	var remaining: float = scene.idle_variant_timer.time_left
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	scene._input(press)
	_check(scene.is_dragging and not scene.drag_changes_animation, "click-disabled state still starts a physical drag")
	_check(scene.anim_player.current_animation == "idle_work" and scene.is_idle_variant_playing and not scene.is_hovering, "passive drag preserves animation and variant/hover state")
	_check(scene.idle_variant_timer.paused and not scene.idle_variant_timer.is_stopped(), "passive drag pauses the existing variant timer")
	scene.drag_velocity_x = -1000.0
	scene._update_drag_tilt()
	_check(scene.anim_player.current_animation == "idle_work", "passive drag does not play tilt animation")
	scene.drag_velocity_x = 0.0
	scene._update_drag_tilt()
	_check(scene.anim_player.current_animation == "idle_work", "passive drag does not play click animation")
	scene.user_config.animations["idle_work"]["hover_interactable"] = true
	scene._update_hover_state()
	_check(scene.anim_player.current_animation == "idle_work" and not scene.is_hovering, "hover cannot replace the animation while dragging")
	await process_frame
	await process_frame
	_check(is_equal_approx(scene.idle_variant_timer.time_left, remaining), "variant timer retains its remaining duration during a passive drag")
	scene._input(release)
	_check(not scene.is_dragging and scene.anim_player.current_animation == "idle_work" and scene.is_idle_variant_playing, "passive release keeps the current animation and variant")
	_check(not scene.idle_variant_timer.paused and is_equal_approx(scene.idle_variant_timer.time_left, remaining), "passive release resumes the original timer without rescheduling")
	scene.user_config.animations["idle_work"]["hover_interactable"] = false
	scene.idle_variant_timer.paused = true
	scene._input(press)
	scene._input(release)
	_check(scene.idle_variant_timer.paused, "passive release preserves a timer that was already paused")
	scene.idle_variant_timer.paused = false

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	var middle_click := InputEventMouseButton.new()
	middle_click.button_index = MOUSE_BUTTON_MIDDLE
	middle_click.pressed = true
	scene._input(right_click)
	scene._input(middle_click)
	_check(scene.right_click_count == 1 and scene.middle_click_count == 1, "disabled animation flags still dispatch right and middle click actions")
	_check(scene.anim_player.current_animation == "idle_work", "right and middle clicks keep the protected animation")
	scene.is_interactible = false
	scene._refresh_interactible()
	_check(scene.is_interactible and not scene.button_pet.disabled and not scene.button_feed.disabled, "animation permission does not disable menu actions")

	scene.is_idle_variant_playing = false
	scene.is_hovering = false
	scene.user_config.animations["idle"]["click_interactable"] = true
	scene.user_config.animations["idle"]["hover_interactable"] = false
	scene.user_config.animations["click"]["click_interactable"] = false
	scene.user_config.animations["tilt_left_fast"]["click_interactable"] = false
	scene._play_anim("idle")
	scene._input(press)
	_check(scene.is_dragging and scene.drag_changes_animation and scene.anim_player.current_animation == "click", "enabled click flag plays click even when hover animation is disabled")
	scene.drag_velocity_x = -1000.0
	scene._update_drag_tilt()
	_check(scene.anim_player.current_animation == "tilt_left_fast", "reactive drag uses originating permission despite click state's disabled flag")
	scene.drag_velocity_x = 1000.0
	scene._update_drag_tilt()
	_check(scene.anim_player.current_animation == "tilt_right_fast", "reactive drag retains permission across tilt states")
	scene.mouse_on_pet = false
	scene._input(release)
	_check(not scene.is_dragging and not scene.is_hovering, "reactive drag release clears dragging and stale hover")
	_check(scene.anim_player.current_animation == "idle" and not scene.idle_variant_timer.is_stopped(), "reactive drag release restores idle scheduling")

	scene.user_config.animations["feed_success"]["click_interactable"] = false
	scene.mouse_on_pet = true
	scene._play_anim("feed_success")
	scene._input(press)
	_check(scene.is_dragging and not scene.drag_changes_animation, "one-shot animation also allows passive dragging")
	scene.anim_player.advance(scene.anim_player.get_animation("feed_success").length + 0.1)
	_check(not scene.anim_player.is_playing(), "one-shot animation finishes naturally during passive dragging")
	scene.mouse_on_pet = false
	scene._input(release)
	_check(not scene.is_dragging and scene.anim_player.is_playing() and scene.anim_player.current_animation == "idle", "passive release restores base state after natural animation completion")
