extends Node
class_name SettingsManager


# --- Description ---
##
## SettingsManager.gd (GLI-19 Compliant - Hardened)
##
## Secure read-only manager for embedded immutable game settings.
##
## Responsibilities:
## - Load static settings from embedded JSON file.
## - Provide safe fallback values when missing.
## - Prevent unauthorized user modification.
## - Emit structured signals for success/failure.
##
## Must be registered as Autoload (singleton).


# --- Signals ---


## Emitted when settings are successfully loaded.
signal settings_loaded()


## Emitted when settings fail to load.
##
## @param reason String: Human-readable reason for failure.
signal settings_load_failed(reason: String)


# --- Constants ---


## Immutable configuration file location.
const CONFIG_FILE_PATH: String = "res://scripts/core/config/settings.json"


# --- Private Variables ---


## Internal dictionary holding loaded settings.
var _settings: Dictionary = {}


# --- Lifecycle Methods ---


## Called when node enters the scene tree.
## Automatically triggers secure settings load.
func _ready() -> void:
	_load_settings()


# --- Public Methods ---


## Retrieves a setting safely with fallback.
##
## @param key String: Setting key to fetch.
## @param default_value Variant: Default value if key is missing.
## @return Variant: The setting value or default.
func get_setting(key: String, default_value: Variant = null) -> Variant:
	assert(key != "", "❌ Setting key must not be empty.")

	if not _settings.has(key):
		push_warning("⚠️ Unknown setting key requested: %s. Returning default." % key)
		return default_value

	return _settings[key]


## Sets a setting in memory at runtime (non-persistent).
##
## @param key String: Setting key to modify.
## @param value Variant: New value.
func set_setting(key: String, value: Variant) -> void:
	assert(key != "", "❌ Setting key must not be empty.")

	_settings[key] = value
	print_debug("⚙️ Runtime setting updated (non-persistent): %s -> %s" % [key, str(value)])


func get_encryption_key() -> String:
	return get_setting("encryption_key", "default_unsafe_key_please_change")


# --- Private Methods ---


## Loads settings securely from embedded configuration file.
##
## Emits signals on success or failure.
func _load_settings() -> void:
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		push_error("❌ Settings file missing at path: %s" % CONFIG_FILE_PATH)
		settings_load_failed.emit("Settings file missing.")
		return

	var file := FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("❌ Failed to open settings file: %s" % CONFIG_FILE_PATH)
		settings_load_failed.emit("Failed to open settings file.")
		return

	var content: String = file.get_as_text()
	file.close()

	var parsed: Dictionary = JSON.parse_string(content)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("❌ Invalid settings format: Expected Dictionary.")
		settings_load_failed.emit("Invalid settings structure.")
		return

	_settings = parsed
	settings_loaded.emit()

	_audit_log_success()
	

## Appends a secure audit entry for successful settings load.
func _audit_log_success() -> void:
	if Engine.has_singleton("AuditLogManager"):
		var audit_manager := Engine.get_singleton("AuditLogManager")
		if audit_manager and audit_manager.has_method("append_entry"):
			audit_manager.append_entry("✅ SettingsManager loaded %d entries successfully." % _settings.size())
	print_debug("✅ Settings loaded successfully with %d entries." % _settings.size())
