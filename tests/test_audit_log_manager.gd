extends Node
class_name TestAuditLogManager


# --- Description ---
##
## TestAuditLogManager.gd
##
## Automated test suite for AuditLogManager functionality.
##
## Responsibilities:
## - Test basic lifecycle (init, append, finalize).
## - Validate file generation and signatures.
## - Simulate export and rotation.
##
## Not registered as Autoload.


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Initializes and runs tests.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager must be loaded.")

	print("🧪 Starting AuditLogManager tests...")

	await _test_append_entry()
	await _test_export_log()
	await _test_log_rotation()

	print("✅ All AuditLogManager tests completed successfully.")


# --- Test Methods ---


## Tests appending a normal entry to the audit log.
func _test_append_entry() -> void:
	var initial_count := _count_log_entries()

	_audit_log_manager.append_entry("🧪 Test: append simple entry.")

	await get_tree().create_timer(0.5).timeout  # Give time for file I/O

	var after_count := _count_log_entries()

	assert(after_count == initial_count + 1, "❌ Audit entry append failed.")
	print("✅ Test: append_entry passed.")


## Tests exporting audit log to JSON.
func _test_export_log() -> void:
	var export_path := "user://test_exports/audit_export_test.json"

	DirAccess.make_dir_recursive_absolute("user://test_exports/")

	_audit_log_manager.export_log("json", export_path, false)

	await get_tree().create_timer(0.5).timeout  # Ensure disk write complete

	assert(FileAccess.file_exists(export_path), "❌ Exported audit log file missing.")
	assert(FileAccess.file_exists("%s.sig" % export_path), "❌ Exported signature file missing.")
	print("✅ Test: export_log passed.")


## Tests rotating audit log manually (forces rotation).
func _test_log_rotation() -> void:
	_audit_log_manager.finalize_session()

	await get_tree().create_timer(0.5).timeout  # Allow rotation process

	# Check if at least one zipped audit backup exists
	var dir := DirAccess.open("user://audit_logs/")
	assert(dir != null, "❌ Cannot open audit_logs directory.")

	dir.list_dir_begin()
	var found_backup := false

	var file := dir.get_next()
	while file != "":
		if file.ends_with(".zip"):
			found_backup = true
			break
		file = dir.get_next()

	dir.list_dir_end()

	assert(found_backup, "❌ No zipped audit backup found after rotation.")
	print("✅ Test: log_rotation passed.")


# --- Helper Methods ---


## Counts how many entries exist in current audit log.
##
## @return int: Number of entries.
func _count_log_entries() -> int:
	var entries = _audit_log_manager._load_entries()
	return entries.size()
