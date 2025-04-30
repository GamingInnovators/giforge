extends Node
class_name EnvironmentManager


# --- Description ---
##
## EnvironmentManager.gd
##
## Enables dynamic environment selection (dev/staging/prod) at runtime.
## Supports configuration override using secondary JSON files.
## Can be injected before initializing SettingsManager.
##
## Usage:
## var env := EnvironmentManager.new()
## env.set_environment("staging")
## env.override_config("upload_url", "https://staging.api/upload")
## env.apply()


# --- Constants ---


const BASE_PATH := "res://scripts/core/config/"
const DEFAULT_ENVIRONMENT := "prod"
const DEFAULT_FILENAME := "settings.json"


# --- Private Variables ---


var _active_environment := DEFAULT_ENVIRONMENT
var _overrides: Dictionary = {}


# --- Public Methods ---


## Sets the active environment manually (dev, staging, prod)
func set_environment(env: String) -> void:
	assert(env in ["dev", "staging", "prod"], "❌ Invalid environment.")
	_active_environment = env


## Overrides a setting key in-memory before applying
func override_config(key: String, value: Variant) -> void:
	_overrides[key] = value


## Applies the selected environment and writes merged settings to SettingsManager's expected path.
func apply() -> void:
	var env_file := BASE_PATH + "settings_" + _active_environment + ".json"
	if not FileAccess.file_exists(env_file):
		push_error("❌ Missing environment config: %s" % env_file)
		return

	var file := FileAccess.open(env_file, FileAccess.READ)
	if file == null:
		push_error("❌ Cannot open config for env: %s" % _active_environment)
		return

	var base_config: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(base_config) != TYPE_DICTIONARY:
		push_error("❌ Invalid config format in: %s" % env_file)
		return

	# Apply overrides
	for key in _overrides.keys():
		base_config[key] = _overrides[key]

	# Write to the default path used by SettingsManager
	var out := FileAccess.open(BASE_PATH + DEFAULT_FILENAME, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(base_config, "\t"))
		out.close()
		print("✅ Environment [%s] applied with overrides." % _active_environment)
	else:
		push_error("❌ Failed to write merged config to settings.json")
