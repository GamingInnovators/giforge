extends Node


# --- Description ---
##
## MetadataLogManager.gd (GLI-19 Certified Version)
##
## Central authority for structured session metadata logging, secure export, and archival.
##
## Responsibilities:
## - Track metadata for each session (start, end, system, operator)
## - Export metadata in JSON, XML (with XSD validation), and CSV formats
## - Sign each export with SHA-256 integrity
## - Compress session metadata into ZIP archives after finalization
##
## Must be registered as Autoload (singleton).


# --- Signals ---


## Emitted when the session metadata is finalized and archived.
##
## @param session_id: Finalized session identifier.
signal session_metadata_finalized(session_id: String)


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")

var _metadata_dir: String = "user://metadata/"
var _active_metadata_file: String = "session_metadata.log"
var _xsd_path: String = "user://schemas/metadata_log.xsd"

var _metadata_file_path: String = ""
var _current_session_id: String = ""
var _session_metadata: Dictionary = {}


# --- Lifecycle Methods ---


## Initializes the MetadataLogManager and prepares directories.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager must be available.")
	assert(_settings_manager != null, "❌ SettingsManager must be available.")

	_load_from_settings()
	_prepare_directories()

	_metadata_file_path = _metadata_dir.path_join(_active_metadata_file)

	_audit_log_manager.append_entry("📝 MetadataLogManager initialized.")


# --- Public Methods ---


## Starts a new metadata session.
##
## @param session_id: Unique session identifier.
## @param operator_name: Operator responsible.
## @param system_version: System version string.
func start_session(session_id: String, operator_name: String, system_version: String) -> void:
	assert(session_id != "", "❌ Session ID must not be empty.")
	assert(operator_name != "", "❌ Operator name must not be empty.")
	assert(system_version != "", "❌ System version must not be empty.")

	_current_session_id = session_id

	_session_metadata = {
		"session_id": session_id,
		"operator": operator_name,
		"system_version": system_version,
		"start_time": Time.get_datetime_string_from_system(true),
		"system": OS.get_name(),
		"hostname": OS.get_environment("HOSTNAME") if OS.has_environment("HOSTNAME") else "unknown"
	}

	_append_to_file(_session_metadata)

	_audit_log_manager.append_entry("🚀 Metadata session started: %s" % session_id)


## Finalizes the metadata session and exports data securely.
func finalize_session() -> void:
	assert(_current_session_id != "", "❌ No active session to finalize.")

	_session_metadata["end_time"] = Time.get_datetime_string_from_system(true)
	_append_to_file(_session_metadata)

	var cumulative_hash := compute_session_hash(_current_session_id)
	_audit_log_manager.append_entry("🔒 Session [%s] finalized with cumulative hash: %s" % [_current_session_id, cumulative_hash])

	var json_path := _metadata_dir.path_join("metadata_%s.json" % _current_session_id)
	var xml_path := _metadata_dir.path_join("metadata_%s.xml" % _current_session_id)
	var csv_path := _metadata_dir.path_join("metadata_%s.csv" % _current_session_id)

	_safe_export_json(json_path)
	_safe_export_xml(xml_path)
	_safe_export_csv(csv_path)

	var archive_path := _metadata_dir.path_join("meta_%s.zip" % _current_session_id)
	_zip_file(_metadata_file_path, archive_path)

	DirAccess.remove_absolute(_metadata_file_path)

	emit_signal("session_metadata_finalized", _current_session_id)


## Exports session metadata to JSON securely.
func export_session_json(target_path: String, session_id: String) -> void:
	assert(target_path.ends_with(".json"), "❌ Target path must end with '.json'.")
	assert(session_id != "", "❌ Session ID must not be empty.")

	var entries := _get_entries_by_session(session_id)
	assert(entries.size() > 0, "❌ No entries found for session: %s" % session_id)

	FileUtils.save_json(target_path, entries)
	IntegrityChecker.save_file_signature(target_path)
	_audit_log_manager.append_entry("✅ JSON metadata exported: %s" % target_path)


## Exports session metadata to XML securely with XSD validation.
func export_session_xml(target_path: String, session_id: String) -> void:
	assert(target_path.ends_with(".xml"), "❌ Target path must end with '.xml'.")
	assert(session_id != "", "❌ Session ID must not be empty.")

	var entries := _get_entries_by_session(session_id)
	assert(entries.size() > 0, "❌ No entries found for session: %s" % session_id)

	FileUtils.save_xml(target_path, entries)

	if XsdUtils.validate_with_xsd(target_path, _xsd_path) == OK:
		IntegrityChecker.save_file_signature(target_path)
		_audit_log_manager.append_entry("✅ XML metadata exported and validated: %s" % target_path)
	else:
		push_warning("⚠️ XML validation failed: %s" % target_path)
		DirAccess.remove_absolute(target_path)


