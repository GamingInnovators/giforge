extends RefCounted
class_name FileUtils


# --- Description ---
##
## FileUtils.gd (GLI-19/GLI-11/GLI-33 Compliant - Hardened Version)
##
## Provides secure, auditable, and deterministic file I/O operations.
##
## Responsibilities:
## - JSON, CSV, XML, String and Binary secure save/load
## - SHA-256 signing after each write (IntegrityChecker)
## - Optional encryption (SecureFileHelper)
## - Defensive error handling and fallback
##
## Important:
## - Manual instantiation (NOT Autoload)
## - Never throws: always defensive + safe
##


# --- Public Static Methods ---


## Returns the file size in bytes, or -1 on error.
##
## @param path String: Absolute path to file.
## @return int: Size in bytes, or -1 if file not found or unreadable.
static func get_file_size(path: String) -> int:
	assert(path != "", "❌ Path must not be empty.")

	if not FileAccess.file_exists(path):
		push_warning("⚠️ File not found: %s" % path)
		return -1

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("⚠️ Cannot open file: %s" % path)
		return -1

	var size := file.get_length()
	file.close()

	return size


## Saves securely encrypted data with optional GZIP compression and detached signature.
##
## @param file_path String: Destination file path.
## @param data PackedByteArray: Data buffer to encrypt and save.
## @param encryption_key String: Encryption key.
## @param timeout_sec float: Timeout for file access.
## @param save_signature bool: Whether to create .sig file.
## @param compress bool: Whether to GZIP before encryption.
## @param logger Callable: Optional logger callback.
## @return bool: True if successful.
static func save_secure_file_static(
	file_path: String,
	data: PackedByteArray,
	encryption_key: String,
	timeout_sec: float = 5.0,
	save_signature: bool = true,
	compress: bool = false,
	logger: Callable = Callable()
) -> bool:
	assert(file_path != "", "❌ File path cannot be empty.")
	assert(data.size() > 0, "❌ Data buffer must not be empty.")
	assert(encryption_key != "", "❌ Encryption key is required.")

	var final_data := data.compress(FileAccess.COMPRESSION_GZIP) if compress else data
	var encrypted := SecurityUtils.encrypt_cbc(final_data.get_string_from_utf8(), encryption_key)

	if encrypted.is_empty():
		_log_static_error(file_path, "Encryption failed: Encrypted buffer is empty.", logger)
		return false

	var file := _open_file_with_timeout(file_path, FileAccess.WRITE, timeout_sec)
	if file == null:
		_log_static_error(file_path, "Failed to open file for writing.", logger)
		return false

	var new_hash := _generate_sha256(final_data)
	file.store_buffer(encrypted)
	file.store_line(new_hash)
	file.close()

	if save_signature:
		_save_signature_file(file_path, new_hash, logger)

	return true


## Saves a Dictionary or Array as encrypted and signed JSON with optional GZIP compression.
##
## @param path String: Destination file path.
## @param data Variant: Dictionary or Array.
## @param encryption_key String: AES-256 encryption key.
## @param save_signature bool: Whether to save an external .sig file.
## @param compress bool: Whether to compress with GZIP before encryption.
## @param timeout_sec float: Max wait time for file access in seconds.
## @param logger Callable: Optional logger for error reporting.
## @return bool: True if successful, false if error.
static func save_secure_json_static(
	path: String,
	data: Variant,
	encryption_key: String,
	save_signature: bool = true,
	compress: bool = false,
	timeout_sec: float = 5.0,
	logger: Callable = Callable()
) -> bool:
	assert(path != "", "❌ Path must not be empty.")
	assert(typeof(data) in [TYPE_DICTIONARY, TYPE_ARRAY], "❌ Data must be Dictionary or Array.")
	assert(encryption_key.length() >= 16, "❌ Encryption key must be at least 16 characters.")

	var json_string := JSON.stringify(data, "\t")
	var buffer := json_string.to_utf8_buffer()

	return save_secure_file_static(path, buffer, encryption_key, save_signature, compress, timeout_sec, logger)



