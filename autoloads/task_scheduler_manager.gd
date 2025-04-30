extends Node


# --- Description ---
##
## TaskSchedulerManager.gd (GLI-19 Compliant)
##
## Centralized and secure task scheduler for periodic execution of maintenance modules.
## Supports auto backup, cleaning, device lock validation, integrity check and log uploads.
##
## Responsibilities:
## - Configurable timer-based execution using SettingsManager
## - Modular execution with error isolation
## - Full audit logging, SHA-256 structured entries
## - Shutdown on critical violations (e.g., device fingerprint mismatch)
##
## Must be registered as Autoload (singleton)
## Location: res://autoloads/task_scheduler_manager.gd
## Dependencies: AuditLogManager, SettingsManager, DeviceLockManager, etc.


# --- Signals ---


## Emitted when a critical device violation is detected.
## Must be handled externally to trigger shutdown or lock mechanisms.
signal device_lock_violation_detected(reason: String)

## Signal emitted after secure reset is completed successfully.
signal task_scheduler_reset_done(log_data: Dictionary)


# --- Constants ---


## Defines the maximum number of retry attempts per task (GLI-19 failsafe pattern).
const MAX_RETRIES := 3
const RESET_COOLDOWN_SECONDS := 300  # Minimum interval between resets (5 min)

const DEFAULT_INTERVALS := {
	"backup_sec": 3600,
	"cleanup_sec": 1800,
	"device_lock_check_sec": 600,
	"upload_sec": 600,
	"integrity_check_sec": 900
}

const TASKS: Array[Dictionary] = [
	{ "name": "device_check", "interval_key": "task_interval_device_check_sec" },
	{ "name": "integrity_check", "interval_key": "task_interval_integrity_check_sec" },
	{ "name": "auto_backup", "interval_key": "task_interval_auto_backup_sec" },
	{ "name": "auto_clean", "interval_key": "task_interval_auto_clean_sec" },
	{ "name": "auto_upload", "interval_key": "task_interval_auto_upload_sec" }
]


# --- Dependencies ---


@onready var _settings_manager := get_node_or_null("/root/SettingsManager")
@onready var _audit_log_manager := get_node_or_null("/root/AuditLogManager")
@onready var _device_lock_manager := get_node_or_null("/root/DeviceLockManager")
@onready var _backup_manager := get_node_or_null("/root/BackupManager")
@onready var _auto_cleaner_manager := get_node_or_null("/root/AutoCleanerManager")
@onready var _remote_uploader_manager := get_node_or_null("/root/RemoteUploaderManager")
@onready var _core_integrity_checker_manager := get_node_or_null("/root/CoreIntegrityCheckerManager")
@onready var _system_bootstrap_manager := get_node_or_null("/root/SystemBootstrapManager")


# --- Private Variables ---


var _last_reset_timestamp := 0
var _retry_counters: Dictionary = {}
var _safe_mode_enabled: bool = false
var _timers := {
	"backup": Timer.new(),
	"cleanup": Timer.new(),
	"device_lock_check": Timer.new(),
	"upload": Timer.new(),
	"integrity_check": Timer.new()
}


# --- Lifecycle ---


## Initializes all core dependencies, timers, and validates bootstrap order.
##
## Must be executed on engine boot via autoload.
func _ready() -> void:
	assert(_settings_manager != null, "❌ SettingsManager not found.")
	assert(_audit_log_manager != null, "❌ AuditLogManager not found.")
	assert(_device_lock_manager != null, "❌ DeviceLockManager not found.")
	assert(_backup_manager != null, "❌ BackupManager not found.")
	assert(_remote_uploader_manager != null, "❌ RemoteUploaderManager not found.")
	assert(_auto_cleaner_manager != null, "❌ AutoCleanerManager not found.")
	assert(_core_integrity_checker_manager != null, "❌ CoreIntegrityCheckerManager not found.")
	assert(_system_bootstrap_manager != null, "❌ SystemBootstrapManager not found.")

	if not _system_bootstrap_manager.is_boot_sequence_complete():
		push_warning("⏳ Waiting for SystemBootstrapManager to complete sequence.")
		await _system_bootstrap_manager.bootstrap_completed
		_audit_log_manager.append_entry("✅ SystemBootstrap completed. Continuing initialization.")

	_register_and_configure_timers()
	_bind_external_signals()
	_start_all_timers()

	_audit_log_manager.append_entry("🕒 TaskSchedulerManager: Initialization completed. All timers active.")


