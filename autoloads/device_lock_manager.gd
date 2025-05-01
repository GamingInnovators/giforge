extends Node
class_name DeviceLockManager


# --- Description ---
##
## DeviceLockManager.gd (GLI-19 Compliant - Immutable Device Guardian)
##
## Ensures execution only on the original storage device by:
## - Binding to physical serial/device ID
## - Registering and encrypting the initial lock (bin + sig + hash)
## - Verifying lock integrity periodically or on demand
## - Triggering violation signal on mismatch or tampering
##
## Must be registered as Autoload (singleton).


# --- Signals ---


## Emitted if the device fingerprint is invalid or mismatched.
signal device_lock_violation_detected(reason: String)


# --- Dependencies ---


@onready var _audit_log_manager := get_node_or_null("/root/AuditLogManager")
@onready var _settings_manager := get_node_or_null("/root/SettingsManager")


# --- Constants ---


const LOCK_FILE_PATH := "user://system/device_lock.bin"
const LOCK_SIG_PATH := LOCK_FILE_PATH + ".sig"
const LOCK_BACKUP := "user://system/device_lock_backup.zip"
const ENCRYPTION_PASS := "Lock@Game@Media@Secure!"


# --- Private State ---


var _expected_fingerprint: String = ""


# --- Lifecycle ---


func _ready() -> void:
	_validate_dependencies()

	if not FileAccess.file_exists(LOCK_FILE_PATH):
		_register_device_fingerprint()
	else:
		_validate_device_fingerprint()


# --- Public API ---


## Allows external systems (e.g., TaskScheduler) to trigger validation.
func check_integrity() -> void:
	_validate_device_fingerprint()

## Exposes current fingerprint for diagnostics.
func get_current_fingerprint() -> String:
	return _generate_device_fingerprint()


# --- Private Logic ---


func _validate_dependencies() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")
	assert(_settings_manager != null, "❌ SettingsManager is required.")


## Combines machine ID, OS, hostname and disk serial into fingerprint.
func _generate_device_fingerprint() -> String:
	var mac := OS.get_unique_id()
	var os_name := OS.get_name()
	var hostname := OS.get_environment("HOSTNAME")
	var disk_serial := _get_serial_via_udevadm("/dev/sda")

	var combined := mac + os_name + hostname + disk_serial
	return HashUtils.sha256_from_string(combined)


## Linux-only disk serial fetch (udevadm).
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


## Registers fingerprint securely.
func _register_device_fingerprint() -> void:
	_expected_fingerprint = _generate_device_fingerprint()

	var file := FileAccess.open_encrypted_with_pass(LOCK_FILE_PATH, FileAccess.WRITE, ENCRYPTION_PASS)
	assert(file != null, "❌ Failed to create encrypted device lock file.")

	file.store_var({
		"fingerprint": _expected_fingerprint,
		"created": Time.get_datetime_string_from_system(true)
	})
	file.close()

	IntegrityChecker.save_file_signature(LOCK_FILE_PATH)
	_create_lock_backup()

	_audit_log_manager.append_entry("🔐 DeviceLock registered and secured.")


## Validates fingerprint and halts if tampering is detected.
func _validate_device_fingerprint() -> void:
	if not IntegrityChecker.validate_file_signature(LOCK_FILE_PATH):
		_audit_log_manager.append_entry("❌ DeviceLock signature invalid.")
		emit_signal("device_lock_violation_detected", "Signature mismatch")
		get_tree().quit()
		return

	var file := FileAccess.open_encrypted_with_pass(LOCK_FILE_PATH, FileAccess.READ, ENCRYPTION_PASS)
	assert(file != null, "❌ Failed to read encrypted device lock.")

	var data: Dictionary = file.get_var()
	file.close()

	_expected_fingerprint = data.get("fingerprint", "")
	var current := _generate_device_fingerprint()

	if current != _expected_fingerprint:
		_audit_log_manager.append_entry("⛔ DeviceLock mismatch. System halt.")
		emit_signal("device_lock_violation_detected", "Fingerprint mismatch")
		get_tree().quit()
	else:
		_audit_log_manager.append_entry("✅ DeviceLock validated successfully.")


## Creates ZIP backup of lock file and signs it.
func _create_lock_backup() -> void:
	var zip := ZIPPacker.new()

	if zip.open(LOCK_BACKUP, ZIPPacker.APPEND_CREATE) == OK:
		zip.start_file(LOCK_FILE_PATH.get_file())
		zip.write_file(FileAccess.get_file_as_bytes(LOCK_FILE_PATH))
		zip.close()

		IntegrityChecker.save_file_signature(LOCK_BACKUP)
		_audit_log_manager.append_entry("📦 DeviceLock backup created and signed.")
