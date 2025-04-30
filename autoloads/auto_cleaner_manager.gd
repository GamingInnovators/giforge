extends Node


# --- Description ---
##
## AutoCleanerManager.gd (Optimized, Secure, GLI-19 Compliant)
##
## Automated cleaning system for obsolete files with audit, SHA-256 signature,
## JSON/XML reporting, and full compliance with persistence and traceability policies.
##
## Responsibilities:
## - Remove files based on maximum age (days) or maximum count thresholds.
## - Generate immutable cleanup reports.
## - Sign reports with SHA-256 digital signatures.
##
## Must be registered as Autoload (singleton).


# --- Constants ---


## Cleanup rules configuration: folders, files, limits.
const CLEANUP_RULES: Array[Dictionary] = [
	{ "path": "user://audit_logs/", "max_files": 20, "max_days": 180 },
	{ "path": "user://backups/", "max_files": 10, "max_days": 365 },
	{ "path": "user://cache/", "max_files": 50, "max_days": 30 },
	{ "path": "user://config/", "max_files": 10, "max_days": 365 },
	{ "path": "user://exports/", "max_files": 30, "max_days": 90 },
	{ "path": "user://logs/", "max_files": 50, "max_days": 90 },
	{ "path": "user://metadata/", "max_files": 30, "max_days": 180 },
	{ "path": "user://receipts/", "max_files": 50, "max_days": 180 },
	{ "path": "user://uploaded/", "max_files": 20, "max_days": 90 },
	{ "path": "user://rng_test_results.csv", "max_files": 5, "max_days": 30 },
	{ "path": "user://rng_gli19_log.txt", "max_files": 5, "max_days": 90 },
	{ "path": "user://manifest/", "max_files": 10, "max_days": 365 },
	{ "path": "user://saves/", "max_files": 20, "max_days": 365 }
]


# --- Public Variables ---


@export var enable_cleaning: bool = true
@export var generate_cleanup_report: bool = true


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Initializes the AutoCleanerManager and optionally triggers cleanup.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager must be loaded.")

	if enable_cleaning:
		_execute_cleanup_cycle()


# --- Private Methods ---


## Executes the cleanup cycle across all defined paths.
func _execute_cleanup_cycle() -> void:
	print("🧹 AutoCleanerManager: Starting cleanup...")

	var cleaned_files: Array[String] = []

	for rule in CLEANUP_RULES:
		var path: String = rule["path"]
		var max_files: int = rule["max_files"]
		var max_days: int = rule["max_days"]

		if not DirAccess.dir_exists_absolute(path):
			push_warning("⚠️ Cleanup skipped: Path not found: %s" % path)
			continue

		var dir := DirAccess.open(path)
		if dir == null:
			push_warning("⚠️ Cannot open cleanup directory: %s" % path)
			continue

		dir.list_dir_begin()
		var file_list: Array[String] = []

		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				file_list.append(file_name)
			file_name = dir.get_next()

		dir.list_dir_end()

		file_list.sort_custom(func(a, b): return FileAccess.get_modified_time(path.path_join(a)) < FileAccess.get_modified_time(path.path_join(b)))

		cleaned_files.append_array(_remove_excess_files(file_list, path, max_files))
		cleaned_files.append_array(_remove_old_files(file_list, path, max_days))

	if generate_cleanup_report and cleaned_files.size() > 0:
		_generate_cleanup_report(cleaned_files)


## Removes files exceeding maximum allowed count.
##
## @param files Array of filenames.
## @param path String: Directory path.
## @param max_allowed int: Maximum allowed file count.
## @return Array of cleaned file paths.
func _remove_excess_files(files: Array[String], path: String, max_allowed: int) -> Array[String]:
	var cleaned: Array[String] = []

	if files.size() <= max_allowed:
		return cleaned

	var excess_files := files.slice(0, files.size() - max_allowed)

	for file_name in excess_files:
		var full_path := path.path_join(file_name)
		if FileAccess.file_exists(full_path):
			DirAccess.remove_absolute(full_path)
			cleaned.append(full_path)
			_audit_log_manager.append_entry("🧹 Deleted excess file: %s" % full_path)

	return cleaned


## Removes files older than maximum allowed days.
##
## @param files Array of filenames.
## @param path String: Directory path.
## @param max_days int: Maximum file age in days.
## @return Array of cleaned file paths.
func _remove_old_files(files: Array[String], path: String, max_days: int) -> Array[String]:
	var cleaned: Array[String] = []
	var now := Time.get_unix_time_from_system()

	for file_name in files:
		var full_path := path.path_join(file_name)
		if FileAccess.file_exists(full_path):
			var modified_time := FileAccess.get_modified_time(full_path)
			var age_days := (now - modified_time) / (60.0 * 60.0 * 24.0)

			if age_days > max_days:
				DirAccess.remove_absolute(full_path)
				cleaned.append(full_path)
				_audit_log_manager.append_entry("🧹 Deleted old file: %s (Age: %.2f days)" % [full_path, age_days])

	return cleaned


## Generates a cleanup report with digital signature.
##
## @param cleaned_files Array of deleted file paths.
func _generate_cleanup_report(cleaned_files: Array[String]) -> void:
	var report: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(true),
		"total_cleaned_files": cleaned_files.size(),
		"files": []
	}

	for file_path in cleaned_files:
		report["files"].append({
			"file_path": file_path,
			"deletion_timestamp": Time.get_datetime_string_from_system(true)
		})

	var json_path := "user://audit_logs/auto_cleaner_report.json"
	var xml_path := "user://audit_logs/auto_cleaner_report.xml"

	FileUtils.save_json(json_path, report)
	FileUtils.save_xml(xml_path, report)

	if FileAccess.file_exists(json_path):
		IntegrityChecker.save_file_signature(json_path)
	if FileAccess.file_exists(xml_path):
		IntegrityChecker.save_file_signature(xml_path)

	_audit_log_manager.append_entry("📄 AutoCleaner cleanup report generated and signed successfully.")
