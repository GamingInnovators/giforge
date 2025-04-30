extends RefCounted
class_name HashUtils


# --- Description ---
##
## HashUtils.gd (GLI-19 Certified, Hardened)
##
## Provides standardized SHA-256 cryptographic operations:
## - Hashes for strings, byte buffers, and files.
## - Used for secure signature generation and integrity checking.
##
## Must be manually instantiated (NOT Autoload).
## Fully deterministic, secure, and side-effect free.
##


# --- Public Static Methods ---


## Computes the SHA-256 hash from a given string.
##
## @param text String - The input text.
## @return String - Hexadecimal encoded SHA-256 digest.
static func sha256_from_string(text: String) -> String:
	assert(text is String and not text.is_empty(), "❌ Text input must be a non-empty string.")

	var context := HashingContext.new()
	assert(context.start(HashingContext.HASH_SHA256) == OK, "❌ Failed to start SHA-256 hashing context.")

	context.update(text.to_utf8_buffer())
	var result := context.finish()
	assert(result is PackedByteArray and result.size() == 32, "❌ SHA-256 finalization failed.")
	return result.hex_encode()


## Computes the SHA-256 hash from a PackedByteArray.
##
## @param bytes PackedByteArray - The input binary buffer.
## @return String - Hexadecimal encoded SHA-256 digest.
static func sha256_from_bytes(bytes: PackedByteArray) -> String:
	assert(bytes is PackedByteArray and bytes.size() > 0, "❌ Bytes input must be a non-empty PackedByteArray.")

	var context := HashingContext.new()
	assert(context.start(HashingContext.HASH_SHA256) == OK, "❌ Failed to start SHA-256 hashing context.")

	context.update(bytes)
	var result := context.finish()
	assert(result is PackedByteArray and result.size() == 32, "❌ SHA-256 finalization failed.")
	return result.hex_encode()


## Computes the SHA-256 hash from a file on disk.
##
## @param file_path String - Absolute or user:// path.
## @return String - Hexadecimal encoded SHA-256 digest, or empty string on failure.
static func sha256_from_file(file_path: String) -> String:
	assert(file_path is String and not file_path.is_empty(), "❌ File path must be a non-empty string.")

	if not FileAccess.file_exists(file_path):
		push_warning("⚠️ File not found for hashing: %s" % file_path)
		return ""

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("⚠️ Cannot open file for hashing: %s" % file_path)
		return ""

	var context := HashingContext.new()
	assert(context.start(HashingContext.HASH_SHA256) == OK, "❌ Failed to start hashing context.")

	const CHUNK_SIZE := 4096
	while not file.eof_reached():
		var chunk := file.get_buffer(CHUNK_SIZE)
		context.update(chunk)

	file.close()
	var result := context.finish()
	assert(result is PackedByteArray and result.size() == 32, "❌ SHA-256 file finalization failed.")
	return result.hex_encode()
