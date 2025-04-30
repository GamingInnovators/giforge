extends Node
class_name TestFactoryManager


# --- Description ---
##
## TestFactoryManager.gd
##
## Unit and functional testing for FactoryManager secure initialization.
##
## Responsibilities:
## - Validate guardian lock creation and signing.
## - Validate factory export generation for all formats.
## - Validate audit logging integrity.
##
## Fully GLI-19 Audit Trail Compatible.
##


# --- Constants ---


const GUARDIAN_LOCK_PATH := "user://system/system_guardian.bin"
const GUARDIAN_LOCK_SIG := "user://system/system_guardian.bin.sig"
const EXPORT_DIRECTORIES := [
	"user://exports/game/config/",
	"user://exports/game/paytable/",
	"user://exports/game/draw_history/"
]


# --- Private Variables ---


@onready var _factory_manager := Engine.get_singleton("FactoryManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Called automatically when the test node is ready.
func _ready() -> void:
	assert(_factory_manager != null, "❌ FactoryManager must be autoloaded.")
	assert(_audit_log_manager != null, "❌ AuditLogManager must be autoloaded.")

	_run_tests()


# --- Public Test Methods ---


## Executes the full suite of FactoryManager tests.
func _run_tests() -> void:
	print("🧪 Starting FactoryManager secure initialization tests...")

	_test_guardian_lock_creation()
	_test_exports_generated()
	_test_audit_log_entries()

	print("✅ FactoryManager secure initialization tests completed.")


# --- Private Test Methods ---


## Validates that the Guardian Lock was correctly created and signed.
func _test_guardian_lock_creation() -> void:
	print("🔒 Testing guardian lock file...")

	assert(FileAccess.file_exists(GUARDIAN_LOCK_PATH), "❌ Guardian lock file missing.")
	assert(FileAccess.file_exists(GUARDIAN_LOCK_SIG), "❌ Guardian lock signature file missing.")
	assert(IntegrityChecker.validate_file_signature(GUARDIAN_LOCK_PATH), "❌ Guardian lock signature validation failed.")

	print("✅ Guardian lock file created and verified successfully.")


## Validates that all expected export files are generated and signed.
func _test_exports_generated() -> void:
	print("🗂️ Testing factory-generated export files...")

	for directory in EXPORT_DIRECTORIES:
		var dir := DirAccess.open(directory)
		assert(dir != null, "❌ Failed to open export directory: %s" % directory)

		dir.list_dir_begin()
		var file := dir.get_next()

		var export_found := false

		while file != "":
			if not dir.current_is_dir():
				var file_path: String = directory.path_join(file)
				export_found = true
				assert(FileAccess.file_exists(file_path), "❌ Export file missing: %s" % file_path)
				assert(IntegrityChecker.validate_file_signature(file_path), "❌ Export file signature invalid: %s" % file_path)
			file = dir.get_next()

		dir.list_dir_end()

		assert(export_found, "❌ No export files found in: %s" % directory)

	print("✅ Factory exports created and validated successfully.")


## Validates that the audit log contains expected entries.
func _test_audit_log_entries() -> void:
	print("📝 Testing audit log entries...")

	var entries := _load_audit_log_entries()

	var keywords := ["Guardian lock", "export", "signed", "Factory mode disabled", "execution report"]

	for keyword in keywords:
		var found := false
		for entry in entries:
			if keyword in str(entry.get("message", "")):
				found = true
				break

		assert(found, "❌ Audit log missing entry containing keyword: %s" % keyword)

	print("✅ Audit log contains all expected entries.")


# --- Helper Methods ---


## Loads the audit log file and parses entries.
##
## @return Array[Dictionary]: Parsed audit entries.
func _load_audit_log_entries() -> Array[Dictionary]:
	var audit_log_path: String = _audit_log_manager._log_path

	assert(FileAccess.file_exists(audit_log_path), "❌ Audit log file missing.")

	var content := FileAccess.get_file_as_string(audit_log_path)
	var entries: Array[Dictionary] = []

	for line in content.split("\n", false):
		var parsed: Dictionary = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			entries.append(parsed)

	return entries
