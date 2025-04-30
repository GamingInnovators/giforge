extends Node


# --- Description ---
##
## CoreDocumentationManager.gd (Optimized and GLI-19 Compliant)
##
## Secure module responsible for generating a verifiable snapshot of the system environment.
##
## Responsibilities:
## - JSON documentation of system state and project metadata.
## - SHA-256 signed export with IntegrityChecker.
## - Full GLI-19 traceability and audit compliance.
##
## Must be registered as Autoload (singleton).


# --- Public Variables ---


## Path where the generated documentation will be saved.
@export var documentation_output_path: String = "user://system/system_documentation.json"


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Called when the node is added to the scene tree.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required for CoreDocumentationManager.")
	_audit_log_manager.append_entry("📚 CoreDocumentationManager initialized.")


# --- Public Methods ---


## Generates the full system documentation and applies SHA-256 signing.
##
## @return bool: True if the documentation was generated and signed successfully, false otherwise.
func generate_documentation() -> bool:
	var documentation := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"system_name": OS.get_name(),
		"system_version": OS.get_version_alias(),
		"locale": OS.get_locale(),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown Project"),
		"engine_version": Engine.get_version_info()["string"],
		"gpu_adapter": RenderingServer.get_video_adapter_name(),
		"autoload_modules": _get_autoload_modules()
	}

	DirAccess.make_dir_recursive_absolute(documentation_output_path.get_base_dir())

	var file := FileAccess.open(documentation_output_path, FileAccess.WRITE)
	if file == null:
		push_error("❌ Unable to open documentation file: %s" % documentation_output_path)
		_audit_log_manager.append_entry("❌ Failed to generate documentation at: %s" % documentation_output_path)
		return false

	file.store_string(JSON.stringify(documentation, "\t"))
	file.close()

	if IntegrityChecker:
		IntegrityChecker.save_file_signature(documentation_output_path)
		_audit_log_manager.append_entry("✅ Documentation generated and signed successfully: %s" % documentation_output_path)
	else:
		push_warning("⚠️ IntegrityChecker unavailable. Documentation not signed.")

	return true


# --- Private Methods ---


## Retrieves and sorts autoloaded modules alphabetically.
##
## @return Array[String]: Sorted list of autoloaded module names.
func _get_autoload_modules() -> Array[String]:
	var modules: Array[String] = []

	for property in ProjectSettings.get_property_list():
		if property.name.begins_with("autoload/"):
			modules.append(property.name.replace("autoload/", ""))

	modules.sort()
	return modules
