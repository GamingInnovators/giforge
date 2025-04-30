extends Node


# --- Description ---
##
## ReceiptManager.gd (GLI-19 Compliant & Hardened)
##
## Secure session receipt manager with support for:
## - Persistent receipt storage and signing
## - Automated uploads with retry and backup
## - JSON, CSV, and XML exports
## - Full audit trail and tamper-proof design
##
## Must be registered as Autoload (singleton).


# --- Signals ---


## Emitted when a receipt is finalized and stored.
##
## @param session_id String: Finalized session identifier.
## @param receipt_path String: Full path of stored receipt.
signal receipt_finalized(session_id: String, receipt_path: String)


# --- Constants ---


const RECEIPT_EXTENSION: String = ".json"
const RECEIPT_PREFIX: String = "receipt_"


# --- Dependencies ---


@onready var _api_client_manager := Engine.get_singleton("ApiClientManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")
@onready var _remote_uploader_manager := Engine.get_singleton("RemoteUploaderManager")


# --- Private Variables ---


var _receipt_dir: String = "user://receipts/"
var _backup_dir: String = "user://uploaded/"
var _upload_url: String = ""
var _bearer_token: String = ""
var _upload_interval_sec: int = 600
var _auto_upload_enabled: bool = true
var _max_retries: int = 3

var _session_id: String = ""
var _session_data: Dictionary = {}
var _retry_queue: Dictionary = {}

var _upload_timer: Timer


# --- Lifecycle Methods ---


## Initializes the ReceiptManager.
func _ready() -> void:
	assert(_audit_log_manager, "❌ AuditLogManager not loaded.")
	assert(_settings_manager, "❌ SettingsManager not loaded.")
	assert(_api_client_manager, "❌ ApiClientManager not loaded.")
	assert(_remote_uploader_manager, "❌ RemoteUploaderManager not loaded.")

	_load_settings()
	_prepare_directories()
	_validate_existing_receipts()

	if _auto_upload_enabled:
		_initialize_upload_timer()

	_audit_log_manager.append_entry("🧾 ReceiptManager initialized.")


# --- Configuration Methods ---


## Loads receipt manager settings from SettingsManager.
func _load_settings() -> void:
	_receipt_dir = _settings_manager.get_setting("receipt_directory", "user://receipts/")
	_backup_dir = _settings_manager.get_setting("receipt_backup_directory", "user://uploaded/")
	_upload_url = _settings_manager.get_setting("upload_url", "")
	_bearer_token = _settings_manager.get_setting("upload_bearer_token", "")
	_upload_interval_sec = _settings_manager.get_setting("upload_interval_sec", 600)
	_auto_upload_enabled = _settings_manager.get_setting("auto_upload_enabled", true)
	_max_retries = _settings_manager.get_setting("max_upload_retries", 3)

	assert(_receipt_dir != "", "❌ Receipt directory cannot be empty.")
	assert(_backup_dir != "", "❌ Backup directory cannot be empty.")


## Ensures all required directories exist.
func _prepare_directories() -> void:
	DirAccess.make_dir_recursive_absolute(_receipt_dir)
	DirAccess.make_dir_recursive_absolute(_backup_dir)


## Initializes and starts the upload timer.
func _initialize_upload_timer() -> void:
	_upload_timer = Timer.new()
	_upload_timer.one_shot = false
	_upload_timer.wait_time = _upload_interval_sec
	_upload_timer.timeout.connect(_on_upload_timer_timeout)
	add_child(_upload_timer)
	_upload_timer.start()

	_audit_log_manager.append_entry("🧾 Upload timer started (Interval: %d seconds)." % _upload_interval_sec)


# --- Session Management ---


## Starts a new receipt session.
##
## @param session_id String: Session identifier.
func start_session(session_id: String) -> void:
	assert(session_id != "", "❌ Session ID must not be empty.")

	_session_id = session_id
	_session_data = {
		"session_id": session_id,
		"timestamp_start": Time.get_datetime_string_from_system(true),
		"total_bets": 0.0,
		"total_wins": 0.0,
		"rounds_played": 0,
		"balance_start": 0.0,
		"balance_end": 0.0
	}

	_audit_log_manager.append_entry("🧾 New receipt session started: %s" % session_id)


## Finalizes the active receipt session.
##
## @param session_id String: Must match the started session.
func finalize_session(session_id: String) -> void:
	assert(session_id != "", "❌ Session ID must not be empty.")
	assert(session_id == _session_id, "❌ Session ID mismatch.")

	_session_data["timestamp_end"] = Time.get_datetime_string_from_system(true)
	var receipt_path := _get_receipt_path(session_id)

	var file := FileAccess.open(receipt_path, FileAccess.WRITE)
	assert(file, "❌ Cannot open receipt file: %s" % receipt_path)

	file.store_string(JSON.stringify(_session_data, "\t"))
	file.close()

	assert(FileAccess.file_exists(receipt_path), "❌ Receipt file not found after writing.")

	IntegrityChecker.save_file_signature(receipt_path)

	emit_signal("receipt_finalized", session_id, receipt_path)
	_audit_log_manager.append_entry("✅ Receipt finalized and signed: %s" % session_id)