# --- Signal Handlers ---


## Binds signals from external components (e.g., device lock violation).
##
## Ensures secure reaction to real-time device mismatch detection.
func _bind_external_signals() -> void:
	if _device_lock_manager and _device_lock_manager.has_signal("device_lock_violation_detected"):
		_device_lock_manager.device_lock_violation_detected.connect(_on_device_lock_violation)

	_audit_log_manager.append_entry("🔗 TaskSchedulerManager: Signals connected to DeviceLockManager.")


## Handles a device fingerprint violation signal.
##
## @param reason String: Descriptive reason for system log and shutdown.
func _on_device_lock_violation(reason: String) -> void:
	_audit_log_manager.append_entry("🚨 Security violation detected: %s" % reason)

	# Optional delay for log persistence before shutdown
	await get_tree().create_timer(2.0).timeout

	push_error("💥 Critical security violation. Shutting down...")
	get_tree().quit()


# --- Timer Configuration ---


## Configures internal timers using settings or fallback values.
##
## Timers are non-autostart and one-shot disabled by default.
func _register_and_configure_timers() -> void:
	for task_name in _timers.keys():
		var timer: Timer = _timers[task_name]
		timer.name = "Timer_%s" % task_name
		timer.autostart = false
		timer.one_shot = false

		var setting_key := "%s_interval_sec" % task_name
		var interval: int = _settings_manager.get_setting(setting_key, DEFAULT_INTERVALS.get(setting_key))

		timer.wait_time = interval
		timer.timeout.connect(_on_timer_timeout.bind(task_name))

		add_child(timer)


## Starts all configured timers.
##
## Timers will run indefinitely, each triggering its associated task.
func _start_all_timers() -> void:
	for timer in _timers.values():
		timer.start()

	_audit_log_manager.append_entry("▶️ TaskSchedulerManager: All timers started.")


# --- Timer Callbacks ---


## Routes timer expiration to its respective task handler.
##
## @param task_name String: Identifier for the expired timer.
func _on_timer_timeout(task_name: String) -> void:
	match task_name:
		"backup":
			_handler_backup()
		"cleanup":
			_handler_cleanup()
		"upload":
			_handler_upload()
		"device_lock_check":
			_handler_device_lock_check()
		"integrity_check":
			_handler_integrity_check()
		_:
			push_warning("⚠️ Unknown timer triggered: %s" % task_name)


# --- Task Handlers ---


## Handles secure device lock validation with structured logging.
##
## Emits signal and appends violation entry if the fingerprint does not match.
##
## @param log_data Dictionary: Log container to be extended with status and metadata.
## @return bool: Whether the current device is valid.
func _handle_device_lock_check(log_data: Dictionary) -> bool:
	assert(log_data != null, "❌ Log data must be provided for device lock check.")
	assert(_device_lock_manager != null, "❌ DeviceLockManager dependency missing.")

	var result: bool = _device_lock_manager.validate_device_lock()
	var timestamp := Time.get_datetime_string_from_system()

	log_data["timestamp"] = timestamp
	log_data["status"] = result if result else "violation"
	log_data["note"] = "Device lock validated." if result else "Device fingerprint mismatch"

	if not result:
		emit_signal("device_lock_violation_detected", log_data["note"])
		_audit_log_manager.append_entry("🔒 Device lock violation detected.")
	else:
		_audit_log_manager.append_entry("✅ Device lock validated successfully.")

	_audit_log_manager.append_structured_log(log_data, "device_lock_check")

	return result


## Executes the backup routine.
func _handler_backup() -> void:
	_run_task(_backup_manager.create_backup, "backup")


## Triggers cleanup routine through AutoCleanerManager.
func _handler_cleanup() -> void:
	_run_task(_auto_cleaner_manager._ready, "cleanup")


## Triggers remote upload logic using RemoteUploaderManager.
func _handler_upload() -> void:
	_run_task(_remote_uploader_manager.update_upload_settings, "upload")


