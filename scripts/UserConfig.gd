extends RefCounted

var settings: Dictionary = {}
var animations: Dictionary = {}
var animations_valid := false
var _warned_keys: Dictionary = {}


func load_file(path: String = "res://assets/user_config.json") -> bool:
	settings = {}
	animations = {}
	animations_valid = false
	_warned_keys.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot read %s; using default pet settings." % path)
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Invalid JSON in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return false
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_warning("%s must contain a JSON object; using default pet settings." % path)
		return false

	var loaded_settings: Variant = parsed.get("settings", {})
	if loaded_settings is Dictionary:
		settings = loaded_settings
	else:
		_warn_invalid("settings")
	var loaded_animations: Variant = parsed.get("animations", {})
	if loaded_animations is Dictionary:
		animations = loaded_animations
		animations_valid = parsed.has("animations")
	else:
		_warn_invalid("animations")
	return true


func state(name: String) -> Dictionary:
	var value: Variant = animations.get(name, {})
	if value is Dictionary:
		return value
	_warn_invalid("animations.%s" % name)
	return {}


func number(section: Dictionary, key: String, fallback: float, minimum: float = -INF, maximum: float = INF) -> float:
	var default_value := clampf(fallback, minimum, maximum)
	if not section.has(key):
		return default_value
	var value: Variant = section[key]
	if not _is_number(value):
		_warn_invalid(key)
		return default_value
	return clampf(float(value), minimum, maximum)


func boolean(section: Dictionary, key: String, fallback: bool) -> bool:
	if not section.has(key):
		return fallback
	var value: Variant = section[key]
	if value is bool:
		return value
	_warn_invalid(key)
	return fallback


func range_value(section: Dictionary, key: String, fallback: Vector2, minimum: float = 0.0) -> Vector2:
	var value: Variant = section.get(key)
	if value == null:
		return fallback
	if not value is Array or value.size() != 2:
		_warn_invalid(key)
		return fallback
	if not _is_number(value[0]) or not _is_number(value[1]):
		_warn_invalid(key)
		return fallback
	var first := maxf(minimum, float(value[0]))
	var second := maxf(minimum, float(value[1]))
	return Vector2(minf(first, second), maxf(first, second))


func size_value(section: Dictionary, key: String, fallback: Vector2i) -> Vector2i:
	if not section.has(key):
		return fallback
	var value: Variant = section[key]
	if not value is Array or value.size() != 2:
		_warn_invalid(key)
		return fallback
	for component in value:
		if not _is_integer(component) or component < 1 or component > 2147483647:
			_warn_invalid(key)
			return fallback
	return Vector2i(int(value[0]), int(value[1]))


func time_windows(section: Dictionary, key: String, fallback: Array) -> Array:
	if not section.has(key):
		return fallback
	var value: Variant = section[key]
	if not value is Array:
		_warn_invalid(key)
		return fallback
	for window in value:
		if not window is Array or window.size() != 2:
			_warn_invalid(key)
			return fallback
		for clock_time in window:
			if not clock_time is Array or clock_time.size() != 2:
				_warn_invalid(key)
				return fallback
			if not _is_integer(clock_time[0]) or not _is_integer(clock_time[1]):
				_warn_invalid(key)
				return fallback
			if clock_time[0] < 0 or clock_time[0] > 23 or clock_time[1] < 0 or clock_time[1] > 59:
				_warn_invalid(key)
				return fallback
	return value


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _is_integer(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))


func _warn_invalid(key: String) -> void:
	if _warned_keys.has(key):
		return
	_warned_keys[key] = true
	push_warning("user_config.json: invalid value for '%s'; using the default." % key)
