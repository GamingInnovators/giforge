extends Node


# --- Description ---
##
## test_system_bootstrap_manager.gd (Test Suite for SystemBootstrapManager)
##
## Validates integrity and directory bootstrapping logic.
## Location: res://scripts/core/tests/test_system_bootstrap_manager.gd
##


# --- Dependencies ---


@onready var _bootstrap := Engine.get_singleton("SystemBootstrap")
@onready var _settings := Engine.get_singleton("SettingsManager")
@onready var _audit := Engine.get_singleton("AuditLogManager")


# --- Lifecycle ---


func _ready() -> void:
	assert(_bootstrap != null, "❌ SystemBootstrap singleton missing.")
	assert(_settings != null, "❌ SettingsManager missing.")
	assert(_audit != null, "❌ AuditLogManager missing.")

	print("🧪 Starting SystemBootstrapManager test suite...")

	test_validate_settings_signature()
	test_ensure_required_directories()
	test_validate_schema_xsd()
	test_validate_all_critical_signatures()
	test_check_rng_state_file()

	print("✅ All SystemBootstrapManager tests completed.")


# --- Tests ---


func test_validate_settings_signature() -> void:
	print("🔍 Testing: validate_settings_signature")
	_bootstrap.validate_settings_signature()


func test_ensure_required_directories() -> void:
	print("📂 Testing: ensure_required_directories")
	_bootstrap.ensure_required_directories()

	for path in _bootstrap.REQUIRED_DIRECTORIES:
		assert(DirAccess.dir_exists_absolute(path), "❌ Required directory missing: %s" % path)
	print("✅ All required directories exist.")


func test_validate_schema_xsd() -> void:
	print("📘 Testing: validate_schema_xsd")
	_bootstrap.validate_schema_xsd()


func test_validate_all_critical_signatures() -> void:
	print("🔐 Testing: validate_all_critical_signatures")
	_bootstrap.validate_all_critical_signatures()


func test_check_rng_state_file() -> void:
	print("🎲 Testing: check_rng_state_file")
	_bootstrap.check_rng_state_file()