## Device fingerprint validation.
##
## Emits violation signal and logs structured entry on failure.
func _handler_device_lock_check() -> void:
	var log_data := {
		"timestamp": Time.get_datetime_string_from_system(),
		"task": "device_lock_check"
	}

	var result := _handle_device_lock_check(log_data)

	log_data["status"] = "ok" if result else "violation"
	if not result:
		emit_signal("device_lock_violation_detected", "Device fingerprint mismatch")

	_audit_log_manager.append_structured_log(log_data, "device_lock_check")


## Executes system-wide integrity check using the checker manager.
##
## Logs structured validation outcome and detailed errors if any.
func _handler_integrity_check() -> void:
	if not _core_integrity_checker_manager:
		push_warning("⚠️ CoreIntegrityCheckerManager unavailable.")
		return

	var result: Dictionary = _core_integrity_checker_manager.validate_all()

	var log_data := {
		"task": "integrity_check",
		"timestamp": Time.get_datetime_string_from_system(),
		"result": result.get("status", "unknown"),
		"validated_items": result.get("validated_items", []),
		"errors": result.get("errors", [])
	}

	_audit_log_manager.append_structured_log(log_data, "integrity_check")

	if log_data.result != "valid":
		_audit_log_manager.append_entry("❌ Integrity check failed.")
	else:
		_audit_log_manager.append_entry("✅ System integrity check passed.")


# --- Task Execution Wrapper ---


## Generic wrapper for task execution with retry, isolation, logging and auto-pause.
##
## @param task_func Callable: Reference to the method to invoke.
## @param task_name String: Task identifier.
func _run_task(task_func: Callable, task_name: String) -> void:
	if not task_func.is_valid():
		push_warning("⚠️ Invalid task function: %s" % task_name)
		return

	if not _retry_counters.has(task_name):
		_retry_counters[task_name] = 0

	var timestamp := Time.get_datetime_string_from_system()
	var log_data := {
		"timestamp": timestamp,
		"task": task_name,
		"status": "unknown",
		"retry_attempts": _retry_counters[task_name],
		"max_retries": MAX_RETRIES
	}

	var success: bool = task_func.call()

	if success:
		log_data.status = "success"
		_retry_counters[task_name] = 0
		_audit_log_manager.append_entry("✅ Task %s completed." % task_name)
	else:
		_retry_counters[task_name] += 1
		log_data.status = "failure"
		_audit_log_manager.append_entry("❌ Task %s failed (Retry %d/%d)." % [
			task_name, _retry_counters[task_name], MAX_RETRIES
		])

		# Pause if too many failures
		if _retry_counters[task_name] >= MAX_RETRIES and _timers.has(task_name):
			var timer: Timer = _timers[task_name]
			timer.stop()
			_audit_log_manager.append_entry("⛔ Timer '%s' paused due to max retries." % task_name)

	_audit_log_manager.append_structured_log(log_data, "task_scheduler")


# --- Snapshot Export ---


## Exports a full signed snapshot of task scheduler state.
##
## Includes hash, session ID, game/device ID. GLI-19 compliant.
func export_scheduler_snapshot() -> void:
	var snapshot := {
		"timestamp": Time.get_datetime_string_from_system(),
		"session_id": _settings_manager.get_session_id(),
		"game_id": _settings_manager.get_game_id(),
		"device_id": NativeDeviceInfo.get_device_id(),
		"tasks": get_task_status_report()
	}

	var snapshot_json := JSON.stringify(snapshot)
	var signature := IntegrityChecker.generate_signature(snapshot_json)
	snapshot["signature"] = signature

	_audit_log_manager.append_structured_log(snapshot, "task_scheduler_snapshot")
	_audit_log_manager.append_entry("🔐 Snapshot exported and signed with SHA-256.")

	if _audit_log_manager.has_method("export_csv_log"):
		_audit_log_manager.export_csv_log("task_scheduler_snapshot")

	if _audit_log_manager.has_method("export_xml_log"):
		_audit_log_manager.export_xml_log("task_scheduler_snapshot")

	if _remote_uploader_manager and _remote_uploader_manager.has_method("notify_snapshot_exported"):
		_remote_uploader_manager.notify_snapshot_exported("task_scheduler_snapshot")

	print("📤 Snapshot exported with hash: %s" % signature)


