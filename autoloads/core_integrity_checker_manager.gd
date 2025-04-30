extends Node


# --- Description ---
##
## TestCoreIntegrityCheckerManager.gd (Enhanced GLI-19 Exportable Version)
##
## Automated test suite for CoreIntegrityCheckerManager with full audit export.
##
## Responsibilities:
## - Run forced manual integrity checks.
## - Export results as signed JSON and XML.
## - Emit structured audit logs.
##
## Located at: res://scripts/core/tests/test_core_integrity_checker_manager.gd
##
## Must be manually instantiated (NOT Autoload).


# --- Private Variables ---


@onready var _integrity_checker := Engine.get_singleton("CoreIntegrityCheckerManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")

var _last_report: Dictionary = {}
var _timestamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")


# --- Lifecycle Methods ---


## Initializes the test environment.
func _ready() -> void:
	assert(_integrity_checker != null, "❌ CoreIntegrityCheckerManager is missing.")
	assert(_audit_log_manager != null, "❌ AuditLogManager is missing.")

	_integrity_checker.integrity_check_completed.connect(_on_integrity_check_completed)

	print_debug("✅ TestCoreIntegrityCheckerManager initialized.")
	await _run_tests()


# --- Private Methods ---


## Runs the full set of tests.
func _run_tests() -> void:
	print_debug("🧪 Starting CoreIntegrityCheckerManager test...")

	_integrity_checker.perform_integrity_check()

	await get_tree().create_timer(1.0).timeout

	_validate_report_structure()
	_export_test_results()

	_audit_log_manager.append_entry("🧪 TestCoreIntegrityCheckerManager: Test completed and results exported.")

	print_debug("✅ TestCoreIntegrityCheckerManager finished.")


## Callback when integrity check completes.
##
## @param report Dictionary: Integrity check report.
func _on_integrity_check_completed(report: Dictionary) -> void:
	_last_report = report
	print_debug("📝 Integrity Check Report Captured: %s" % JSON.stringify(report, "\t"))


## Validates report structure correctness.
func _validate_report_structure() -> void:
	assert(_last_report.has("checked"), "❌ Missing 'checked' field.")
	assert(_last_report.has("passed"), "❌ Missing 'passed' field.")
	assert(_last_report.has("failed"), "❌ Missing 'failed' field.")
	assert(_last_report.has("missing"), "❌ Missing 'missing' field.")
	assert(_last_report.has("errors"), "❌ Missing 'errors' field.")
	assert(typeof(_last_report.errors) == TYPE_ARRAY, "❌ 'errors' must be Array.")
	assert(typeof(_last_report.checked) == TYPE_INT, "❌ 'checked' must be int.")
	assert(typeof(_last_report.passed) == TYPE_INT, "❌ 'passed' must be int.")
	assert(typeof(_last_report.failed) == TYPE_INT, "❌ 'failed' must be int.")
	assert(typeof(_last_report.missing) == TYPE_INT, "❌ 'missing' must be int.")

	print_debug("✅ Report structure validated successfully.")


## Exports test results to JSON and XML, and signs them.
func _export_test_results() -> void:
	var output_dir := "user://test_results/"
	DirAccess.make_dir_recursive_absolute(output_dir)

	var json_path := "%stest_core_integrity_checker_manager_%s.json" % [output_dir, _timestamp]
	var xml_path := "%stest_core_integrity_checker_manager_%s.xml" % [output_dir, _timestamp]

	FileUtils.save_json(json_path, _last_report)
	FileUtils.save_xml(xml_path, [_last_report])

	if FileAccess.file_exists(json_path):
		IntegrityChecker.save_file_signature(json_path)
	if FileAccess.file_exists(xml_path):
		IntegrityChecker.save_file_signature(xml_path)

	_audit_log_manager.append_entry("📋 Test results exported and signed: %s" % json_path)
	_audit_log_manager.append_entry("📋 Test results exported and signed: %s" % xml_path)

	print_debug("✅ Test results exported to JSON and XML successfully.")
