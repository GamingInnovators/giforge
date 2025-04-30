extends Node
class_name TestCoreIntegrityCheckerManager


# --- Description ---
##
## TestCoreIntegrityCheckerManager.gd (Optimized, GLI-19 Audit-Ready)
##
## Performs full automated test of CoreIntegrityCheckerManager.
##
## Responsibilities:
## - Manual integrity check execution.
## - Report structure validation.
## - Export of results in JSON and XML with digital signatures.
## - GLI-19 compliant audit trail.
##
## Must be manually instantiated (NOT Autoload).
##


# --- Private Variables ---


@onready var _integrity_checker := Engine.get_singleton("CoreIntegrityCheckerManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")

var _result_report: Dictionary = {}
var _timestamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")


# --- Lifecycle Methods ---


## Initializes and starts the test automatically.
func _ready() -> void:
	assert(_integrity_checker != null, "❌ CoreIntegrityCheckerManager is required.")
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")

	_integrity_checker.integrity_check_completed.connect(_on_integrity_check_completed)

	print_debug("🧪 Starting TestCoreIntegrityCheckerManager...")
	await _execute_test()


# --- Private Methods ---


## Executes the full testing sequence.
func _execute_test() -> void:
	print_debug("🔍 Performing forced integrity check...")
	_integrity_checker.perform_integrity_check()

	await get_tree().create_timer(1.0).timeout

	_validate_report()
	_export_results()
	_log_test_completion()

	print_debug("✅ TestCoreIntegrityCheckerManager completed successfully.")


## Callback when the integrity check completes.
##
## @param report Dictionary: Result from integrity checking.
func _on_integrity_check_completed(report: Dictionary) -> void:
	_result_report = report
	print_debug("📝 Integrity report captured.")


## Validates the captured report structure.
func _validate_report() -> void:
	assert(_result_report.has("checked"), "❌ Missing 'checked' field.")
	assert(_result_report.has("passed"), "❌ Missing 'passed' field.")
	assert(_result_report.has("failed"), "❌ Missing 'failed' field.")
	assert(_result_report.has("missing"), "❌ Missing 'missing' field.")
	assert(_result_report.has("errors"), "❌ Missing 'errors' field.")

	assert(typeof(_result_report.checked) == TYPE_INT, "❌ 'checked' must be int.")
	assert(typeof(_result_report.passed) == TYPE_INT, "❌ 'passed' must be int.")
	assert(typeof(_result_report.failed) == TYPE_INT, "❌ 'failed' must be int.")
	assert(typeof(_result_report.missing) == TYPE_INT, "❌ 'missing' must be int.")
	assert(typeof(_result_report.errors) == TYPE_ARRAY, "❌ 'errors' must be an Array.")

	print_debug("✅ Report structure validated.")


## Exports test results to secure JSON and XML formats.
func _export_results() -> void:
	var output_dir := "user://test_results/"
	DirAccess.make_dir_recursive_absolute(output_dir)

	var json_path := "%stest_core_integrity_checker_%s.json" % [output_dir, _timestamp]
	var xml_path := "%stest_core_integrity_checker_%s.xml" % [output_dir, _timestamp]

	FileUtils.save_json(json_path, _result_report)
	FileUtils.save_xml(xml_path, [_result_report])

	if FileAccess.file_exists(json_path):
		IntegrityChecker.save_file_signature(json_path)
	if FileAccess.file_exists(xml_path):
		IntegrityChecker.save_file_signature(xml_path)

	print_debug("📄 Test results exported: %s and %s" % [json_path, xml_path])


## Appends an audit log entry for test completion.
func _log_test_completion() -> void:
	_audit_log_manager.append_entry("🧪 TestCoreIntegrityCheckerManager: Test finished and exported results (timestamp: %s)." % _timestamp)
