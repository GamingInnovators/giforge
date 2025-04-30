extends Node
class_name MockSettingsManager


# --- Description ---
##
## MockSettingsManager.gd
##
## Simulates SettingsManager behavior for isolated tests.
##
## Features:
## - Memory-only configuration
## - No file loading
## - Fully isolated from filesystem


# --- Private Variables ---


var _mock_settings: Dictionary = {}


# --- Public Methods ---


## Retrieves a mocked setting by key, with fallback.
##
## @param key String: Key name.
## @param default_value Variant: Fallback if key missing.
## @return Variant: Value or fallback.
func get_setting(key: String, default_value: Variant = null) -> Variant:
	if _mock_settings.has(key):
		return _mock_settings[key]
	return default_value


## Sets a mock setting in memory.
##
## @param key String: Key name.
## @param value Variant: New value.
func set_setting(key: String, value: Variant) -> void:
	_mock_settings[key] = value


## Clears all mock settings.
func clear() -> void:
	_mock_settings.clear()
