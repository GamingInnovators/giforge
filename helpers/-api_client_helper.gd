extends Node
class_name APIClientHelper


# --- Description ---
##
## APIClientHelper.gd (GLI-19 Certified)
##
## Helper for secure, audit-logged and retryable network operations.
## Extends ApiClientManager with high-level operations like:
## - File download/upload
## - Signature validation
## - Endpoint pinging
## - Recovery strategy
##
## Must be instantiated manually (NOT an Autoload).
## Location: res://scripts/core/helpers/api_client_helper.gd
##


# --- Private Dependencies ---


@onready var _api_client_manager := Engine.get_singleton("ApiClientManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Ensures dependencies are correctly loaded.
func _ready() -> void:
	assert(_api_client_manager != null, "❌ Missing ApiClientManager.")
	assert(_audit_log_manager != null, "❌ Missing AuditLogManager.")


# --- Public Methods ---


## Downloads a file from a URL with optional signature validation.
##
## @param url String: Remote file URL.
## @param destination_path String: Local destination path.
## @param validate_signature bool: Whether to verify .sig after download.
## @param retries int: Retry attempts for network error.
## @return Dictionary: { "success": bool, "error": String }
func download_file(url: String, destination_path: String, validate_signature: bool = false, retries: int = 2) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid download URL.")
	assert(destination_path != "", "❌ Destination path must not be empty.")

	var response: Dictionary = await _api_client_manager.get_json(url, [], retries)
	if not response.get("ok", false):
		_audit_log_manager.append_entry("❌ Failed to download: %s" % url)
		return { "success": false, "error": "Download failed from: %s" % url }

	var file := FileAccess.open(destination_path, FileAccess.WRITE)
	if file == null:
		_audit_log_manager.append_entry("❌ Failed to write file: %s" % destination_path)
		return { "success": false, "error": "Unable to save file to: %s" % destination_path }

	file.store_buffer(response.get("data", "").to_utf8_buffer())
	file.close()

	if validate_signature and not IntegrityChecker.validate_file_signature(destination_path):
		_audit_log_manager.append_entry("❌ Signature invalid: %s" % destination_path)
		return { "success": false, "error": "Signature mismatch for: %s" % destination_path }

	_audit_log_manager.append_entry("✅ File downloaded: %s" % destination_path)
	return { "success": true }


## Downloads a file and its .sig, validates both for integrity.
##
## @param url String: File URL.
## @param destination_path String: Where to save.
## @param retries int: Retry attempts.
## @return Dictionary: { "success": bool, "error": String }
func download_file_with_signature(url: String, destination_path: String, retries: int = 2) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid download URL.")
	assert(destination_path != "", "❌ Destination path must not be empty.")

	var file_result := await download_file(url, destination_path, false, retries)
	if not file_result.get("success", false):
		return file_result

	var sig_url := "%s.sig" % url
	var sig_path := "%s.sig" % destination_path

	var sig_result: Dictionary = await _api_client_manager.get_json(sig_url, [], retries)
	if not sig_result.get("ok", false):
		_audit_log_manager.append_entry("⚠️ Missing signature for: %s" % url)
		return { "success": false, "error": "Signature file not available." }

	var sig_file := FileAccess.open(sig_path, FileAccess.WRITE)
	if sig_file == null:
		_audit_log_manager.append_entry("❌ Failed to save .sig: %s" % sig_path)
		return { "success": false, "error": "Unable to write signature file." }

	sig_file.store_buffer(sig_result.get("data", "").to_utf8_buffer())
	sig_file.close()

	if not IntegrityChecker.validate_file_signature(destination_path):
		_audit_log_manager.append_entry("❌ Integrity check failed: %s" % destination_path)
		return { "success": false, "error": "Integrity validation failed." }

	_audit_log_manager.append_entry("✅ File and .sig validated: %s" % destination_path)
	return { "success": true }


## Uploads a JSON payload to remote server.
##
## @param url String: Target API URL.
## @param payload Dictionary: JSON to post.
## @param retries int: Retry count.
## @return Dictionary: Standard result from ApiClientManager.
func upload_json(url: String, payload: Dictionary, retries: int = 2) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid URL.")
	assert(typeof(payload) == TYPE_DICTIONARY, "❌ Payload must be a Dictionary.")

	var result: Dictionary = await _api_client_manager.post_json(url, payload, [], retries)

	if result.get("ok", false):
		_audit_log_manager.append_entry("✅ JSON uploaded to: %s" % url)
	else:
		_audit_log_manager.append_entry("❌ Failed to upload JSON to: %s" % url)

	return result


## Uploads a binary file.
##
## @param url String: API URL.
## @param file_path String: File path to upload.
## @param retries int: Retry count.
## @return Dictionary: Upload result.
func upload_file(url: String, file_path: String, retries: int = 2) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid URL.")
	assert(FileAccess.file_exists(file_path), "❌ File not found: %s" % file_path)

	var data := FileAccess.get_file_as_bytes(file_path)
	if data.is_empty():
		_audit_log_manager.append_entry("❌ Skipping empty file: %s" % file_path)
		return { "ok": false, "error_code": ERR_FILE_CORRUPT, "error_message": "Empty file." }

	var result: Dictionary = await _api_client_manager.post_bytes(url, data, [], retries)

	if result.get("ok", false):
		_audit_log_manager.append_entry("✅ File uploaded to: %s" % url)
	else:
		_audit_log_manager.append_entry("❌ File upload failed to: %s" % url)

	return result


## Sends a GET request to check endpoint availability.
##
## @param url String: Endpoint URL.
## @return bool: True if available.
func ping_endpoint(url: String) -> bool:
	assert(url.begins_with("http"), "❌ Invalid URL for ping.")

	var result: Dictionary = await _api_client_manager.get_json(url, [], 1)

	if result.get("ok", false):
		_audit_log_manager.append_entry("✅ Ping OK: %s" % url)
	else:
		_audit_log_manager.append_entry("⚠️ Ping failed: %s" % url)

	return result.get("ok", false)


## Attempts to recover from previous failure via callable.
##
## @param last_result Dictionary: Previous API response.
## @param fallback_action Callable: Recovery method.
## @return bool: True if retried successfully.
func attempt_recovery(last_result: Dictionary, fallback_action: Callable) -> bool:
	assert(typeof(fallback_action) == TYPE_CALLABLE, "❌ Invalid recovery action.")

	if last_result.get("error_code", ERR_QUERY_FAILED) in [ERR_TIMEOUT, ERR_CANT_CONNECT]:
		if fallback_action.is_valid():
			_audit_log_manager.append_entry("🔄 Retrying via recovery action...")
			await fallback_action.call()
			return true

	_audit_log_manager.append_entry("⚠️ Recovery skipped or failed.")
	return false
