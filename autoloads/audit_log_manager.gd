extends Node
class_name AuditLogManager


# --- Description ---
##
## AuditLogManager.gd (GLI-19 Compliant)
##
## Centralized immutable audit logging system with real-time integrity tracking.
##
## Features:
## - Structured JSON entries
## - SHA-256 digital signature per entry
## - Automatic file rotation and ZIP compression
## - Export to JSON, CSV, XML with verification
## - Operator and session tracking for traceability
##
## Must be registered as Autoload (singleton)
## Location: res://autoloads/audit_log_manager.gd


# --- Signals ---


## Emitted whenever a new entry is recorded into the audit log.
##
## @param entry Dictionary: The structured and signed audit entry.
signal entry_logged(entry: Dictionary)


# --- Constants ---


## Supported export formats for log export.
const EXPORT_FORMATS: Array[String] = ["json", "csv", "xml"]

## Keywords considered critical for real-time monitoring dashboards.
const CRITICAL_KEYWORDS: Array[String] = ["❌", "⛔", "⚠️", "🔴"]

## Default configuration (overridden by SettingsManager if available).
const DEFAULT_AUDIT_DIR := "user://audit_logs/"
const DEFAULT_LOG_NAME := "session_audit.log"
const DEFAULT_MAX_SIZE := 10 * 1024 * 1024  # 10 MB


# --- Dependencies & Internal State ---


@onready var _settings_manager := get_node_or_null("/root/SettingsManager")

var _audit_dir: String = DEFAULT_AUDIT_DIR
var _log_file_name: String = DEFAULT_LOG_NAME
var _log_path: String = ""
var _max_log_size_bytes: int = DEFAULT_MAX_SIZE

var _session_id: String = "unknown_session"
var _operator_name: String = "unknown_operator"
var _otp_required: bool = false


# --- Lifecycle Methods ---


## Initializes audit system, directory structure, and log file.
func _ready() -> void:
	assert(_settings_manager != null, "❌ [AuditLogManager] SettingsManager reference is required but missing.")

	_load_settings()
	DirAccess.make_dir_recursive_absolute(_audit_dir)
	_initialize_log_file()
	_append_internal_entry("📝 [AuditLogManager] Initialized successfully.")


## Loads persistent configuration for audit log parameters.
func _load_settings() -> void:
	_audit_dir = _settings_manager.get_setting("audit_dir", DEFAULT_AUDIT_DIR)
	_log_file_name = _settings_manager.get_setting("audit_log_file", DEFAULT_LOG_NAME)
	_max_log_size_bytes = _settings_manager.get_setting("max_log_size_bytes", DEFAULT_MAX_SIZE)
	_otp_required = _settings_manager.get_setting("otp_required_for_critical_actions", false)

	_log_path = "%s%s" % [_audit_dir, _log_file_name]


## Creates the initial log file if it does not exist.
func _initialize_log_file() -> void:
	if not FileAccess.file_exists(_log_path):
		var init_entry := {
			"timestamp": Time.get_datetime_string_from_system(true),
			"session_id": "system",
			"operator": "system",
			"message": "📝 Log initialized.",
			"signature": IntegrityChecker.generate_signature("📝 Log initialized.")
		}
		_write_entry(init_entry)


## Appends a structured internal system entry to the audit log.
##
## @param message String: Text to record, typically system lifecycle events.
func _append_internal_entry(message: String) -> void:
	assert(message != "", "❌ [AuditLogManager] nternal log message cannot be empty.")

	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"session_id": "system",
		"operator": "system",
		"message": message,
		"signature": IntegrityChecker.generate_signature(message)
	}

	_write_entry(entry)
	emit_signal("entry_logged", entry)


# --- Public Methods ---


## Starts a new audit session with contextual information.
##
## @param session_id String: Unique session ID for this session.
## @param operator_name String: Name of the human operator (for traceability).
func start_session(session_id: String, operator_name: String) -> void:
	assert(session_id != "", "❌ [AuditLogManager] Session ID must not be empty.")
	assert(operator_name != "", "❌ [AuditLogManager] Operator name must not be empty.")

	_session_id = session_id
	_operator_name = operator_name

	_append_internal_entry("🟢 [AuditLogManager] Session started by operator: %s" % operator_name)


## Finalizes the current session and rotates the audit log.
func finalize_session() -> void:
	_append_internal_entry("🔴 [AuditLogManager] Session finalized.")
	_rotate_and_sign_log()


## Appends a user-level structured audit entry.
##
## @param message String: Description of the event to log.
func append_entry(message: String) -> void:
	assert(message != "", "❌ Audit entry message is required.")

	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"session_id": _session_id,
		"operator": _operator_name,
		"message": message,
		"signature": IntegrityChecker.generate_signature(message)
	}

	_write_entry(entry)
	emit_signal("entry_logged", entry)


# --- Internal Write Logic ---


