extends Node


# --- Description ---
##
## GlobalInitializerManager.gd (GLI-19 Compliant and Strict Order Controlled)
##
## Deterministic initializer for critical Autoloads (Singletons).
##
## Responsibilities:
## - Strict loading sequence to avoid dependency issues.
## - Manual invocation (NOT registered as Autoload itself).
## - Audit-safe boot process (prevents uninitialized singletons).
##
## Location: res://scripts/core/autoloads/global_initializer_manager.gd
##
## Must be called manually by Loading Screen, Main Menu, or System Bootstrap.


# --- Constants ---


## Strict initialization order for Autoloads.
const AUTOLOADS: Array[Dictionary] = [
	{ "name": "SettingsManager", "path": "res://scripts/core/autoloads/settings_manager.gd" },
	{ "name": "AuditLogManager", "path": "res://scripts/core/autoloads/audit_log_manager.gd" },
	{ "name": "ApiClientManager", "path": "res://scripts/core/autoloads/api_client_manager.gd" },
	{ "name": "RemoteUploaderManager", "path": "res://scripts/core/autoloads/remote_uploader_manager.gd" },
	{ "name": "ReceiptManager", "path": "res://scripts/core/autoloads/receipt_manager.gd" },
	{ "name": "MetadataLogManager", "path": "res://scripts/core/autoloads/metadata_log_manager.gd" },
	{ "name": "SessionManager", "path": "res://scripts/core/autoloads/session_manager.gd" },
	{ "name": "OtpManager", "path": "res://scripts/core/autoloads/otp_manager.gd" },
	{ "name": "BackupManager", "path": "res://scripts/core/autoloads/backup_manager.gd" },
	{ "name": "ManifestExportManager", "path": "res://scripts/core/autoloads/manifest_export_manager.gd" },
	{ "name": "CoreIntegrityCheckerManager", "path": "res://scripts/core/autoloads/core_integrity_checker_manager.gd" },
	{ "name": "CoreDocumentationManager", "path": "res://scripts/core/autoloads/core_documentation_manager.gd" },
	{ "name": "AutoCleanerManager", "path": "res://scripts/core/autoloads/auto_cleaner_manager.gd" },
	{ "name": "FactoryManager", "path": "res://scripts/core/autoloads/factory_manager.gd" }
]


# --- Private Variables ---


var _system_bootstrap := SystemBootstrap.new()


# --- Lifecycle Methods ---


## Called automatically when the node is ready.
##
## Immediately triggers controlled initialization of all Autoloads.
func _ready() -> void:
	_validate_dependencies()

	initialize_all()


# --- Private Methods ---


## Ensures all critical singletons are present before proceeding.
func _validate_dependencies() -> void:
	_system_bootstrap.validate_settings_signature()
	_system_bootstrap.ensure_required_directories()


## Initializes the session generator with fallback to local if API fails.
func _initialize_session() -> void:
	var use_external := _settings.get_setting("session_use_external", false)
	var external_url := _settings.get_setting("session_external_url", "")
	_session_id_generator.init(use_external, external_url)
	_audit_log.append_entry("🆔 SessionIDGenerator initialized (external=%s)." % str(use_external))


# --- Public Methods ---


## Initializes all autoloads in strict order.
##
## Must be called manually during the loading sequence.
func initialize_all() -> void:
	print("🚀 GlobalInitializerManager: Starting autoload initialization...")

	for autoload_info in AUTOLOADS:
		_initialize_singleton(autoload_info.name, autoload_info.path)

	print("✅ GlobalInitializerManager: All autoloads initialized successfully.")


# --- Private Methods ---


## Loads and registers an autoload if not already present.
##
## @param singleton_name String: Name to register.
## @param script_path String: Script path to instantiate.
func _initialize_singleton(singleton_name: String, script_path: String) -> void:
	assert(singleton_name != "", "❌ Singleton name must not be empty.")
	assert(script_path != "", "❌ Singleton path must not be empty.")

	if Engine.has_singleton(singleton_name):
		print("ℹ️ Singleton already exists: %s" % singleton_name)
		return

	var script := load(script_path)
	assert(script != null, "❌ Failed to load singleton script: %s" % script_path)

	var instance = script.new()
	instance.name = singleton_name

	get_tree().get_root().call_deferred("add_child", instance)
	Engine.register_singleton(singleton_name, instance)

	print("✅ Singleton registered: %s" % singleton_name)
