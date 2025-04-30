extends Node
class_name SystemBootstrap


# --- Description ---
##
## SystemBootstrap.gd (GLI-19 Compliant)
##
## Responsible for secure startup validation of critical configuration files and paths.
## Ensures:
## - Directory preparation
## - Signature check for settings.json
## - Optional schema validation (XSD)
##
## Must be registered as Autoload (singleton).
##


# --- Dependencies ---


@onready var _audit_log_manager := get_node_or_null("/root/AuditLogManager")
@onready var _settings_manager := get_node_or_null("/root/SettingsManager")


# --- Constants ---


const SETTINGS_PATH := "res://scripts/core/config/settings.json"
const SETTINGS_SIG := SETTINGS_PATH + ".sig"
const SETTINGS_XSD := "res://scripts/core/config/settings.xml"
const SETTINGS_SCHEMA := "res://scripts/core/config/settings.xsd"

const REQUIRED_DIRECTORIES := [
	"user://system/", "user://audit_logs/", "user://exports/",
	"user://saves/", "user://metadata/", "user://receipts/",
	"user://uploaded/", "user://manifest/", "user://backups/", "user://config/"
]


# --- Lifecycle ---


func _ready() -> void:
	_validate_dependencies()
	_ensure_required_directories()
	_validate_settings_signature()
	_validate_schema_xsd()


# --- Public Methods ---


## Allows factory/system reinitialization for testing/debugging.
func reinitialize() -> void:
	_ensure_required_directories()
	_validate_settings_signature()
	_validate_schema_xsd()
	_audit("System reinitialized.")


## Validates the RNG state file and its signature.
##
## Ensures RNG file wasn't tampered and exists properly.
func check_rng_state_file() -> void:
	var path = _settings_manager.get_setting("rng_state_file", "user://rng_state.dat")
	if not FileAccess.file_exists(path):
		push_error("❌ RNG state file missing: %s" % path)
		return

	if not IntegrityChecker.validate_file_signature(path):
		push_error("❌ RNG state signature mismatch: %s" % path)
	else:
		_audit("✅ RNG state file signature OK: %s" % path)


# --- Private Methods ---


func _validate_dependencies() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is missing.")
	assert(_settings_manager != null, "❌ SettingsManager is missing.")


## Ensures critical system directories exist.
func _ensure_required_directories() -> void:
	for dir_path in REQUIRED_DIRECTORIES:
		DirAccess.make_dir_recursive_absolute(dir_path)
	_audit("System directories validated.")


## Validates the digital signature of settings.json file.
func _validate_settings_signature() -> void:
	if not FileAccess.file_exists(SETTINGS_SIG):
		push_warning("⚠️ Signature file missing for settings.json.")
		return

	var is_valid := IntegrityChecker.validate_file_signature(SETTINGS_PATH)
	if not is_valid:
		push_error("❌ settings.json signature mismatch. Build may be tampered.")
	else:
		_audit("✅ settings.json signature validated.")


## Validates the digital signature of all known critical configuration files.
##
## @note Useful to audit settings, manifests, receipts and metadata in one pass.
func validate_all_critical_signatures() -> void:
	var critical_paths := [
		"res://scripts/core/config/settings.json",
		"user://manifest/manifest.json",
		"user://receipts/receipt_%s.json" % _get_session_id_safe(),
		"user://metadata/metadata_%s.json" % _get_session_id_safe(),
		"user://audit_logs/audit_%s.json" % _get_session_id_safe()
	]

	for path in critical_paths:
		if FileAccess.file_exists(path):
			var result := IntegrityChecker.validate_file_signature(path)
			if result:
				_audit("✅ Signature OK: %s" % path)
			else:
				push_error("❌ Signature INVALID for: %s" % path)
		else:
			push_warning("⚠️ File not found for signature check: %s" % path)


## Gets session ID safely from SessionManager if available.
func _get_session_id_safe() -> String:
	var session_manager := get_node_or_null("/root/SessionManager")
	return session_manager.get_session_id() if session_manager else "unknown"


## Optionally validates XML configuration file against its XSD.
func _validate_schema_xsd() -> void:
	if FileAccess.file_exists(SETTINGS_XSD) and FileAccess.file_exists(SETTINGS_SCHEMA):
		var result := XsdUtils.validate_with_xsd(SETTINGS_XSD, SETTINGS_SCHEMA)
		if result == OK:
			_audit("✅ XML settings schema validated successfully.")
		else:
			push_warning("⚠️ XML settings failed schema validation.")


## Emits and logs audit messages.
func _audit(message: String) -> void:
	print_debug(message)
	_audit_log_manager.append_entry(message)
