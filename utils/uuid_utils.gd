extends RefCounted
class_name UuidUtils


# --- Description ---
##
## UuidUtils.gd
##
## Secure and deterministic UUID generator utility for casino and VLT applications.
##
## Supports:
## - UUID v4 (Random secure generation)
## - UUID v3 (Deterministic MD5 namespace hashing)
## - UUID v5 (Deterministic SHA-1 namespace hashing)
##
## Design:
## - GLI-19 Compliant (offline secure generation supported)
## - No state preservation; fully stateless operations
##
## Location: res://scripts/core/utils/uuid_utils.gd
##
## Example usage:
## - `var uuid := UuidUtils.v4()`
## - `var deterministic := UuidUtils.v5(UuidUtils.NAMESPACE_DNS, "unique_text")`


# --- Constants ---

const BYTE_MASK: int = 0xFF
const NAMESPACE_DNS: String = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"


# --- Public Static Methods ---

## Generates a secure random UUID v4.
##
## @return String - UUID v4 canonical string.
static func v4() -> String:
	var bytes := _generate_random_bytes()
	_set_version_and_variant(bytes, 4)
	return _format_uuid(bytes)


## Generates a deterministic UUID v3 (MD5).
##
## @param uuid_namespace String - Namespace UUID string.
## @param input String - Input text.
## @return String - UUID v3 canonical string.
static func v3(uuid_namespace: String, input: String) -> String:
	assert(uuid_namespace != "" and input != "", "❌ Namespace and input must be provided for UUID v3.")

	var input_data := _parse_uuid(uuid_namespace)
	input_data.append_array(input.to_utf8_buffer())

	var ctx := HashingContext.new()
	assert(ctx.start(HashingContext.HASH_MD5) == OK, "❌ Failed to initialize MD5 context.")

	ctx.update(input_data)
	var digest := ctx.finish()
	digest.resize(16)

	_set_version_and_variant(digest, 3)
	return _format_uuid(digest)


## Generates a deterministic UUID v5 (SHA-1).
##
## @param uuid_namespace String - Namespace UUID string.
## @param input String - Input text.
## @return String - UUID v5 canonical string.
static func v5(uuid_namespace: String, input: String) -> String:
	assert(uuid_namespace != "" and input != "", "❌ Namespace and input must be provided for UUID v5.")

	var input_data := _parse_uuid(uuid_namespace)
	input_data.append_array(input.to_utf8_buffer())

	var ctx := HashingContext.new()
	assert(ctx.start(HashingContext.HASH_SHA1) == OK, "❌ Failed to initialize SHA-1 context.")

	ctx.update(input_data)
	var digest := ctx.finish()
	digest.resize(16)

	_set_version_and_variant(digest, 5)
	return _format_uuid(digest)


# --- Private Static Methods ---

## Generates a secure random 16-byte array.
##
## @return PackedByteArray - Random 16 bytes.
static func _generate_random_bytes() -> PackedByteArray:
	var result := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for _i in range(16):
		result.append(rng.randi() & BYTE_MASK)

	return result


## Applies UUID version and variant bits according to RFC 4122.
##
## @param bytes PackedByteArray - 16-byte buffer.
## @param version int - Version number (3, 4, or 5).
static func _set_version_and_variant(bytes: PackedByteArray, version: int) -> void:
	assert(bytes.size() == 16, "❌ Byte array must be 16 bytes for UUID adjustment.")

	bytes[6] = (bytes[6] & 0x0F) | (version << 4)  # Set version bits
	bytes[8] = (bytes[8] & 0x3F) | 0x80            # Set variant bits


## Formats a 16-byte array into a canonical UUID string.
##
## @param bytes PackedByteArray - 16 bytes.
## @return String - Formatted UUID string.
static func _format_uuid(bytes: PackedByteArray) -> String:
	assert(bytes.size() == 16, "❌ UUID format requires exactly 16 bytes.")

	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]


## Parses a UUID string into a 16-byte PackedByteArray.
##
## @param uuid_str String - Canonical UUID string.
## @return PackedByteArray - Parsed 16-byte array.
static func _parse_uuid(uuid_str: String) -> PackedByteArray:
	assert(uuid_str.length() >= 32, "❌ UUID string must have at least 32 characters.")

	var clean := uuid_str.replace("-", "")
	var result := PackedByteArray()

	for i in range(0, clean.length(), 2):
		result.append(clean.substr(i, 2).hex_to_int())

	assert(result.size() == 16, "❌ Parsed UUID must be exactly 16 bytes.")
	return result
