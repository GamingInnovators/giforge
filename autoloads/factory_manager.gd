extends Node


# --- Description ---
##
## FactoryManager.gd (Hardened, Encrypted, GLI-19 Compliant)
##
## Responsibilities:
## - Secure first-time initialization of system files and directories.
## - Device-locked guardian file with AES encryption and SHA-256 signing.
## - Factory generation of critical configuration exports.
## - Full audit logging and GLI-19 traceability.
##
## Must be registered as Autoload (singleton).
##


# --- Signals ---


# (Optional: you could later add signals like factory_initialized if needed)


# --- Constants ---


const EXPORT_ITEMS: Array[Dictionary] = [
	{ "prefix": "game_config", "snapshot_method": "_generate_default_game_config_snapshot", "formats": ["json", "xml", "csv"], "path": "user://exports/game/config/" },
	{ "prefix": "paytable", "snapshot_method": "_generate_default_paytable_snapshot", "formats": ["json", "xml"], "path": "user://exports/game/paytable/" },
	{ "prefix": "draw_history_template", "snapshot_method": "_generate_default_draw_history_snapshot", "formats": ["json"], "path": "user://exports/game/draw_history/" }
]

const CONFIG_VERSION: String = "1.0.0"
const GUARDIAN_LOCK_PATH: String = "user://system/system_guardian.bin"
const GUARDIAN_LOCK_SIG: String = GUARDIAN_LOCK_PATH + ".sig"
const GUARDIAN_LOCK_ZIP: String = "user://system/system_guardian_backup.zip"
const GUARDIAN_PASSWORD: String = "Secure@Game@Lock!"


# --- Public Variables ---


@export var factory_mode_enabled: bool = false
@export var force_regeneration: bool = false


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")


# --- Lifecycle Methods ---


## Initializes the FactoryManager and triggers first validation or generation.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager required.")
	assert(_settings_manager != null, "❌ SettingsManager required.")

	if not Engine.is_editor_hint():
		_prepare_initial_directories()
		_validate_or_create_guardian_lock()

	if factory_mode_enabled:
		_run_factory_generation()


# --- Guardian Lock Methods ---


## Prepares system-critical directories safely.
func _prepare_initial_directories() -> void:
	var paths := [
		"user://system/", "user://audit_logs/", "user://exports/",
		"user://saves/", "user://metadata/", "user://receipts/",
		"user://uploaded/", "user://manifest/", "user://backups/", "user://config/"
	]

	for path in paths:
		DirAccess.make_dir_recursive_absolute(path)

	_audit_log_manager.append_entry("📂 System directories prepared.")


## Validates or creates the encrypted guardian lock file.
func _validate_or_create_guardian_lock() -> void:
	if not FileAccess.file_exists(GUARDIAN_LOCK_PATH):
		_audit_log_manager.append_entry("🛡️ Guardian lock missing. Creating...")
		_create_guardian_lock()
	else:
		if not IntegrityChecker.validate_file_signature(GUARDIAN_LOCK_PATH):
			_audit_log_manager.append_entry("❌ Guardian lock invalid. Terminating system.")
			push_error("❌ Guardian lock tampered or missing signature.")
			get_tree().quit()

	_audit_log_manager.append_entry("🛡️ Guardian lock validated successfully.")


## Creates an encrypted and signed guardian lock file.
func _create_guardian_lock() -> void:
	var lock_data := {
		"created_at": Time.get_datetime_string_from_system(true),
		"system_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"engine_version": Engine.get_version_info()["string"],
		"hostname": OS.get_environment("HOSTNAME") if OS.has_environment("HOSTNAME") else "unknown"
	}

	var file := FileAccess.open_encrypted_with_pass(GUARDIAN_LOCK_PATH, FileAccess.WRITE, GUARDIAN_PASSWORD)
	assert(file != null, "❌ Failed to create encrypted guardian lock.")

	file.store_var(lock_data)
	file.close()

	IntegrityChecker.save_file_signature(GUARDIAN_LOCK_PATH)
	_create_guardian_backup()

	_audit_log_manager.append_entry("🔒 Guardian lock created and secured.")


## Creates a ZIP backup of the guardian lock file and signs it.
func _create_guardian_backup() -> void:
	var zip := ZIPPacker.new()

	if zip.open(GUARDIAN_LOCK_ZIP, ZIPPacker.APPEND_CREATE) == OK:
		zip.start_file(GUARDIAN_LOCK_PATH.get_file())
		zip.write_file(FileAccess.get_file_as_bytes(GUARDIAN_LOCK_PATH))
		zip.close()

	IntegrityChecker.save_file_signature(GUARDIAN_LOCK_ZIP)
	_audit_log_manager.append_entry("🛡️ Guardian lock backup created and signed.")


# --- Factory Generation Methods ---


## Executes the factory process to generate initial configurations.
func _run_factory_generation() -> void:
	print("🏭 Running Factory Generation...")

	for item in EXPORT_ITEMS:
		var export_path_base: String = item["path"]
		_prepare_export_directory(export_path_base)

		var prefix: String = item["prefix"]
		var snapshot_func: String = item["snapshot_method"]
		var formats: Array = item["formats"]

		var snapshot: Dictionary = call(snapshot_func)

		for format in formats:
			var export_path := "%s%s_%s.%s" % [export_path_base, prefix, CONFIG_VERSION, format]

			if FileAccess.file_exists(export_path) and not force_regeneration:
				push_warning("⚠️ Export already exists: %s (skipping)" % export_path)
				continue

			match format:
				"json":
					FileUtils.save_json(export_path, snapshot)
				"xml":
					FileUtils.save_xml(export_path, [snapshot])
				"csv":
					FileUtils.save_csv(export_path, [snapshot])
				_:
					push_error("❌ Unsupported export format: %s" % format)
					continue

			IntegrityChecker.save_file_signature(export_path)
			_audit_log_manager.append_entry("🔒 Export file signed: %s" % export_path)

	_generate_execution_report()
	_disable_factory_mode()

	print("✅ Factory Generation completed successfully.")


## Prepares the export directory if it doesn't exist.
func _prepare_export_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
		_audit_log_manager.append_entry("📂 Created export directory: %s" % path)


## Disables factory mode after successful generation.
func _disable_factory_mode() -> void:
	factory_mode_enabled = false
	force_regeneration = false
	_audit_log_manager.append_entry("🔒 Factory mode disabled.")


## Generates a structured execution report and signs it.
func _generate_execution_report() -> void:
	var report := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"config_version": CONFIG_VERSION,
		"items": []
	}

	for item in EXPORT_ITEMS:
		report["items"].append({
			"prefix": item["prefix"],
			"path": item["path"],
			"formats": item["formats"]
		})

	FileUtils.save_json("user://audit_logs/framework_factory_report.json", report)
	FileUtils.save_xml("user://audit_logs/framework_factory_report.xml", [report])

	IntegrityChecker.save_file_signature("user://audit_logs/framework_factory_report.json")
	IntegrityChecker.save_file_signature("user://audit_logs/framework_factory_report.xml")

	_audit_log_manager.append_entry("📝 Factory execution report generated and signed.")
