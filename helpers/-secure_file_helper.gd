extends RefCounted
class_name SecureFileHelper


# --- Description ---
##
## SecureFileHelper.gd (GLI-19+ Modular Standard)
##
## Handles secure file operations with encryption, compression, detached signature and hash validation.
##
## Features:
## - AES-256 CBC encryption and decryption via injected SecurityUtils
## - SHA-256 integrity via detached .sig file
## - GZIP compression support
## - Timeout-based I/O for stability
## - Safe initialization via `init()`
##
## Compliant with: GLI-19, GLI-11, GLI-33
## Location: res://scripts/core/helpers/secure_file_helper.gd
## Not Autoload. Must be manually instantiated and initialized.


# --- Signals ---


signal file_operation_failed(file_path: String, reason: String)


# --- Constants ---


const SIGNATURE_SUFFIX: String = ".sig"


# --- Private Variables ---


var _settings_manager: Node
var _logger_callback: Callable = Callable()

var _encryption_key: String = "A1B2C3D4E5F6G7H8"
var _timeout_sec: float = 5.0


# --- Initialization ---


## Initializes the helper with SecurityUtils and SettingsManager.
func init(settings_manager: Node) -> void:
	assert(settings_manager != null, "❌ SettingsManager is required.")
	_settings_manager = settings_manager
	_load_settings()


## Sets optional logger callback (e.g. for audit log).
func set_logger(logger: Callable) -> void:
	_logger_callback = logger


## Loads secure file settings dynamically.
func _load_settings() -> void:
	if _settings_manager:
		_encryption_key = _settings_manager.get_setting("secure_encryption_key", _encryption_key)
		_timeout_sec = _settings_manager.get_setting("secure_file_timeout_sec", _timeout_sec)


# --- Public Methods ---


## Saves an encrypted and optionally compressed file with optional detached signature.
func save_secure_file(
	file_path: String,
	data: PackedByteArray,
	save_external_signature: bool = true,
	compress: bool = false
) -> bool:
	assert(file_path != "", "❌ File path cannot be empty.")
	assert(data.size() > 0, "❌ Data buffer must not be empty.")

	var final_data := data.compress(FileAccess.COMPRESSION_GZIP) if compress else data
	var encrypted := SecurityUtils.encrypt_cbc(final_data.get_string_from_utf8())
	if encrypted.is_empty():
		_log_error(file_path, "Encryption failed: Encrypted buffer is empty.")
		return false

	var file := _open_file_with_timeout(file_path, FileAccess.WRITE)
	if file == null:
		_log_error(file_path, "Failed to open file for writing.")
		return false

	var new_hash := _generate_sha256(final_data)
	file.store_buffer(encrypted)
	file.store_line(new_hash)
	file.close()

	if save_external_signature:
		_save_signature_file(file_path, new_hash)

	return true


## Loads and validates a secure file, including decryption, decompression, and hash checks.
func load_secure_file(file_path: String, compressed: bool = false) -> Dictionary:
	assert(file_path != "", "❌ File path must not be empty.")

	var result := { "success": false, "data": PackedByteArray() }

	var file := _open_file_with_timeout(file_path, FileAccess.READ)
	if file == null:
		_log_error(file_path, "Cannot open file for reading.")
		return result

	if file.get_length() < 64:
		_log_error(file_path, "File too small to contain SHA-256 signature.")
		file.close()
		return result

	var content := file.get_buffer(file.get_length()).get_string_from_utf8()
	file.close()

	var lines := content.split("\n", false)
	if lines.size() < 2:
		_log_error(file_path, "Invalid file format: Missing hash line.")
		return result

	var stored_hash := lines[-1].strip_edges()
	var encrypted := "\n".join(lines.slice(0, lines.size() - 1)).to_utf8_buffer()

	var decrypted_text := SecurityUtils.decrypt_cbc(encrypted)
	var buffer := decrypted_text.to_utf8_buffer()

	if compressed:
		buffer = buffer.decompress(FileAccess.COMPRESSION_GZIP)

	if _generate_sha256(buffer) != stored_hash:
		_log_error(file_path, "Embedded hash mismatch.")
		return result

	if not _validate_signature_file(file_path, stored_hash):
		return result

	result.success = true
	result.data = buffer
	return result


# --- Private Methods ---


func _open_file_with_timeout(path: String, mode: int) -> FileAccess:
	assert(path != "", "❌ Path is required.")
	var start := Time.get_ticks_msec()
	var file = null

	while not file and Time.get_ticks_msec() - start < _timeout_sec * 1000:
		file = FileAccess.open(path, mode)

	return file


func _generate_sha256(buffer: PackedByteArray) -> String:
	assert(buffer.size() > 0, "❌ Cannot hash empty buffer.")
	var ctx := HashingContext.new()
	assert(ctx.start(HashingContext.HASH_SHA256) == OK, "❌ Failed to start hash context.")
	ctx.update(buffer)
	return ctx.finish().hex_encode()


func _save_signature_file(file_path: String, signature: String) -> void:
	assert(file_path != "" and signature != "")
	var sig_path := "%s%s" % [file_path, SIGNATURE_SUFFIX]
	var file := FileAccess.open(sig_path, FileAccess.WRITE)
	if file:
		file.store_line(signature)
		file.close()
	else:
		_log_error(file_path, "Failed to write .sig file.")


func _validate_signature_file(file_path: String, expected_hash: String) -> bool:
	assert(file_path != "" and expected_hash != "")
	var sig_path := "%s%s" % [file_path, SIGNATURE_SUFFIX]

	if not FileAccess.file_exists(sig_path):
		_log_error(file_path, "Signature file missing.")
		return false

	var sig_file := FileAccess.open(sig_path, FileAccess.READ)
	if sig_file == null:
		_log_error(file_path, "Failed to open signature file.")
		return false

	var signature := sig_file.get_line().strip_edges()
	sig_file.close()

	if signature != expected_hash:
		_log_error(file_path, "Signature mismatch.")
		return false

	return true


func _log_error(file_path: String, reason: String) -> void:
	assert(file_path != "" and reason != "")
	push_error("❌ %s" % reason)
	file_operation_failed.emit(file_path, reason)
	if _logger_callback.is_valid():
		_logger_callback.call(file_path, reason)