## Writes the structured entry to the audit log and checks size threshold.
##
## @param entry Dictionary: Structured log line to persist.
func _write_entry(entry: Dictionary) -> void:
	assert(entry.has("timestamp"), "❌ [AuditLogManager] Structured log entry is missing 'timestamp' field.")
	assert(entry.has("message"), "❌ [AuditLogManager] Structured log entry is missing 'message' field.")

	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	assert(file != null, "❌ Unable to open audit log file.")

	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()

	_check_log_rotation()


# --- Rotation & Size Enforcement ---


## Checks if the current log exceeds the configured maximum size.
##
## If exceeded, rotates and signs the file securely.
func _check_log_rotation() -> void:
	if FileUtils.get_file_size(_log_path) > _max_log_size_bytes:
		_append_internal_entry("⚠️ [AuditLogManager] Log exceeded size threshold. Rotation initiated.")
		_rotate_and_sign_log()


## Archives the current audit log into a ZIP file, digitally signs it,
## and resets the active log file.
##
## Follows GLI-19 compliance: immutable archive, digital signature and traceability.
func _rotate_and_sign_log() -> void:
	var zip_path := "%s/audit_%s.zip" % [_audit_dir, _session_id]
	var zip := ZIPPacker.new()

	if zip.open(zip_path, ZIPPacker.APPEND_CREATE) == OK:
		zip.start_file(_log_file_name)
		zip.write_file(FileAccess.get_file_as_bytes(_log_path))
		zip.close()

		# Clean the original log file and save signature of the ZIP
		DirAccess.remove_absolute(_log_path)
		IntegrityChecker.save_file_signature(zip_path)

		_append_internal_entry("🗜️ [AuditLogManager] Log archived and signed: %s" % zip_path.get_file())
	else:
		push_error("❌ [AuditLogManager] Failed to rotate and archive log at: %s" % zip_path)


# --- Export Methods ---


## Exports the given list of entries to the specified format and path.
##
## @param entries Array[Dictionary]: The audit entries to export.
## @param format String: "json", "csv", or "xml".
## @param path String: Destination file path.
func _export_entries(entries: Array[Dictionary], format: String, path: String) -> void:
	assert(entries.size() > 0, "❌ [AuditLogManager] No entries provided for export operation.")
	assert(EXPORT_FORMATS.has(format), "❌ [AuditLogManager] Unsupported export format: %s" % format)

	match format:
		"json":
			FileUtils.save_json(path, entries)
		"csv":
			FileUtils.save_csv(path, entries)
		"xml":
			FileUtils.save_xml(path, entries)

	# Digitally sign the exported file for tamper detection
	IntegrityChecker.save_file_signature(path)

	_append_internal_entry("📤 [AuditLogManager] Exported %d entries to %s (%s format)" % [entries.size(), path.get_file(), format])


## Compresses a previously exported file with encryption and signature.
##
## @param path String: Path to the exported file.
func _compress_file(path: String) -> void:
	var compressed_path := "%s.zip" % path
	var raw_data: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var encryption_key: String = _settings_manager.get_encryption_key()

	var success := FileUtils.save_secure_file_static(
		compressed_path,
		raw_data,
		encryption_key,
		5.0,
		true,
		true
	)

	if success:
		DirAccess.remove_absolute(path)
		IntegrityChecker.save_file_signature(compressed_path)
		_append_internal_entry("🗜️ [AuditLogManager] Compressed and signed: %s" % compressed_path.get_file())
	else:
		push_error("❌ [AuditLogManager] Failed to compress and secure export: %s" % path)


## Loads and parses all valid structured entries from the current audit log file.
##
## @return Array[Dictionary]: List of entries. Invalid lines are skipped silently.
func _load_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	if not FileAccess.file_exists(_log_path):
		return entries

	var content := FileAccess.get_file_as_string(_log_path)
	if content == "":
		return entries

	for line in content.split("\n", false):
		if line.strip_edges() == "":
			continue

		var parsed: Dictionary = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			entries.append(parsed)

	return entries


# --- Analysis and Search Tools ---


## Checks whether the current audit log contains any critical messages.
##
## A message is considered critical if it includes one of the predefined CRITICAL_KEYWORDS.
##
## @return bool: True if any critical entry is found.
func has_critical_entries() -> bool:
	var entries := _load_entries()

	for entry in entries:
		if entry.has("message"):
			for keyword in CRITICAL_KEYWORDS:
				if entry["message"].findn(keyword) != -1:
					return true

	return false


## Returns the total number of structured audit entries currently stored.
##
## Useful for dashboards, summaries, or diagnostics.
##
## @return int: Count of structured entries.
func get_entry_count() -> int:
	return _load_entries().size()


