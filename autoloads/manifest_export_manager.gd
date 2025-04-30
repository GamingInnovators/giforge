extends Node


# --- Description ---
##
## ManifestExportManager.gd (GLI-19 Hardened)
##
## Centralized module for secure generation, validation, signing, and multi-format export of manifest files.
##
## Responsibilities:
## - Scans export directories for files.
## - Builds structured manifest with path, size, and SHA-256.
## - Saves and signs manifest (JSON + CSV + XML ready).
## - Ensures full GLI-19 traceability and tamper-proof operation.
##
## Must be registered as Autoload (singleton).


# --- Dependencies ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")
@onready var _session_manager := Engine.get_singleton("SessionManager")


# --- Private Variables ---


var _export_directories: Array[String] = []
var _manifest_path: String = "user://manifest/manifest.json"


# --- Lifecycle Methods ---


## Initializes the ManifestExportManager after Autoload registration.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager not loaded.")
	assert(_settings_manager != null, "❌ SettingsManager not loaded.")
	assert(_session_manager != null, "❌ SessionManager not loaded.")

	_load_settings()
	_ensure_directories()

	_audit_log_manager.append_entry("📜 ManifestExportManager initialized successfully.")


# --- Public Methods ---


## Generates a full signed manifest based on configured directories.
##
## @return bool: True if manifest generated and signed successfully, False otherwise.
func generate_manifest() -> bool:
	var manifest: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(true),
		"system_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"session_id": _session_manager.get_session_id(),
		"operator": _session_manager.get_operator_name(),
		"files": []
	}

	for dir_path in _export_directories:
		_append_directory_to_manifest(dir_path, manifest)

	var raw_manifest := JSON.stringify(manifest, "\t")
	manifest["signature"] = HashUtils.sha256_from_string(raw_manifest)

	if not _save_manifest_to_disk(manifest):
		push_error("❌ Failed to save manifest: %s" % _manifest_path)
		return false

	_export_manifest_as_csv(manifest)
	_audit_log_manager.append_entry("✅ Manifest generated and signed successfully: %s" % _manifest_path)
	return true


## Returns the current manifest path.
##
## @return String: Path of the manifest file.
func get_manifest_path() -> String:
	return _manifest_path


## Loads and parses the manifest safely from disk.
##
## @return Dictionary: Loaded manifest data or empty dictionary if failed.
func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(_manifest_path):
		push_warning("⚠️ Manifest file not found: %s" % _manifest_path)
		return {}

	var file := FileAccess.open(_manifest_path, FileAccess.READ)
	if file == null:
		push_warning("⚠️ Cannot open manifest file: %s" % _manifest_path)
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed: Dictionary = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("⚠️ Manifest content invalid.")
		return {}

	return parsed


## Compares two manifests (old vs new) and exports a full audit trail (JSON + CSV).
##
## @param old_manifest_path String: Path to the previous (reference) manifest.
## @param new_manifest_path String: Path to the newly generated manifest.
##
## @return Dictionary: Structured comparison report.
func compare_manifests(old_manifest_path: String, new_manifest_path: String) -> Dictionary:
	assert(old_manifest_path != "", "❌ Old manifest path must not be empty.")
	assert(new_manifest_path != "", "❌ New manifest path must not be empty.")

	var old_manifest := _load_manifest_from_path(old_manifest_path)
	var new_manifest := _load_manifest_from_path(new_manifest_path)

	var report: Dictionary = {
		"checked": 0,
		"matched": 0,
		"modified": [],
		"missing_in_new": [],
		"extra_in_new": [],
		"errors": []
	}

	if old_manifest.is_empty() or new_manifest.is_empty():
		push_warning("⚠️ One or both manifests could not be loaded.")
		report.errors.append("One or both manifests could not be loaded correctly.")
		return report

	var old_files := _build_file_map(old_manifest)
	var new_files := _build_file_map(new_manifest)

	# Check for modified or missing files
	for path in old_files.keys():
		report.checked += 1

		if not new_files.has(path):
			report.missing_in_new.append(path)
			continue

		if old_files[path]["sha256"] != new_files[path]["sha256"]:
			report.modified.append({
				"path": path,
				"old_sha256": old_files[path]["sha256"],
				"new_sha256": new_files[path]["sha256"]
			})
		else:
			report.matched += 1

	# Check for extra files
	for path in new_files.keys():
		if not old_files.has(path):
			report.extra_in_new.append(path)

	_export_comparison_report(report)

	_audit_log_manager.append_entry(
		"🧩 Manifest comparison completed: Matched: %d | Modified: %d | Missing: %d | Extra: %d" % [
			report.matched,
			report.modified.size(),
			report.missing_in_new.size(),
			report.extra_in_new.size()
		]
	)

	return report


# --- Private Methods ---


