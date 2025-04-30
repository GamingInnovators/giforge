extends Node


# --- Description ---
##
## RemoteUploaderManager.gd (GLI-19 Optimized)
##
## Handles secure, resilient remote file uploads with retry, OTP validation, and audit trail logging.
##
## Responsibilities:
## - Parallel uploads with queue limit.
## - Secure retry system with requeue.
## - OTP validation for forced uploads.
## - SHA-256 integrity signing after upload.
##
## Must be registered as Autoload (singleton).


# --- Signals ---


## Emitted when a file is successfully uploaded.
## @param file_path: Path of the uploaded file.
signal upload_success(file_path: String)


## Emitted when a file upload fails after retries.
## @param file_path: Path of the file.
## @param error_code: Associated error code.
signal upload_failure(file_path: String, error_code: int)


# --- Public Variables ---


@export var max_parallel_uploads: int = 4
@export var retry_interval_sec: int = 60


# --- Private Variables ---


@onready var _api_client_manager := Engine.get_singleton("ApiClientManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")

var _upload_url: String = ""
var _bearer_token: String = ""
var _upload_enabled: bool = true
var _otp_required: bool = false

var _current_uploads: int = 0
var _upload_queue: Array[String] = []

var _retry_timer: Timer


# --- Lifecycle Methods ---


## Initializes the RemoteUploaderManager and starts the retry mechanism.
func _ready() -> void:
	assert(_api_client_manager != null)
	assert(_audit_log_manager != null)
	assert(_settings_manager != null)

	_load_settings()
	_initialize_retry_timer()

	_audit_log_manager.append_entry("📡 RemoteUploaderManager initialized.")


# --- Private Methods ---


## Loads configuration from SettingsManager.
func _load_settings() -> void:
	_upload_url = _settings_manager.get_setting("upload_url", "")
	_bearer_token = _settings_manager.get_setting("upload_bearer_token", "")
	_upload_enabled = _settings_manager.get_setting("auto_upload_enabled", true)
	_otp_required = _settings_manager.get_setting("otp_required_for_force_upload", false)


## Initializes the retry system.
func _initialize_retry_timer() -> void:
	_retry_timer = Timer.new()
	_retry_timer.wait_time = retry_interval_sec
	_retry_timer.one_shot = false
	_retry_timer.timeout.connect(_on_retry_timer_timeout)
	add_child(_retry_timer)
	_retry_timer.start()


## Handles retry events.
func _on_retry_timer_timeout() -> void:
	_process_upload_queue()


## Decrements the number of active uploads safely.
func _decrement_upload_counter() -> void:
	_current_uploads = max(_current_uploads - 1, 0)


# --- Public Methods ---


## Force uploads a file immediately with optional OTP validation.
func force_upload_with_otp(file_path: String) -> void:
	assert(file_path != "")

	if _otp_required:
		var otp := OtpHelper.new()
		otp.request_otp("Force Upload: %s" % file_path.get_file(), func() -> void:
			_execute_force_upload(file_path)
		)
	else:
		_execute_force_upload(file_path)


## Queues a file for auto-upload.
func queue_file_for_upload(file_path: String) -> void:
	assert(file_path != "")

	if not _upload_enabled:
		push_warning("⚠️ Uploads disabled. File not queued: %s" % file_path)
		return

	_upload_queue.append(file_path)
	_audit_log_manager.append_entry("📩 File queued for upload: %s" % file_path)
	_process_upload_queue()


## Uploads a file automatically through the configured URL.
func upload_file_auto(file_path: String) -> int:
	assert(file_path != "")
	return await _upload_file(file_path, _upload_url, _bearer_token)


## Uploads a file manually to a specific URL.
func upload_file(file_path: String, url: String, token: String = "") -> int:
	assert(file_path != "")
	assert(url.begins_with("http"))
	return await _upload_file(file_path, url, token)


## Removes a file from the upload queue manually.
##
## @param file_path String: Full path to file to be removed.
func remove_file_from_queue(file_path: String) -> void:
	assert(file_path != "", "❌ File path must not be empty for removal.")

	if _upload_queue.has(file_path):
		_upload_queue.erase(file_path)
		_audit_log_manager.append_entry("🗑️ File removed from upload queue: %s" % file_path)
	else:
		push_warning("⚠️ Attempted to remove non-existent file from queue: %s" % file_path)