# --- Data Recording ---


## Records a bet in the current session.
##
## @param amount float: Bet amount.
func record_bet(amount: float) -> void:
	assert(amount >= 0.0, "❌ Bet amount must be positive.")
	_session_data["total_bets"] += amount
	_session_data["rounds_played"] += 1


## Records a win in the current session.
##
## @param amount float: Win amount.
func record_win(amount: float) -> void:
	assert(amount >= 0.0, "❌ Win amount must be positive.")
	_session_data["total_wins"] += amount


## Sets the starting balance.
func set_initial_balance(balance: float) -> void:
	assert(balance >= 0.0, "❌ Balance must be non-negative.")
	_session_data["balance_start"] = balance


## Sets the ending balance.
func set_final_balance(balance: float) -> void:
	assert(balance >= 0.0, "❌ Balance must be non-negative.")
	_session_data["balance_end"] = balance


# --- Upload Management ---


## Uploads all pending receipts.
func _on_upload_timer_timeout() -> void:
	await _upload_all_receipts()


## Uploads receipts with retry management.
func _upload_all_receipts() -> void:
	var dir := DirAccess.open(_receipt_dir)
	if dir == null:
		push_warning("⚠️ Cannot open receipt directory.")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(RECEIPT_EXTENSION):
			var full_path := _receipt_dir.path_join(file_name)
			var retries: int = _retry_queue.get(full_path, 0)

			if retries > _max_retries:
				_audit_log_manager.append_entry("⛔ Max retries exceeded for: %s" % file_name)
			else:
				var result: int = await _remote_uploader_manager.upload_file_auto(full_path)
				if result == OK:
					var backup_path := _move_to_backup(full_path)
					if backup_path != "":
						IntegrityChecker.save_file_signature(backup_path)
						_audit_log_manager.append_entry("✅ Receipt uploaded and backed up: %s" % backup_path)
					_retry_queue.erase(full_path)
				else:
					_retry_queue[full_path] = retries + 1
					_audit_log_manager.append_entry("❌ Upload failed: %s (Retry %d/%d)" % [
						file_name, retries, _max_retries
					])

		file_name = dir.get_next()

	dir.list_dir_end()


## Moves receipt to backup folder after upload.
func _move_to_backup(path: String) -> String:
	assert(path != "", "❌ Path cannot be empty.")

	var file_name := path.get_file()
	var backup_path := _backup_dir.path_join(file_name)

	if DirAccess.rename_absolute(path, backup_path) == OK:
		return backup_path
	else:
		push_warning("⚠️ Failed to move receipt to backup: %s" % file_name)
		return ""


# --- Export Methods ---


## Exports all session receipts in selected format.
##
## @param format String: "json", "csv", or "xml".
## @param session_id String: Target session.
## @param target_path String: Output file path.
func export_receipts(format: String, session_id: String, target_path: String) -> void:
	assert(session_id != "", "❌ Session ID cannot be empty.")
	assert(format in ["json", "csv", "xml"], "❌ Invalid export format: %s" % format)

	var entries := _get_entries_by_session(session_id)

	match format:
		"json":
			FileUtils.save_json(target_path, entries)
		"csv":
			FileUtils.save_csv(target_path, entries)
		"xml":
			FileUtils.save_xml(target_path, entries)

	IntegrityChecker.save_file_signature(target_path)
	_audit_log_manager.append_entry("📤 Receipt export completed: %s" % target_path)


## Retrieves all receipts for the session.
func _get_entries_by_session(session_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var dir := DirAccess.open(_receipt_dir)

	if dir == null:
		return entries

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(RECEIPT_EXTENSION):
			var full_path := _receipt_dir.path_join(file_name)
			var content := FileAccess.get_file_as_string(full_path)
			var parsed: Dictionary = JSON.parse_string(content)
			if typeof(parsed) == TYPE_DICTIONARY and parsed.get("session_id", "") == session_id:
				entries.append(parsed)

		file_name = dir.get_next()

	dir.list_dir_end()

	return entries


## Returns the full receipt path for the session ID.
func _get_receipt_path(session_id: String) -> String:
	return "%s%s%s%s" % [_receipt_dir, RECEIPT_PREFIX, session_id, RECEIPT_EXTENSION]


## Validates signatures for all existing receipts.
func _validate_existing_receipts() -> void:
	var dir := DirAccess.open(_receipt_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(RECEIPT_EXTENSION):
			var full_path := _receipt_dir.path_join(file_name)
			if not IntegrityChecker.validate_file_signature(full_path):
				_audit_log_manager.append_entry("❌ Integrity check failed: %s" % full_path)
		file_name = dir.get_next()

	dir.list_dir_end()
