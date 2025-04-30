extends Node
class_name TestGlobalInitializerManager


# --- Description ---
##
## TestGlobalInitializerManager.gd
##
## Automated validation for GlobalInitializerManager singleton loading.
##
## Responsibilities:
## - Verifies that all critical singletons are properly initialized.
## - Generates structured audit results (JSON + XML) with SHA-256 signature.
##
## Must be called manually during development or QA phases.
##
## Location: res://scripts/core/tests/test_global_initializer_manager.gd


# --- Constants ---


const REPORT_PATH_JSON := "user://audit_logs/global_initializer_test_report.json"
const REPORT_PATH_XML := "user://audit_logs/global_initializer_test_report.xml"


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Called when the node is ready.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")

	await _execute_test()


# --- Private Methods ---


## Executes the full singleton initialization validation.
func _execute_test() -> void:
	print("🧪 Running GlobalInitializerManager Test...")

	var test_results: Array[Dictionary] = []
	var all_passed := true

	# Load GlobalInitializerManager script temporarily.
	var global_initializer_script := load("res://scripts/core/autoloads/global_initializer_manager.gd")
	assert(global_initializer_script != null, "❌ Failed to load GlobalInitializerManager script.")

	var global_initializer = global_initializer_script.new()
	global_initializer.initialize_all()

	await get_tree().process_frame  # Wait one frame for deferred singletons to attach

	for autoload_info in global_initializer.AUTOLOADS:
		var autoload_name: String = autoload_info.name

		var passed := Engine.has_singleton(autoload_name)
		if not passed:
			all_passed = false
			_audit_log_manager.append_entry("❌ Missing singleton after initialization: %s" % autoload_name)
		else:
			print("✅ Singleton initialized successfully: %s" % autoload_name)

		test_results.append({
			"singleton_name": autoload_name,
			"initialized": passed
		})

	_save_test_report(test_results)

	if all_passed:
		_audit_log_manager.append_entry("✅ GlobalInitializerManager Test PASSED: All singletons present.")
	else:
		_audit_log_manager.append_entry("❌ GlobalInitializerManager Test FAILED: Some singletons are missing.")

	print("🧪 GlobalInitializerManager Test completed.")


## Saves the structured test report as JSON and XML, with signature.
##
## @param results Array of test entries.
func _save_test_report(results: Array[Dictionary]) -> void:
	var report := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"test_suite": "GlobalInitializerManager",
		"total_singletons": results.size(),
		"results": results
	}

	DirAccess.make_dir_recursive_absolute("user://audit_logs/")

	FileUtils.save_json(REPORT_PATH_JSON, report)
	FileUtils.save_xml(REPORT_PATH_XML, [report])

	if FileAccess.file_exists(REPORT_PATH_JSON):
		IntegrityChecker.save_file_signature(REPORT_PATH_JSON)
	if FileAccess.file_exists(REPORT_PATH_XML):
		IntegrityChecker.save_file_signature(REPORT_PATH_XML)

	_audit_log_manager.append_entry("📝 GlobalInitializerManager Test report saved: %d singletons checked." % results.size())