## Retrieves structured audit entries that fall within a specific date range.
##
## Optionally filters by `log_type`, which corresponds to the "task" field or any categorization key.
##
## @param log_type String: Optional filter (e.g., "integrity_check", "device_lock_check"). If empty, matches all.
## @param start_date String: Inclusive start date in "YYYY-MM-DD" format.
## @param end_date String: Inclusive end date in "YYYY-MM-DD" format.
## @return Array[Dictionary]: Filtered entries in chronological order.
func get_logs_between_dates(log_type: String, start_date: String, end_date: String) -> Array[Dictionary]:
	assert(start_date != "", "❌ [AuditLogManager] 'start_date' is required for filtering.")
	assert(end_date != "", "❌ [AuditLogManager] 'end_date' is required for filtering.")

	var results: Array[Dictionary] = []
	var entries: Array[Dictionary] = _load_entries()

	var start_dt := Time.get_unix_time_from_datetime_string("%sT00:00:00" % start_date)
	var end_dt := Time.get_unix_time_from_datetime_string("%sT23:59:59" % end_date)

	for entry in entries:
		if not entry.has("timestamp"):
			continue

		var ts: String = entry["timestamp"]
		var entry_time := Time.get_unix_time_from_datetime_string(ts)

		# Only match within range
		if entry_time < start_dt or entry_time > end_dt:
			continue

		# If log_type is given, filter by field "task"
		var matches_type: bool = log_type == "" or (entry.has("task") and entry["task"] == log_type)

		if matches_type:
			results.append(entry)

	# Optionally, sort results by timestamp ascending
	results.sort_custom(func(a, b):
		return Time.get_unix_time_from_datetime_string(a["timestamp"]) < Time.get_unix_time_from_datetime_string(b["timestamp"])
	)

	return results


## Performs a full-text search in audit messages for the provided keyword.
##
## The search is case-insensitive and trims spaces.
##
## @param keyword String: Text to look for in log entries.
## @return Array[Dictionary]: List of matched entries.
func search_entries(keyword: String) -> Array[Dictionary]:
	assert(keyword != "", "❌ [AuditLogManager] Search keyword must not be empty.")

	var results: Array[Dictionary] = []
	var entries := _load_entries()
	var normalized := keyword.strip_edges().to_lower()

	if normalized == "":
		return results

	for entry in entries:
		if entry.has("message"):
			var msg: String = entry["message"].to_lower()
			if msg.findn(normalized) != -1:
				results.append(entry)

	return results


## Exports audit logs filtered by type and date range in JSON, CSV, and XML formats.
##
## Ensures compliance with GLI-19 by including signed outputs.
##
## @param log_type String: Optional task filter. Pass "" to include all types.
## @param start_date String: Inclusive start in "YYYY-MM-DD".
## @param end_date String: Inclusive end in "YYYY-MM-DD".
func export_logs_by_date_range(log_type: String, start_date: String, end_date: String) -> void:
	assert(start_date != "", "❌ Start date is required.")
	assert(end_date != "", "❌ End date is required.")

	var logs := get_logs_between_dates(log_type, start_date, end_date)

	if logs.is_empty():
		append_entry("⚠️ [AuditLogManager] No logs found from %s to %s (type: %s)." % [start_date, end_date, log_type])
		return

	var base_name := "%s_%s_to_%s" % [log_type if log_type != "" else "all_logs", start_date, end_date]
	var json_path := "%s/%s.json" % [_audit_dir, base_name]
	var csv_path := "%s/%s.csv" % [_audit_dir, base_name]
	var xml_path := "%s/%s.xml" % [_audit_dir, base_name]

	# Export and sign
	FileUtils.save_json(json_path, logs)
	FileUtils.save_csv(csv_path, logs)
	FileUtils.save_xml(xml_path, logs)

	IntegrityChecker.save_file_signature(json_path)
	IntegrityChecker.save_file_signature(csv_path)
	IntegrityChecker.save_file_signature(xml_path)

	# Log export operation
	append_entry("📤 [AuditLogManager] Exported %d logs from %s to %s [type: %s]" % [
		logs.size(), start_date, end_date, log_type if log_type != "" else "all"
	])


## Deletes audit entries older than N days and rewrites the file.
##
## @param days int: Number of days to retain.
func purge_entries_older_than(days: int) -> void:
	assert(days > 0, "❌ [AuditLogManager] Purge days must be a positive integer.")

	var cutoff_ts := Time.get_unix_time_from_system() - (days * 86400)
	var kept_entries := []

	for entry in _load_entries():
		if entry.has("timestamp"):
			var entry_ts := Time.get_unix_time_from_datetime_string(entry["timestamp"])
			if entry_ts >= cutoff_ts:
				kept_entries.append(entry)

	if kept_entries.is_empty():
		push_warning("⚠️ [AuditLogManager] All audit entries purged. No data newer than %d days." % days)
	else:
		# Rewrite file safely
		var file := FileAccess.open(_log_path, FileAccess.WRITE)
		for entry in kept_entries:
			file.store_line(JSON.stringify(entry))
		file.close()

		append_entry("🧹 [AuditLogManager] Purged entries older than %d days. %d retained." % [days, kept_entries.size()])