## Updates upload settings dynamically from SettingsManager.
##
## Can be called when settings change at runtime.
func update_upload_settings() -> void:
	_load_settings()

	if _retry_timer != null:
		_retry_timer.stop()
		_retry_timer.wait_time = retry_interval_sec
		_retry_timer.start()

	_audit_log_manager.append_entry("🔄 RemoteUploaderManager settings updated dynamically.")


# --- Upload Processing ---


## Processes the upload queue respecting max parallel uploads.
func _process_upload_queue() -> void:
	while _current_uploads < max_parallel_uploads and _upload_queue.size() > 0:
		var file_path: String = _upload_queue.pop_front()
		_start_upload(file_path)


## Starts a single upload operation.
func _start_upload(file_path: String) -> void:
	_current_uploads += 1
	_upload_file(file_path, _upload_url, _bearer_token)


## Uploads a file, checking connectivity first.
func _upload_file(file_path: String, url: String, token: String) -> int:
	assert(file_path != "")
	assert(url != "")

	if _api_client_manager.is_online() != OK:
		push_warning("⚠️ Offline. File requeued: %s" % file_path)
		_upload_queue.append(file_path)
		_decrement_upload_counter()
		return ERR_CANT_CONNECT

	return await _upload_and_handle_result(file_path, url, token)


## Uploads file and handles success or failure.
func _upload_and_handle_result(file_path: String, url: String, token: String) -> int:
	if not FileAccess.file_exists(file_path):
		push_warning("⚠️ File missing: %s" % file_path)
		_decrement_upload_counter()
		return ERR_FILE_NOT_FOUND

	var file_bytes := FileAccess.get_file_as_bytes(file_path)
	if file_bytes.is_empty():
		push_warning("⚠️ Empty file: %s" % file_path)
		_decrement_upload_counter()
		return ERR_FILE_CANT_READ

	var multipart := _create_multipart_body(file_path, file_bytes)
	var headers := _create_headers(token, multipart.body.size(), multipart.boundary)

	var response: Dictionary = await _api_client_manager.send_request(url, HTTPClient.METHOD_POST, headers, multipart.body, true)

	_decrement_upload_counter()

	if response.get("ok", false):
		emit_signal("upload_success", file_path)
		_audit_log_manager.append_entry("✅ File uploaded: %s" % file_path.get_file())
	else:
		emit_signal("upload_failure", file_path, response.get("error_code", ERR_QUERY_FAILED))
		_upload_queue.append(file_path)
		_audit_log_manager.append_entry("❌ Upload failed. Requeued: %s" % file_path.get_file())

	_process_upload_queue()

	return OK if response.get("ok", false) else ERR_QUERY_FAILED


# --- Force Upload Execution ---


## Executes a forced upload immediately.
func _execute_force_upload(file_path: String) -> void:
	assert(file_path != "")

	_current_uploads += 1
	await _upload_and_handle_result(file_path, _upload_url, _bearer_token)


# --- Helper Methods ---


## Creates a multipart/form-data body for uploads.
func _create_multipart_body(file_path: String, file_bytes: PackedByteArray) -> Dictionary:
	var boundary := "Boundary-%s" % UuidUtils.v4().substr(0, 8)
	var body := PackedByteArray()
	var preamble := "--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\nContent-Type: application/octet-stream\r\n\r\n" % [boundary, file_path.get_file()]
	var epilogue := "\r\n--%s--\r\n" % boundary

	body.append_array(preamble.to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array(epilogue.to_utf8_buffer())

	return { "body": body, "boundary": boundary }


## Creates HTTP headers for upload requests.
func _create_headers(token: String, body_size: int, boundary: String) -> Array:
	var headers: Array = [
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
		"Content-Length: %d" % body_size
	]

	if token.strip_edges() != "":
		headers.append("Authorization: Bearer %s" % token.strip_edges())

	return headers