# --- Status Report Methods ---


## Returns the current execution status of all managed timers.
##
## Used for audits, snapshot exports, and runtime dashboards.
##
## @return Dictionary: Status of all task timers (running state, wait time, time left).
func get_task_status_report() -> Dictionary:
	var report := {}

	for task_name in _timers.keys():
		var timer: Timer = _timers[task_name]
		report[task_name] = {
			"running": not timer.is_stopped(),
			"wait_time_sec": timer.wait_time,
			"time_left_sec": timer.time_left
		}

	return report


# --- Public Control Methods ---


## Pauses all task timers safely.
##
## Recommended during shutdown, maintenance, or audits.
func pause_all_tasks() -> void:
	for timer in _timers.values():
		if not timer.is_stopped():
			timer.stop()

	_audit_log_manager.append_entry("⏸️ TaskSchedulerManager: All timers paused.")


## Resumes all previously paused timers.
##
## Useful post-maintenance or on resume.
func resume_all_tasks() -> void:
	for timer in _timers.values():
		if timer.is_stopped():
			timer.start()

	_audit_log_manager.append_entry("▶️ TaskSchedulerManager: All timers resumed.")


# --- Device Lock Secure Validation ---


## Manually triggers the secure validation of device fingerprint.
##
## Emits signal and logs if validation fails.
func validate_device_lock() -> void:
	var is_valid := NativeDeviceInfo.validate_signature()

	if not is_valid:
		var reason := "Device lock integrity check failed."
		emit_signal("device_lock_violation_detected", reason)

		var violation_log := {
			"timestamp": Time.get_datetime_string_from_system(),
			"device_id": NativeDeviceInfo.get_device_id(),
			"status": "violation",
			"reason": reason
		}

		_audit_log_manager.append_entry("❌ Device Lock Violation: " + reason)
		_audit_log_manager.append_structured_log(violation_log, "device_lock_violations")

		if _audit_log_manager.has_method("export_csv_log"):
			_audit_log_manager.export_csv_log("device_lock_violations")

		if _audit_log_manager.has_method("export_xml_log"):
			_audit_log_manager.export_xml_log("device_lock_violations")


# --- Fallback Task Configuration Loader ---