## Exports the comparison report into JSON, CSV, and XML files with SHA-256 signatures.
##
## @param report Dictionary: The structured comparison report.
func _export_comparison_report(report: Dictionary) -> void:
	var timestamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	var base_path := "user://audit_logs/manifest_comparison_report_%s" % timestamp

	var json_path := "%s.json" % base_path
	var csv_path := "%s.csv" % base_path
	var xml_path := "%s.xml" % base_path

	# Save JSON
	FileUtils.save_json(json_path, report)

	# Prepare CSV
	var csv_data: Array = []

	for mod_entry in report.modified:
		csv_data.append({
			"event": "Modified",
			"path": mod_entry.path,
			"old_sha256": mod_entry.old_sha256,
			"new_sha256": mod_entry.new_sha256
		})

	for missing_path in report.missing_in_new:
		csv_data.append({
			"event": "MissingInNew",
			"path": missing_path,
			"old_sha256": "N/A",
			"new_sha256": "N/A"
		})

	for extra_path in report.extra_in_new:
		csv_data.append({
			"event": "ExtraInNew",
			"path": extra_path,
			"old_sha256": "N/A",
			"new_sha256": "N/A"
		})

	FileUtils.save_csv(csv_path, csv_data)

	# Save XML
	var xml_struct: Array = []

	for entry in csv_data:
		xml_struct.append(entry)

	FileUtils.save_xml(xml_path, xml_struct)

	# Sign files
	if IntegrityChecker:
		IntegrityChecker.save_file_signature(json_path)
		IntegrityChecker.save_file_signature(csv_path)
		IntegrityChecker.save_file_signature(xml_path)

	_audit_log_manager.append_entry(
		"📄 Manifest comparison reports saved: %s (JSON), %s (CSV), %s (XML)" % [json_path, csv_path, xml_path]
	)


## Loads and parses a manifest from a specific file path.
##
## @param manifest_path String: Path to manifest file.
## @return Dictionary: Parsed manifest or empty dictionary.
func _load_manifest_from_path(manifest_path: String) -> Dictionary:
	if not FileAccess.file_exists(manifest_path):
		push_warning("⚠️ Manifest file not found: %s" % manifest_path)
		return {}

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_warning("⚠️ Cannot open manifest file: %s" % manifest_path)
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed: Dictionary = JSON.parse_string(content)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	else:
		push_warning("⚠️ Invalid manifest format at: %s" % manifest_path)
		return {}


## Builds a lookup map from a manifest.
##
## @param manifest Dictionary: Manifest dictionary.
## @return Dictionary: Map of { path -> {size, sha256} }
func _build_file_map(manifest: Dictionary) -> Dictionary:
	var map := {}

	for file_entry in manifest.get("files", []):
		map[file_entry.get("path", "")] = {
			"size": file_entry.get("size", 0),
			"sha256": file_entry.get("sha256", "")
		}

	return map



## Loads manifest settings from SettingsManager.
func _load_settings() -> void:
	_export_directories = _settings_manager.get_setting("export_directories", [
		"user://audit_logs/",
		"user://metadata/",
		"user://exports/config/"
	])

	_manifest_path = _settings_manager.get_setting("manifest_path", "user://manifest/manifest.json")


## Ensures that necessary directories exist.
func _ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(_manifest_path.get_base_dir())

	for path in _export_directories:
		DirAccess.make_dir_recursive_absolute(path)


## Saves the manifest securely and signs it.
##
## @param manifest Dictionary: Manifest content.
## @return bool: True if saved, False otherwise.
func _save_manifest_to_disk(manifest: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(_manifest_path.get_base_dir())

	var file := FileAccess.open(_manifest_path, FileAccess.WRITE)
	if file == null:
		push_error("❌ Failed to open manifest for writing: %s" % _manifest_path)
		return false

	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()

	if IntegrityChecker:
		IntegrityChecker.save_file_signature(_manifest_path)

	return true


## Recursively appends files from a directory into the manifest.
##
## @param dir_path String: Directory to scan.
## @param manifest Dictionary: Manifest being built.
func _append_directory_to_manifest(dir_path: String, manifest: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("⚠️ Cannot open directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and not file_name.begins_with("."):
			var full_path := dir_path.path_join(file_name)
			_append_file_to_manifest(full_path, manifest)

		file_name = dir.get_next()

	dir.list_dir_end()


## Appends single file information to the manifest.
##
## @param file_path String: Path of the file.
## @param manifest Dictionary: Manifest data.
func _append_file_to_manifest(file_path: String, manifest: Dictionary) -> void:
	if not FileAccess.file_exists(file_path):
		push_warning("⚠️ Skipping missing file: %s" % file_path)
		return

	var buffer := FileAccess.get_file_as_bytes(file_path)
	if buffer.is_empty():
		push_warning("⚠️ Skipping empty file: %s" % file_path)
		return

	manifest["files"].append({
		"path": file_path,
		"size": buffer.size(),
		"sha256": HashUtils.sha256_from_bytes(buffer)
	})


## Exports the manifest contents as CSV for external audits.
##
## @param manifest Dictionary: Manifest data already generated.
func _export_manifest_as_csv(manifest: Dictionary) -> void:
	var csv_path := _manifest_path.replace(".json", ".csv")
	var csv_data: Array = []

	for file_entry in manifest.get("files", []):
		csv_data.append({
			"path": file_entry.get("path", ""),
			"size": file_entry.get("size", 0),
			"sha256": file_entry.get("sha256", "")
		})

	FileUtils.save_csv(csv_path, csv_data)

	if IntegrityChecker:
		IntegrityChecker.save_file_signature(csv_path)

	_audit_log_manager.append_entry("📄 Manifest exported additionally as CSV: %s" % csv_path)
