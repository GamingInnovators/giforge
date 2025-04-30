extends Node
class_name TestAutoCleanerManager


# --- Description ---
##
## TestAutoCleanerManager.gd
##
## Unit test suite for AutoCleanerManager.gd
##
## Responsibilities:
## - Validate file cleaning logic (by max count and age).
## - Confirm report generation (JSON/XML) and signature existence.
## - Ensure integration with AuditLogManager.
##
## Must be executed separately in a dedicated testing environment.
##
## Not an Autoload.
##


# --- Private Variables ---


var _test_dir: String = "user://test_auto_cleaner/"
var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Sets up test environment before tests.
func _ready() -> void:
	_initialize_test_environment()
	_run_all_tests()


## Cleans up after tests are complete.
func _exit_tree() -> void:
	_cleanup_test_environment()


# --- Test Runner ---


## Runs all tests sequentially.
func _run_all_tests() -> void:
	print("🧪 Running AutoCleanerManager tests...")
	test_excess_file_cleanup()
	test_old_file_cleanup()
	test_cleanup_report_generation()
	print("✅ All AutoCleanerManager tests completed.")


# --- Private Test Methods ---


## Initializes a test environment with dummy files.
func _initialize_test_environment() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)

	# Create dummy files
	for i in range(30):
		var file_path := "%s/test_file_%02d.txt" % [_test_dir, i]
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		assert(file != null, "❌ Failed to create test file: %s" % file_path)
		file.store_string("Dummy content %d" % i)
		file.close()


## Cleans up all test files and folders.
func _cleanup_test_environment() -> void:
	if DirAccess.dir_exists_absolute(_test_dir):
		var dir := DirAccess.open(_test_dir)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(_test_dir.path_join(file_name))
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(_test_dir)


## Tests removal of excess files.
func test_excess_file_cleanup() -> void:
	print("🧪 Test: Excess File Cleanup")

	var cleaned = _audit_log_manager._remove_excess_files(
		_get_file_list(_test_dir),
		_test_dir,
		10
	)

	assert(cleaned.size() == 20, "❌ Expected 20 files cleaned by excess, got %d." % cleaned.size())
	print("✅ Excess file cleanup passed.")


## Tests removal of old files based on maximum days.
func test_old_file_cleanup() -> void:
	print("🧪 Test: Old File Cleanup")

	# Refresh environment
	_initialize_test_environment()

	var cleaned = _audit_log_manager._remove_old_files(
		_get_file_list(_test_dir),
		_test_dir,
		90
	)

	assert(cleaned.size() == 10, "❌ Expected 10 old files cleaned, got %d." % cleaned.size())
	print("✅ Old file cleanup passed.")


## Tests generation of cleanup report and signature.
func test_cleanup_report_generation() -> void:
	print("🧪 Test: Cleanup Report Generation")

	var dummy_files := ["user://test_auto_cleaner/dummy1.txt", "user://test_auto_cleaner/dummy2.txt"]

	var report := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"total_cleaned_files": dummy_files.size(),
		"files": []
	}

	for path in dummy_files:
		report["files"].append({
			"file_path": path,
			"deletion_timestamp": Time.get_datetime_string_from_system(true)
		})

	var json_path := "user://audit_logs/test_auto_cleaner_report.json"
	var xml_path := "user://audit_logs/test_auto_cleaner_report.xml"

	FileUtils.save_json(json_path, report)
	FileUtils.save_xml(xml_path, report)

	IntegrityChecker.save_file_signature(json_path)
	IntegrityChecker.save_file_signature(xml_path)

	assert(FileAccess.file_exists(json_path), "❌ JSON report not found.")
	assert(FileAccess.file_exists(xml_path), "❌ XML report not found.")

	assert(FileAccess.file_exists(json_path + ".sig"), "❌ Missing JSON signature.")
	assert(FileAccess.file_exists(xml_path + ".sig"), "❌ Missing XML signature.")

	print("✅ Cleanup report generation and signature passed.")


# --- Helper Methods ---


## Retrieves file list in given path.
##
## @param path String: Directory path.
## @return Array of filenames.
func _get_file_list(path: String) -> Array[String]:
	var dir := DirAccess.open(path)
	if dir == null:
		return []

	var files: Array[String] = []

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return files