## Saves raw string to disk securely.
##
## @param path String: Target file path.
## @param content String: String to save.
static func save_string(path: String, content: String) -> void:
	assert(path != "", "❌ Path must not be empty.")
	assert(content != "", "❌ Content must not be empty.")

	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "❌ Cannot open file for writing: %s" % path)

	file.store_string(content)
	file.close()

	var success := IntegrityChecker.save_file_signature(path)
	assert(success, "❌ Signature saving failed: %s" % path)


## Saves Dictionary/Array as formatted JSON and signs it.
##
## @param path String: Destination path.
## @param data Variant: Data to save.
static func save_json(path: String, data: Variant) -> void:
	assert(path != "", "❌ Path must not be empty.")
	assert(typeof(data) in [TYPE_DICTIONARY, TYPE_ARRAY], "❌ JSON data must be Dictionary or Array.")

	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "❌ Cannot open JSON file: %s" % path)

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	IntegrityChecker.save_file_signature(path)


## Saves an Array of Dictionaries as CSV and signs it.
##
## @param path String: Destination path.
## @param data Variant: Array[Dictionary] to save.
static func save_csv(path: String, data: Variant) -> void:
	assert(path != "", "❌ Path must not be empty.")
	assert(typeof(data) == TYPE_ARRAY, "❌ CSV data must be an Array.")

	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "❌ Cannot open CSV file: %s" % path)

	if data.is_empty():
		file.store_line("empty_file")
	else:
		var header: Array = data[0].keys()
		file.store_line(ArrayUtils.join_as_string(header, ","))

		for entry in data:
			var row: Array = []
			for key in header:
				assert(typeof(entry.get(key, "")) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT], "❌ CSV entry has unsupported type.")
				row.append(str(entry.get(key, "")).xml_escape())
			file.store_line(ArrayUtils.join_as_string(row, ","))

	file.close()

	IntegrityChecker.save_file_signature(path)


## Saves an Array of Dictionaries as XML and signs it.
##
## @param path String: Destination file path.
## @param data Variant: Array[Dictionary].
static func save_xml(path: String, data: Variant) -> void:
	assert(path != "", "❌ Path must not be empty.")
	assert(typeof(data) == TYPE_ARRAY, "❌ XML data must be an Array.")

	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "❌ Cannot open XML file: %s" % path)

	file.store_line('<?xml version="1.0" encoding="UTF-8"?>')
	file.store_line("<Data>")

	for entry in data:
		file.store_line("\t<Entry>")
		for key in entry.keys():
			assert(typeof(entry.get(key, "")) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT], "❌ XML entry has unsupported type.")
			file.store_line("\t\t<%s>%s</%s>" % [key, str(entry[key]).xml_escape(), key])
		file.store_line("\t</Entry>")

	file.store_line("</Data>")
	file.close()

	IntegrityChecker.save_file_signature(path)


## Saves encrypted JSON optionally compressed, optionally signs.
##
## @param path String: Path to save.
## @param data Variant: Dictionary or Array.
## @param save_signature bool: Save .sig file.
## @param compress bool: Compress payload.
## @return bool: Success.
static func save_json_secure(path: String, data: Variant, save_signature: bool = true, compress: bool = false) -> bool:
	assert(path != "", "❌ Path must not be empty.")
	assert(typeof(data) in [TYPE_DICTIONARY, TYPE_ARRAY], "❌ JSON data must be Dictionary or Array.")

	var helper := SecureFileHelper.new()
	var buffer := JSON.stringify(data, "\t").to_utf8_buffer()

	return helper.save_secure_file(path, buffer, save_signature, compress)


## Saves encrypted binary structure with password and optional signing.
##
## @param path String: File path.
## @param data Variant: Dictionary or Array.
## @param password String: Password for encryption.
## @param save_signature bool: Save .sig file.
## @return bool: Success.
static func save_secure_bin(path: String, data: Variant, password: String, save_signature: bool = true) -> bool:
	assert(path != "", "❌ Path must not be empty.")
	assert(password != "", "❌ Password must not be empty.")
	assert(typeof(data) in [TYPE_DICTIONARY, TYPE_ARRAY], "❌ Data must be Dictionary or Array.")

	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, password)
	if file == null:
		push_error("❌ Cannot open encrypted file: %s" % path)
		return false

	var ok := file.store_var(data)
	assert(ok, "❌ Failed to store encrypted variable.")
	file.close()

	if save_signature:
		IntegrityChecker.save_file_signature(path)

	return true


