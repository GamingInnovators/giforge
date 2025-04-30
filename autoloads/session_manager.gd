extends Node
class_name SessionManager


# --- Description ---
##
## SessionManager.gd (GLI-19 Compliant, Optimized)
##
## Responsible for secure lifecycle management of game sessions.
##
## Responsibilities:
## - Generate and validate session ID (UUIDv4)
## - Bind operator metadata
## - Manage secure finalization and export of session logs
## - Provide session integrity assurance (Audit, Metadata, Receipt)
##
## Must be registered as Autoload (singleton).


# --- Signals ---


## Emitted when a new session starts.
## @param session_id String: Unique session identifier.
signal session_started(session_id: String)


## Emitted when a session ends.
## @param session_id String: Unique session identifier.
signal session_ended(session_id: String)


# --- Constants ---


const SETTINGS_PATH: String = "user://config/settings.json"


# --- Dependencies ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _metadata_log_manager := Engine.get_singleton("MetadataLogManager")
@onready var _receipt_manager := Engine.get_singleton("ReceiptManager")


# --- Private Variables ---


var _session_id: String = ""
var _operator_name: String = ""


# --- Lifecycle Methods ---


## Initializes and starts the session lifecycle.
func _ready() -> void:
	_validate_dependencies()
	await _start_session()


# --- Private Methods ---


## Validates critical dependencies before starting the session.
func _validate_dependencies() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager not loaded.")
	assert(_metadata_log_manager != null, "❌ MetadataLogManager not loaded.")
	assert(_receipt_manager != null, "❌ ReceiptManager not loaded.")


## Starts a new session with generated ID and operator loading.
func _start_session() -> void:
	await _generate_session_id()

	emit_signal("session_started", _session_id)

	_load_operator_name()

	_audit_log_manager.start_session(_session_id, _operator_name)
	_metadata_log_manager.start_session(_session_id, _operator_name, Engine.get_version_info()["string"])
	_receipt_manager.start_session(_session_id)

	_audit_log_manager.append_entry("🎮 New session started: %s" % _session_id)


## Generates a UUID v4 session ID securely.
func _generate_session_id() -> void:
	var generator := SessionIDGenerator.new()
	_session_id = await generator.generate_session_id()

	assert(_session_id.length() > 0, "❌ Failed to generate session ID.")

	if _session_id.is_empty():
		push_error("❌ Critical: Session ID generation failed, terminating session startup.")
		_audit_log_manager.append_entry("❌ Critical failure: Session ID missing, exiting game.")
		end_session()
		get_tree().quit()


## Loads operator name from persistent configuration, or uses fallback.
func _load_operator_name() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		push_warning("⚠️ Settings file not found: %s" % SETTINGS_PATH)
		_operator_name = "Unknown Operator"
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	assert(file != null, "❌ Failed to open settings file.")

	var content := file.get_as_text()
	file.close()

	var data: Dictionary = JSON.parse_string(content)

	if typeof(data) == TYPE_DICTIONARY and data.has("operator_name"):
		_operator_name = data["operator_name"]
		_audit_log_manager.append_entry("👤 Operator loaded: %s" % _operator_name)
	else:
		_operator_name = "Unknown Operator"
		push_warning("⚠️ Operator name missing in settings file.")


## Signs a file only if it exists.
func _sign_file_if_exists(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		IntegrityChecker.save_file_signature(file_path)
	else:
		push_warning("⚠️ Missing file for signature: %s" % file_path)


## Finalizes all session components and exports securely.
func _finalize_exports() -> void:
	if _audit_log_manager:
		_audit_log_manager.finalize_session()

	if _metadata_log_manager:
		_metadata_log_manager.finalize_session()

	if _receipt_manager:
		_receipt_manager.finalize_session(_session_id)

	_sign_file_if_exists("user://audit_logs/audit_%s.json" % _session_id)
	_sign_file_if_exists("user://metadata/metadata_%s.json" % _session_id)
	_sign_file_if_exists("user://receipts/receipt_%s.json" % _session_id)


# --- Public Methods ---


## Ends the current session gracefully and securely.
func end_session() -> void:
	_audit_log_manager.append_entry("🛑 Session ended: %s" % _session_id)

	_metadata_log_manager.append_entry({
		"event": "session_end",
		"timestamp": Time.get_datetime_string_from_system(true)
	})

	_finalize_exports()

	emit_signal("session_ended", _session_id)


## Retrieves the active session ID (UUID v4 format).
##
## @return String: The active session identifier.
func get_session_id() -> String:
	return _session_id


## Sets the operator name manually and logs the event.
##
## @param operator_name String: Name of the operator.
func set_operator_name(operator_name: String) -> void:
	assert(operator_name != "", "❌ Operator name must not be empty.")

	_operator_name = operator_name

	_audit_log_manager.append_entry("👤 Operator manually set: %s" % _operator_name)
	_metadata_log_manager.append_entry({
		"event": "operator_set",
		"operator": _operator_name,
		"timestamp": Time.get_datetime_string_from_system(true)
	})


## Returns the current operator's name.
##
## @return String: Operator name.
func get_operator_name() -> String:
	return _operator_name
