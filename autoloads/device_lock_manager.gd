extends Node
class_name DeviceLockManager


# --- Description ---
##
## DeviceLockManager.gd (GLI-19 Compliant - Immutable Device Guardian)
##
## Ensures that the game runs only on the original storage device and environment.
##
## Responsibilities:
## - Lock to original hardware/mídia via serial hash
## - First-time secure registration (bin + signature + hash)
## - Periodic validation
## - Audit-safe and tamper detection
##
## Must be registered as Autoload (singleton).


# --- Dependencies ---


@onready var _audit_log_manager := get_node_or_null("/root/AuditLogManager")
@onready var _settings_manager := get_node_or_null("/root/SettingsManager")


# --- Constants ---


const LOCK_FILE_PATH := "user://system/device_lock.bin"
const LOCK_SIG_PATH := LOCK_FILE_PATH + ".sig"
const LOCK_BACKUP := "user://system/device_lock_backup.zip"
const ENCRYPTION_PASS := "Lock@Game@Media@Secure!"


# --- Private Variables ---


var _expected_fingerprint: String = ""


# --- Lifecycle ---


func _ready() -> void:
	_validate_dependencies()

	if not FileAccess.file_exists(LOCK_FILE_PATH):
		_register_device_fingerprint()
	else:
		_validate_device_fingerprint()


# --- Public Methods ---


## Public method to trigger device check manually (used by TaskScheduler).
func check_integrity() -> void:
	_validate_device_fingerprint()


# --- Private Methods ---


## Validates required autoloads.
func _validate_dependencies() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")
	assert(_settings_manager != null, "❌ SettingsManager is required.")


## Generates a fingerprint string combining serials and hashes.
func _generate_device_fingerprint() -> String:
	var mac := OS.get_unique_id()
	var os_name := OS.get_name()
	var hostname := OS.get_environment("HOSTNAME")
	var disk_serial := _get_serial_via_udevadm("/dev/sda") # Linux-only fallback
	var combined := mac + os_name + hostname + disk_serial

	return HashUtils.sha256_from_string(combined)


func _get_serial_via_udevadm(device_path := "/dev/sda") -> String:
	if OS.get_name() != "Linux":
		return "unknown"

	var output := []
	var result := OS.execute("udevadm", ["info", "--query=all", "--name=" + device_path], output)

	if result == OK and output.size() > 0:
		for line in output:
			if line.find("ID_SERIAL_SHORT") != -1:
				return line.strip_edges().split("=")[1]
	return "unknown"


## Registers and signs the current device fingerprint.
func _register_device_fingerprint() -> void:
	_expected_fingerprint = _generate_device_fingerprint()

	var file := FileAccess.open_encrypted_with_pass(LOCK_FILE_PATH, FileAccess.WRITE, ENCRYPTION_PASS)
	assert(file != null, "❌ Failed to create encrypted lock file.")

	file.store_var({ "fingerprint": _expected_fingerprint, "created": Time.get_datetime_string_from_system(true) })
	file.close()

	IntegrityChecker.save_file_signature(LOCK_FILE_PATH)
	_create_lock_backup()

	_audit_log_manager.append_entry("🔐 DeviceLock registered successfully.")


## Validates the device fingerprint and halts the game if it was cloned.
func _validate_device_fingerprint() -> void:
	if not IntegrityChecker.validate_file_signature(LOCK_FILE_PATH):
		_audit_log_manager.append_entry("❌ DeviceLock signature mismatch.")
		push_error("🔒 Critical: DeviceLock signature invalid.")
		get_tree().quit()

	var file := FileAccess.open_encrypted_with_pass(LOCK_FILE_PATH, FileAccess.READ, ENCRYPTION_PASS)
	assert(file != null, "❌ Failed to read encrypted lock file.")

	var data: Dictionary = file.get_var()
	file.close()

	_expected_fingerprint = data.get("fingerprint", "")
	var current_fingerprint := _generate_device_fingerprint()

	if current_fingerprint != _expected_fingerprint:
		_audit_log_manager.append_entry("⛔ DeviceLock mismatch detected. Execution halted.")
		push_error("🔒 Device environment has changed. Game terminated.")
		get_tree().quit()

	_audit_log_manager.append_entry("✅ DeviceLock integrity verified.")


## Creates a backup ZIP of the lock file.
func _create_lock_backup() -> void:
	var zip := ZIPPacker.new()

	if zip.open(LOCK_BACKUP, ZIPPacker.APPEND_CREATE) == OK:
		zip.start_file(LOCK_FILE_PATH.get_file())
		zip.write_file(FileAccess.get_file_as_bytes(LOCK_FILE_PATH))
		zip.close()

		IntegrityChecker.save_file_signature(LOCK_BACKUP)
		_audit_log_manager.append_entry("🛡️ DeviceLock backup created and signed.")
