extends Node
class_name TestCoreDocumentationManager


# --- Description ---
##
## TestCoreDocumentationManager.gd
##
## Test module for validating the CoreDocumentationManager functionality.
##
## Responsibilities:
## - Test secure documentation generation.
## - Validate file existence and SHA-256 integrity.
## - Structured, GLI-19 compliant, minimal.
##
## Not Autoloaded. Must be manually instantiated for testing.


# --- Private Variables ---


@onready var _doc_manager := Engine.get_singleton("CoreDocumentationManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Initializes the test module.
func _ready() -> void:
	assert(_doc_manager != null, "❌ CoreDocumentationManager not found.")
	assert(_audit_log_manager != null, "❌ AuditLogManager not found.")

	print_debug("🧪 TestCoreDocumentationManager initialized.")

	_run_documentation_test()


# --- Private Methods ---


## Executes the full documentation generation test sequence.
func _run_documentation_test() -> void:
	_audit_log_manager.append_entry("🧪 Starting CoreDocumentationManager test.")

	var success: bool = _doc_manager.generate_documentation()
	assert(success, "❌ Documentation generation failed.")

	var path: String = _doc_manager.documentation_output_path

	assert(FileAccess.file_exists(path), "❌ Documentation file not found: %s" % path)
	assert(IntegrityChecker.validate_file_signature(path), "❌ Documentation file signature invalid: %s" % path)

	_audit_log_manager.append_entry("✅ CoreDocumentationManager test passed successfully.")
	print_debug("✅ CoreDocumentationManager test passed.")