## Loads fallback configuration if SettingsManager is unavailable.
##
## Returns: Dictionary with intervals.
func _load_task_intervals_with_fallback() -> Dictionary:
	var fallback_path := "res://configs/task_scheduler_defaults.json"

	if _settings_manager:
		return {
			"backup_sec": _settings_manager.get_setting("backup_interval_sec", DEFAULT_INTERVALS["backup_sec"]),
			"cleanup_sec": _settings_manager.get_setting("cleanup_interval_sec", DEFAULT_INTERVALS["cleanup_sec"]),
			"device_lock_check_sec": _settings_manager.get_setting("device_lock_check_interval_sec", DEFAULT_INTERVALS["device_lock_check_sec"]),
			"upload_sec": _settings_manager.get_setting("upload_interval_sec", DEFAULT_INTERVALS["upload_sec"]),
			"integrity_check_sec": _settings_manager.get_setting("integrity_check_interval_sec", DEFAULT_INTERVALS["integrity_check_sec"])
		}

	var file := FileAccess.open(fallback_path, FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		file.close()

		var parsed: Dictionary = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			_audit_log_manager.append_entry("📄 Loaded fallback scheduler config.")
			return parsed

	_audit_log_manager.append_entry("⚠️ Failed to load fallback config. Using hardcoded defaults.")
	return DEFAULT_INTERVALS.duplicate()


# --- Secure Reset Methods ---


## Resets all task timers and logs the action with SHA-256 signature.
##
## @param reason String: Justification or origin of the reset.
## @param include_signature bool: Include signature in log?
## @param callback Callable: Optional callback after reset.
func reset_all_tasks(reason: String = "manual_reset", include_signature: bool = true, callback: Callable = Callable()) -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")

	var snapshot := {
		"timestamp": Time.get_datetime_string_from_system(),
		"trigger_reason": reason,
		"session_id": _settings_manager.get_session_id(),
		"game_id": _settings_manager.get_game_id(),
		"device_id": NativeDeviceInfo.get_device_id(),
		"reset_type": "manual",
		"tasks": get_task_status_report()
	}

	if include_signature:
		var snapshot_json := JSON.stringify(snapshot)
		snapshot["signature"] = IntegrityChecker.generate_signature(snapshot_json)

	_audit_log_manager.append_structured_log(snapshot, "task_scheduler_resets")
	_audit_log_manager.append_entry("🔁 All task intervals reset manually (%s)." % reason)

	if _audit_log_manager.has_method("export_csv_log"):
		_audit_log_manager.export_csv_log("task_scheduler_resets")

	if _audit_log_manager.has_method("export_xml_log"):
		_audit_log_manager.export_xml_log("task_scheduler_resets")

	if _remote_uploader_manager and _remote_uploader_manager.has_method("notify_reset_event"):
		_remote_uploader_manager.notify_reset_event("task_scheduler_resets")

	_register_and_configure_timers()
	_start_all_timers()

	if callback.is_valid():
		callback.call()


## Exports task logs within a date range and signs the output.
##
## @param start_date String: Format YYYY-MM-DD.
## @param end_date String: Format YYYY-MM-DD.
func export_logs_by_date_range(start_date: String, end_date: String, log_type: String = "task_scheduler_snapshot") -> void:
	assert(start_date != "", "❌ Start date must not be empty.")
	assert(end_date != "", "❌ End date must not be empty.")

	var filtered_logs := _audit_log_manager.get_logs_between_dates(log_type, start_date, end_date)

	if filtered_logs.is_empty():
		_audit_log_manager.append_entry("⚠️ No logs found from %s to %s (type: %s)." % [start_date, end_date, log_type])
		return

	var export_filename := "%s_export_%s_to_%s" % [log_type, start_date, end_date]

	_audit_log_manager.export_logs_to_csv(log_type, export_filename, filtered_logs)
	_audit_log_manager.export_logs_to_xml(log_type, export_filename, filtered_logs)

	_audit_log_manager.append_entry("📦 Exported %d '%s' logs from %s to %s." % [
		filtered_logs.size(), log_type, start_date, end_date
	])


## Validates all session snapshot signatures for tampering.
##
## Recommended at shutdown or audit checkpoints.
func verify_all_session_signatures() -> void:
	var session_logs: Dictionary = _audit_log_manager.load_all_structured_logs("task_scheduler_snapshot")
	if session_logs.is_empty():
		_audit_log_manager.append_entry("⚠️ No session snapshots found for validation.")
		return

	var invalid_sessions := []

	for log_entry in session_logs:
		if not log_entry.has("signature") or not log_entry.has("timestamp"):
			continue

		var raw: Dictionary = log_entry.duplicate()
		var signature: String = raw["signature"]
		raw.erase("signature")

		if not IntegrityChecker.verify_signature(JSON.stringify(raw), signature):
			invalid_sessions.append({
				"timestamp": raw.get("timestamp", "unknown"),
				"session_id": raw.get("session_id", "unknown")
			})

	if invalid_sessions.size() > 0:
		_audit_log_manager.append_entry("❌ Signature validation failed for %d sessions." % invalid_sessions.size())
		_audit_log_manager.append_structured_log({ "violations": invalid_sessions }, "signature_verification_failures")
	else:
		_audit_log_manager.append_entry("✅ All session snapshot signatures validated successfully.")


## Reactivates a specific task and resets its retry count.
##
## @param task_name String: Name of the task.
func reset_task(task_name: String) -> void:
	assert(_timers.has(task_name), "❌ Invalid task name: %s" % task_name)

	var timer: Timer = _timers[task_name]
	if timer.is_stopped():
		timer.start()
		_audit_log_manager.append_entry("🔄 Task '%s' reactivated." % task_name)

	_retry_counters[task_name] = 0

	_audit_log_manager.append_structured_log({
		"timestamp": Time.get_datetime_string_from_system(),
		"task": task_name,
		"action": "reset",
		"status": "success"
	}, "task_scheduler_admin")
