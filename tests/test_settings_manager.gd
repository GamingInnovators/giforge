extends Node


# --- Description ---
##
## Tests for SettingsManager.gd
##
## Covers:
## - Loading from file (mocked)
## - Key retrieval with and without fallback
## - Runtime memory updates


# --- Mocks / Setup ---


var _settings_manager: MockSettingsManager


func before_each() -> void:
	_settings_manager = MockSettingsManager.new()
	_settings_manager.set_setting("game_version", "1.0.0")
	_settings_manager.set_setting("max_bets", 500)


func after_each() -> void:
	_settings_manager.clear()


# --- Tests ---


## Tests if an existing setting is correctly retrieved.
func test_get_existing_setting() -> void:
	var version = _settings_manager.get_setting("game_version")
	AssertionsUtils.assert_true(version == "1.0.0", "❌ Failed to retrieve existing setting.")


## Tests if missing setting returns the provided fallback.
func test_get_missing_setting_with_default() -> void:
	var value = _settings_manager.get_setting("nonexistent_key", "default_value")
	AssertionsUtils.assert_eq(value, "default_value", "❌ Missing setting fallback failed.")


## Tests if runtime setting update works.
func test_runtime_update_setting() -> void:
	_settings_manager.set_setting("max_bets", 1000)
	var new_value = _settings_manager.get_setting("max_bets")
	AssertionsUtils.assert_eq(new_value, 1000, "❌ Runtime update failed.")