## Loads and validates an encrypted, signed and optionally compressed file.
##
## @param file_path String: Path to the encrypted file.
## @param encryption_key String: AES key (e.g., from SettingsManager).
## @param timeout_sec float: Timeout in seconds for file access.
## @param compressed bool: Whether the file was GZIP-compressed before encryption.
## @param logger Callable: Optional logging function.
## @return Dictionary: { "success": bool, "data": PackedByteArray }
static func load_secure_file_static(
	file_path: String,
	encryption_key: String,
	timeout_sec: float = 5.0,
	compressed: bool = false,
	logger: Callable = Callable()
) -> Dictionary:
	assert(file_path != "", "❌ File path must not be empty.")
	assert(encryption_key != "", "❌ Encryption key is required.")

	var result := {
		"success": false,
		"data": PackedByteArray()
	}

	# --- Open file safely with timeout
	var file := _open_file_with_timeout(file_path, FileAccess.READ, timeout_sec)
	if file == null:
		_log_static_error(file_path, "Cannot open file for reading.", logger)
		return result

	if file.get_length() < 64:
		_log_static_error(file_path, "File too small to contain SHA-256 signature.", logger)
		file.close()
		return result

	# --- Read content and split
	var content := file.get_buffer(file.get_length()).get_string_from_utf8()
	file.close()

	var lines := content.split("\n", false)
	if lines.size() < 2:
		_log_static_error(file_path, "Invalid format: missing hash line.", logger)
		return result

	var stored_hash := lines[-1].strip_edges()
	var encrypted_data := "\n".join(lines.slice(0, lines.size() - 1)).to_utf8_buffer()

	# --- Decrypt
	var decrypted_text := SecurityUtils.decrypt_cbc(encrypted_data, encryption_key)
	var buffer: PackedByteArray = decrypted_text.to_utf8_buffer()

	if compressed:
		buffer = buffer.decompress(FileAccess.COMPRESSION_GZIP)

	# --- Validate internal SHA-256
	if _generate_sha256(buffer) != stored_hash:
		_log_static_error(file_path, "Embedded SHA-256 mismatch.", logger)
		return result

	# --- Validate detached .sig file
	var sig_path := "%s.sig" % file_path
	if FileAccess.file_exists(sig_path):
		var sig_file := FileAccess.open(sig_path, FileAccess.READ)
		if sig_file:
			var sig_value := sig_file.get_line().strip_edges()
			sig_file.close()

			if sig_value != stored_hash:
				_log_static_error(file_path, "Signature mismatch (detached).", logger)
				return result
		else:
			_log_static_error(file_path, "Failed to open .sig file.", logger)
			return result
	else:
		_log_static_error(file_path, "Missing .sig file for integrity.", logger)
		return result

	result.success = true
	result.data = buffer
	return result


## Loads a secure encrypted JSON file with integrity and optional decompression.
##
## @param path String: File path.
## @param encryption_key String: AES-256 decryption key.
## @param compressed bool: If the file was compressed before encryption.
## @param timeout_sec float: Timeout in seconds for file access.
## @param logger Callable: Optional logger for error handling.
## @return Variant: Dictionary or Array if valid; null if invalid.
static func load_secure_json_static(
	path: String,
	encryption_key: String,
	compressed: bool = false,
	timeout_sec: float = 5.0,
	logger: Callable = Callable()
) -> Variant:
	assert(path != "", "❌ Path must not be empty.")
	assert(encryption_key.length() >= 16, "❌ Encryption key must be at least 16 characters.")

	var result := load_secure_file_static(path, encryption_key, compressed, timeout_sec, logger)
	if not result.get("success", false):
		if logger.is_valid():
			logger.call(path, "Load failed or integrity check failed.")
		return null

	var json_string: String = result["data"].get_string_from_utf8()
	var parsed = JSON.parse_string(json_string)
	if typeof(parsed) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		return parsed

	if logger.is_valid():
		logger.call(path, "❌ Parsed JSON is not a Dictionary or Array.")
	return null

