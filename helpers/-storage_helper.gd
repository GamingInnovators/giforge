extends Node
class_name StorageHelper


# --- Description ---
##
## StorageHelper.gd (GLI-19 Compliant)
##
## Provides secure, encrypted, and auditable game data persistence.
##
## Features:
## - AES-256 CBC encryption via SecureFileHelper
## - Optional GZIP compression
## - SHA-256 file and signature validation
## - Structured and auditable data lifecycle
##
## Not Autoload. Must be instantiated manually.
## Located at: res://scripts/core/helpers/storage_helper.gd
##


# --- Private Variables ---


## Internal secure file helper used for encryption and validation.
var _secure_file_helper: SecureFileHelper = SecureFileHelper.new()


# --- Public Methods ---


## Saves data securely as encrypted JSON with optional GZIP and detached signature.
##
## @param path String: Full destination path.
## @param data Variant: Must be Dictionary or Array.
## @param with_signature bool: Save detached .sig file (default = true).
## @param compress bool: Enable GZIP compression before encryption (default = false).
## @return bool: True on successful save, false on failure.
func save_json(path: String, data: Variant, with_signature: bool = true, compress: bool = false) -> bool:
	assert(path != "", "❌ File path must not be empty.")
	assert(typeof(data) in [TYPE_DICTIONARY, TYPE_ARRAY], "❌ Data must be Dictionary or Array.")

	var json_string: String = JSON.stringify(data, "\t")
	var buffer: PackedByteArray = json_string.to_utf8_buffer()

	return _secure_file_helper.save_secure_file(path, buffer, with_signature, compress)


## Loads a securely saved encrypted JSON file.
##
## @param path String: Full path to the secure file.
## @param compressed bool: Whether the file was GZIP compressed when saved.
## @return Dictionary: Parsed content or empty Dictionary on failure.
func load_json(path: String, compressed: bool = false) -> Dictionary:
	assert(path != "", "❌ File path must not be empty.")

	if not FileAccess.file_exists(path):
		push_warning("⚠️ File not found: %s" % path)
		return {}

	var result: Dictionary = _secure_file_helper.load_secure_file(path, compressed)
	if not result.get("success", false):
		push_warning("⚠️ Failed to securely load: %s" % path)
		return {}

	var json_string: String = result["data"].get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(json_string)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("❌ Invalid JSON structure from secure file: %s" % path)
		return {}

	return parsed


## Securely deletes a file from the user:// directory.
##
## @param path String: Absolute or relative file path.
## @return bool: True if deleted successfully or file doesn't exist; false on error.
func delete_file(path: String) -> bool:
	assert(path != "", "❌ File path must not be empty.")

	if not FileAccess.file_exists(path):
		return true  # File already gone.

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("❌ Unable to open user:// directory to delete: %s" % path)
		return false

	var result := dir.remove(path)
	if result != OK:
		push_warning("⚠️ Failed to delete file: %s" % path)

	return result == OK
