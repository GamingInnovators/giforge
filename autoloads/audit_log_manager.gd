extends Node


# --- Description ---
##
## AuditLogManager.gd (Optimized and GLI-19 Compliant)
##
## Centralized immutable audit logging system.
##
## Features:
## - Structured JSON entries
## - Automatic digital signing
## - Secure rotation and compression
## - Export to JSON, CSV, XML
##
## Must be registered as Autoload (singleton).


# --- Signals ---


## Emitted when a new audit entry is recorded.
##
## @param entry Dictionary: The structured log entry.
signal entry_logged(entry: Dictionary)


# --- Constants ---


const EXPORT_FORMATS: Array[String] = ["json", "csv", "xml"]
const CRITICAL_KEYWORDS: Array[String] = ["❌", "⛔", "⚠️", "🔴"]


# --- Private Variables ---


@onready var _settings_manager := Engine.get_singleton("SettingsManager")

var _audit_dir: String = "user://audit_logs/"
var _log_file_name: String = "session_audit.log"
var _log_path: String = ""

var _max_log_size_bytes: int = 10 * 1024 * 1024

var _secure_file_helper: SecureFileHelper = SecureFileHelper.new()

var _session_id: String = "unknown_session"
var _operator_name: String = "unknown_operator"
var _otp_required: bool = false


# --- Lifecycle Methods ---


## Initializes the AuditLogManager by loading settings and preparing the log file.
func _ready() -> void:
	assert(_settings_manager != null, "❌ SettingsManager is required.")

	_load_settings()
	DirAccess.make_dir_recursive_absolute(_audit_dir)
	_initialize_log_file()

	_append_internal_entry("📝 AuditLogManager initialized successfully.")


# --- Public Methods ---


## Starts a new audit session.
##
## @param session_id String: Unique session identifier.
## @param operator_name String: Operator's name for audit traceability.
func start_session(session_id: String, operator_name: String) -> void:
	assert(session_id != "", "❌ Session ID cannot be empty.")
	assert(operator_name != "", "❌ Operator name cannot be empty.")

	_session_id = session_id
	_operator_name = operator_name

	_append_internal_entry("🟢 New session started by operator: %s" % operator_name)


## Finalizes the current session, rotating the audit log.
func finalize_session() -> void:
	_append_internal_entry("🔴 Session finalized.")
	_rotate_and_sign_log()


## Appends a new entry to the audit log.
##
## @param message String: Message content for the audit.
func append_entry(message: String) -> void:
	assert(message != "", "❌ Audit message cannot be empty.")

	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"session_id": _session_id,
		"operator": _operator_name,
		"message": message,
		"signature": IntegrityChecker.generate_signature(message)
	}

	_write_entry(entry)
	emit_signal("entry_logged", entry)


## Exports current audit logs into requested format.
##
## @param format String: "json", "csv" or "xml".
## @param target_path String: Path where export will be saved.
## @param compress bool: Whether to compress the export.
func export_log(format: String, target_path: String, compress: bool = false) -> void:
	assert(format in EXPORT_FORMATS, "❌ Invalid export format: %s" % format)

	var entries := _load_entries()
	_export_entries(entries, format, target_path)

	if compress:
		_compress_file(target_path)


# --- Private Methods ---


## Loads all dynamic settings from SettingsManager.
func _load_settings() -> void:
	_audit_dir = _settings_manager.get_setting("audit_dir", "user://audit_logs/")
	_log_file_name = _settings_manager.get_setting("audit_log_file", "session_audit.log")
	_max_log_size_bytes = _settings_manager.get_setting("max_log_size_bytes", 10 * 1024 * 1024)
	_otp_required = _settings_manager.get_setting("otp_required_for_critical_actions", false)

	_log_path = "%s%s" % [_audit_dir, _log_file_name]


## Creates the initial audit log if it does not exist.
func _initialize_log_file() -> void:
	if not FileAccess.file_exists(_log_path):
		var init_entry := {
			"timestamp": Time.get_datetime_string_from_system(true),
			"message": "📝 New audit log initialized."
		}
		_write_entry(init_entry)


## Writes a structured entry into the audit log file.
##
## @param entry Dictionary: The audit entry to write.
func _write_entry(entry: Dictionary) -> void:
	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	assert(file != null, "❌ Failed to open audit log file for writing.")

	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()

	_check_log_rotation()


## Appends an internal system event entry.
##
## @param message String: The system message.
func _append_internal_entry(message: String) -> void:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"session_id": "system",
		"operator": "system",
		"message": message,
		"signature": IntegrityChecker.generate_signature(message)
	}
	_write_entry(entry)
	emit_signal("entry_logged", entry)


## Checks if the audit log file needs rotation based on size.
func _check_log_rotation() -> void:
	if FileUtils.get_file_size(_log_path) > _max_log_size_bytes:
		_append_internal_entry("⚠️ Audit log exceeded maximum size. Rotating...")
		_rotate_and_sign_log()


## Rotates the audit log by archiving and signing it.
func _rotate_and_sign_log() -> void:
	var zip_path := "%s/audit_%s.zip" % [_audit_dir, _session_id]
	var zip := ZIPPacker.new()

	if zip.open(zip_path, ZIPPacker.APPEND_CREATE) == OK:
		zip.start_file(_log_path.get_file())
		zip.write_file(FileAccess.get_file_as_bytes(_log_path))
		zip.close()

		DirAccess.remove_absolute(_log_path)
		IntegrityChecker.save_file_signature(zip_path)

		_append_internal_entry("🗜️ Audit log rotated and signed.")
	else:
		push_error("❌ Failed to rotate audit log.")


## Loads all structured audit entries from the current log.
##
## @return Array[Dictionary]: List of audit entries.
func _load_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	if not FileAccess.file_exists(_log_path):
		return entries

	var content := FileAccess.get_file_as_string(_log_path)
	for line in content.split("\n", false):
		var parsed: Dictionary = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			entries.append(parsed)

	return entries


## Exports given entries into selected format.
##
## @param entries Array[Dictionary]: Entries to export.
## @param format String: Export format.
## @param path String: Destination path.
func _export_entries(entries: Array[Dictionary], format: String, path: String) -> void:
	match format:
		"json":
			FileUtils.save_json(path, entries)
		"csv":
			FileUtils.save_csv(path, entries)
		"xml":
			FileUtils.save_xml(path, entries)

	IntegrityChecker.save_file_signature(path)


## Compresses a file into a backup securely.
##
## @param path String: File to compress.
func _compress_file(path: String) -> void:
	var compressed_path := "%s.zip" % path
	var backup_result := _secure_file_helper.save_secure_file(
		compressed_path,
		FileAccess.get_file_as_bytes(path),
		true,
		true
	)

	if backup_result:
		DirAccess.remove_absolute(path)
		IntegrityChecker.save_file_signature(compressed_path)
	else:
		push_error("❌ Failed to compress and secure audit export at %s" % compressed_path)