## Loads a JSON file safely.
##
## @param path String: File path.
## @return Variant: Dictionary or Array or null.
static func load_json(path: String) -> Variant:
	assert(path != "", "❌ Path must not be empty.")

	if not FileAccess.file_exists(path):
		push_warning("⚠️ File not found: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("⚠️ Cannot open file: %s" % path)
		return null

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	return parsed if typeof(parsed) in [TYPE_DICTIONARY, TYPE_ARRAY] else null


## Loads a secure encrypted binary file.
##
## @param path String: Encrypted file path.
## @param password String: Decryption password.
## @return Variant: Dictionary or Array or null.
static func load_secure_bin(path: String, password: String) -> Variant:
	assert(path != "", "❌ Path must not be empty.")
	assert(password != "", "❌ Password must not be empty.")

	if not FileAccess.file_exists(path):
		push_warning("⚠️ File not found: %s" % path)
		return null

	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, password)
	if file == null:
		push_error("❌ Cannot open encrypted file: %s" % path)
		return null

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	return parsed if typeof(parsed) in [TYPE_DICTIONARY, TYPE_ARRAY] else null


## Deletes a file securely.
##
## @param path String: File path.
static func delete_file(path: String) -> void:
	assert(path != "", "❌ Path must not be empty.")

	if FileAccess.file_exists(path):
		var result := DirAccess.remove_absolute(path)
		if result == OK:
			print_debug("🗑️ File deleted: %s" % path)
		else:
			push_warning("⚠️ Failed to delete: %s" % path)
	else:
		push_warning("⚠️ Attempt to delete nonexistent file: %s" % path)


## Verifies if a file exists and is non-empty.
##
## @param path String: File path.
## @return bool: True if valid.
static func is_valid_file(path: String) -> bool:
	assert(path != "", "❌ Path must not be empty.")
	return FileAccess.file_exists(path) and get_file_size(path) > 0


# --- Private Static Helpers ---


## Opens a file with timeout (in milliseconds).
##
## @param path String: File path.
## @param mode int: FileAccess.READ or FileAccess.WRITE
## @param timeout_sec float: Max wait time in seconds.
## @return FileAccess or null on failure.
static func _open_file_with_timeout(path: String, mode: int, timeout_sec: float) -> FileAccess:
	assert(path != "", "❌ Path must not be empty.")

	var start := Time.get_ticks_msec()
	var file = null

	while not file and Time.get_ticks_msec() - start < timeout_sec * 1000:
		file = FileAccess.open(path, mode)

	return file


## Generates a SHA-256 hash from a buffer.
##
## @param buffer PackedByteArray
## @return String: hex-encoded hash
static func _generate_sha256(buffer: PackedByteArray) -> String:
	assert(buffer.size() > 0, "❌ Cannot hash empty buffer.")
	var ctx := HashingContext.new()
	assert(ctx.start(HashingContext.HASH_SHA256) == OK, "❌ Failed to start hashing context.")
	ctx.update(buffer)
	return ctx.finish().hex_encode()


## Saves a .sig file next to target file.
##
## @param file_path String
## @param signature String
## @param logger Callable: Optional logger
static func _save_signature_file(file_path: String, signature: String, logger: Callable = Callable()) -> void:
	assert(file_path != "" and signature != "")

	var sig_path := "%s.sig" % file_path
	var file := FileAccess.open(sig_path, FileAccess.WRITE)

	if file:
		file.store_line(signature)
		file.close()
	else:
		_log_static_error(file_path, "Failed to write .sig file.", logger)


## Logs errors in static helpers with optional callback.
##
## @param file_path String
## @param reason String
## @param logger Callable
static func _log_static_error(file_path: String, reason: String, logger: Callable) -> void:
	push_error("❌ %s" % reason)
	if logger.is_valid():
		logger.call(file_path, reason)