## Exports session metadata to CSV securely.
func export_session_csv(target_path: String, session_id: String) -> void:
	assert(target_path.ends_with(".csv"), "❌ Target path must end with '.csv'.")
	assert(session_id != "", "❌ Session ID must not be empty.")

	var entries := _get_entries_by_session(session_id)
	assert(entries.size() > 0, "❌ No entries found for session: %s" % session_id)

	FileUtils.save_csv(target_path, entries)
	IntegrityChecker.save_file_signature(target_path)
	_audit_log_manager.append_entry("✅ CSV metadata exported: %s" % target_path)


## Computes SHA-256 hash over all entries of a session.
##
## @param session_id String: Session ID.
## @return String: Hex-encoded SHA-256 cumulative hash.
func compute_session_hash(session_id: String) -> String:
	assert(session_id != "", "❌ Session ID is required for hash computation.")

	var entries := _get_entries_by_session(session_id)
	if entries.is_empty():
		push_warning("⚠️ No metadata found for session: %s" % session_id)
		return ""

	var buffer := PackedByteArray()
	for entry in entries:
		buffer.append_array(JSON.stringify(entry).to_utf8_buffer())

	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(buffer)

	return hasher.finish().hex_encode()


## Safely exports metadata to JSON.
func _safe_export_json(path: String) -> bool:
	var entries := _get_entries_by_session(_current_session_id)
	if entries.is_empty():
		return false

	FileUtils.save_json(path, entries)
	IntegrityChecker.save_file_signature(path)
	return true


## Safely exports metadata to XML.
func _safe_export_xml(path: String) -> bool:
	var entries := _get_entries_by_session(_current_session_id)
	if entries.is_empty():
		return false

	FileUtils.save_xml(path, entries)

	if XsdUtils.validate_with_xsd(path, _xsd_path) != OK:
		push_warning("⚠️ XML validation failed for: %s" % path)
		DirAccess.remove_absolute(path)
		return false

	IntegrityChecker.save_file_signature(path)
	return true


## Safely exports metadata to CSV.
func _safe_export_csv(path: String) -> bool:
	var entries := _get_entries_by_session(_current_session_id)
	if entries.is_empty():
		return false

	FileUtils.save_csv(path, entries)
	IntegrityChecker.save_file_signature(path)
	return true


## Loads dynamic settings from SettingsManager.
func _load_from_settings() -> void:
	_metadata_dir = _settings_manager.get_setting("metadata_directory", "user://metadata/")
	_active_metadata_file = _settings_manager.get_setting("active_metadata_file", "session_metadata.log")
	_xsd_path = _settings_manager.get_setting("metadata_xsd_path", "user://schemas/metadata_log.xsd")


## Prepares necessary directories.
func _prepare_directories() -> void:
	DirAccess.make_dir_recursive_absolute(_metadata_dir)
	DirAccess.make_dir_recursive_absolute(_xsd_path.get_base_dir())


## Appends a single metadata entry to the active file.
##
## @param entry Dictionary: Metadata entry.
func _append_to_file(entry: Dictionary) -> void:
	var file := FileAccess.open(_metadata_file_path, FileAccess.READ_WRITE)
	assert(file, "❌ Cannot open metadata file for writing.")
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()


## Reads all metadata entries from a file.
##
## @param file_path String: Metadata file path.
## @return Array[Dictionary]: List of parsed entries.
func _read_all_entries(file_path: String) -> Array[Dictionary]:
	assert(file_path != "", "❌ File path cannot be empty.")

	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(file_path):
		return entries

	var content := FileAccess.get_file_as_string(file_path)
	for line in content.split("\n", false):
		var parsed: Dictionary = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			entries.append(parsed)

	return entries


## Retrieves all metadata entries filtered by session ID.
##
## @param session_id String: Target session ID.
## @return Array[Dictionary]: Entries for the session.
func _get_entries_by_session(session_id: String) -> Array:
	var entries := _read_all_entries(_metadata_file_path)
	return entries.filter(func(entry): return entry.get("session_id", "") == session_id)


## Compresses the metadata file into a ZIP archive.
##
## @param source_path String: Source file to compress.
## @param target_zip String: Target ZIP archive path.
func _zip_file(source_path: String, target_zip: String) -> void:
	var zip := ZIPPacker.new()
	assert(zip.open(target_zip, ZIPPacker.APPEND_CREATE) == OK, "❌ Failed to open ZIP archive.")

	zip.start_file(source_path.get_file())
	zip.write_file(FileAccess.get_file_as_bytes(source_path))
	zip.close()

	IntegrityChecker.save_file_signature(target_zip)

	_audit_log_manager.append_entry("🗜️ Metadata compressed into: %s" % target_zip)
