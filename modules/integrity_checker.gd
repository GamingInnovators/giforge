extends RefCounted
class_name IntegrityChecker


# --- Description ---
##
## IntegrityChecker.gd
##
## Provides secure SHA-256 digital signature generation and validation for string and file content.
## Ensures GLI-19/11/33 compliance for audit logs, configuration exports, receipts, and session files.
##
## Location: res://scripts/core/modules/integrity_checker.gd
##
## Example Usage:
## - IntegrityChecker.generate_signature("text")
## - IntegrityChecker.save_file_signature("user://audit.json")
## - IntegrityChecker.validate_file_signature("user://audit.json")


# --- Public Static Methods ---


## Generates a SHA-256 hex signature for the given string content.
##
## @param content String: Content to hash.
## @return String: Hex-encoded SHA-256 hash.
static func generate_signature(content: String) -> String:
	assert(content != "", "❌ Content must not be empty.")
	var buffer := content.to_utf8_buffer()
	return HashUtils.sha256_from_bytes(buffer)


## Verifies that the string content matches the provided SHA-256 signature.
##
## @param content String: Content to verify.
## @param expected_signature String: Signature to compare.
## @return bool: True if match, False otherwise.
static func verify_signature(content: String, expected_signature: String) -> bool:
	assert(content != "", "❌ Content must not be empty.")
	assert(expected_signature != "", "❌ Expected signature must not be empty.")

	var actual_signature := generate_signature(content)
	if actual_signature != expected_signature:
		push_warning("⚠️ Signature mismatch.")
		return false
	return true


## Generates a SHA-256 signature for the contents of a file.
##
## @param file_path String: Absolute or project-relative file path.
## @return String: Hex-encoded SHA-256 hash, or "" if file invalid.
static func generate_file_signature(file_path: String) -> String:
	assert(file_path.is_valid_filename(), "❌ Invalid file path for signature generation.")

	if not FileAccess.file_exists(file_path):
		push_warning("⚠️ File not found: %s" % file_path)
		return ""

	var data := FileAccess.get_file_as_bytes(file_path)
	if data.is_empty():
		push_warning("⚠️ File is empty or unreadable: %s" % file_path)
		return ""

	return HashUtils.sha256_from_bytes(data)


## Saves the signature of a file as a `.sig` companion file.
##
## @param file_path String: Path to the original file.
## @return bool: True if saved, False otherwise.
static func save_file_signature(file_path: String) -> bool:
	assert(file_path.is_valid_filename(), "❌ Invalid file path.")

	var signature := generate_file_signature(file_path)
	if signature == "":
		push_warning("⚠️ Failed to generate signature for: %s" % file_path)
		return false

	var sig_path := "%s.sig" % file_path
	var sig_file := FileAccess.open(sig_path, FileAccess.WRITE)
	if sig_file == null:
		push_warning("⚠️ Failed to write signature file: %s" % sig_path)
		return false

	sig_file.store_string(signature)
	sig_file.close()
	return true


## Validates the integrity of a file against its `.sig` companion.
##
## @param file_path String: File path to check.
## @return bool: True if signature matches, False otherwise.
static func validate_file_signature(file_path: String) -> bool:
	assert(file_path.is_valid_filename(), "❌ Invalid file path.")

	var sig_path := "%s.sig" % file_path
	if not FileAccess.file_exists(file_path):
		push_warning("❌ Original file not found: %s" % file_path)
		return false

	if not FileAccess.file_exists(sig_path):
		push_warning("❌ Signature file not found: %s" % sig_path)
		return false

	var expected := FileAccess.get_file_as_string(sig_path).strip_edges()
	var actual := generate_file_signature(file_path)

	if expected == "" or actual == "":
		push_warning("⚠️ Signature content empty during comparison: %s" % file_path)
		return false

	if actual != expected:
		push_warning("⚠️ Signature mismatch: %s" % file_path)
		return false

	return true
