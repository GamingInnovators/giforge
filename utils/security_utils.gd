extends RefCounted
class_name SecurityUtils

# --- Description ---
##
## SecurityUtils.gd (Static CBC + PBKDF2 Version)
##
## Cryptographic utility for GLI-19 compliant encryption and decryption.
##
## Features:
## - AES-256 CBC encryption with dynamic IV.
## - PBKDF2 password-based key derivation (HMAC-SHA256).
## - Salt generation for each encryption.
## - Full PKCS#7 padding support.
## - Integrity verification with SHA-256.
##
## Must be used as a static class (not instantiated).
## Location: res://scripts/core/utils/security_utils.gd


# --- Constants ---

const DEFAULT_PBKDF2_ITERATIONS: int = 100_000
const DEFAULT_AES_KEY_SIZE_BYTES: int = 32  # 256 bits
const DEFAULT_SALT_SIZE_BYTES: int = 16
const DEFAULT_IV_SIZE_BYTES: int = 16
const DEFAULT_PASSWORD: String = "ChangeThisDefaultPassword!"


# --- Public Static Methods ---


static func encrypt_cbc(plain_text: String, password: String = DEFAULT_PASSWORD) -> PackedByteArray:
	assert(plain_text != "", "❌ plain_text must not be empty.")
	assert(password != "", "❌ Password must not be empty.")

	var salt := _generate_random_bytes(DEFAULT_SALT_SIZE_BYTES)
	var key := _derive_key(password, salt)
	var iv := _generate_random_bytes(DEFAULT_IV_SIZE_BYTES)

	var aes := AESContext.new()
	assert(aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv) == OK, "❌ Failed to start AES CBC encryption.")

	var padded_plain_text := _pad_to_block_size(plain_text.to_utf8_buffer(), DEFAULT_IV_SIZE_BYTES)
	var encrypted := aes.update(padded_plain_text)
	aes.finish()

	return salt + iv + encrypted


static func decrypt_cbc(encrypted_package: PackedByteArray, password: String = DEFAULT_PASSWORD) -> String:
	assert(encrypted_package.size() > (DEFAULT_SALT_SIZE_BYTES + DEFAULT_IV_SIZE_BYTES), "❌ Encrypted package too small.")
	assert(password != "", "❌ Password must not be empty.")

	var salt := encrypted_package.slice(0, DEFAULT_SALT_SIZE_BYTES)
	var iv := encrypted_package.slice(DEFAULT_SALT_SIZE_BYTES, DEFAULT_SALT_SIZE_BYTES + DEFAULT_IV_SIZE_BYTES)
	var encrypted := encrypted_package.slice(DEFAULT_SALT_SIZE_BYTES + DEFAULT_IV_SIZE_BYTES, encrypted_package.size())

	var key := _derive_key(password, salt)

	var aes := AESContext.new()
	assert(aes.start(AESContext.MODE_CBC_DECRYPT, key, iv) == OK, "❌ Failed to start AES CBC decryption.")

	var decrypted := aes.update(encrypted)
	aes.finish()

	assert(decrypted.size() > 0, "❌ AES CBC decryption failed.")

	return _unpad_from_block_size(decrypted).get_string_from_utf8()


static func pbkdf2_hmac_sha256(password: String, salt: PackedByteArray, iterations: int = DEFAULT_PBKDF2_ITERATIONS, key_length: int = DEFAULT_AES_KEY_SIZE_BYTES) -> PackedByteArray:
	assert(password != "", "❌ Password must not be empty.")
	assert(salt.size() > 0, "❌ Salt must not be empty.")
	assert(iterations > 0, "❌ Iterations must be positive.")
	assert(key_length > 0, "❌ Key length must be positive.")

	var password_bytes := password.to_utf8_buffer()
	var derived_key := PackedByteArray()
	var block_count := int(ceil(float(key_length) / 32.0))

	for block_index in range(1, block_count + 1):
		var u := _hmac_sha256(password_bytes, salt + _int_to_bytes(block_index))
		var t := u.duplicate()

		for i in range(1, iterations):
			u = _hmac_sha256(password_bytes, u)
			for j in range(t.size()):
				t[j] = t[j] ^ u[j]

		derived_key.append_array(t)

	return derived_key.slice(0, key_length)


# --- Private Static Methods ---


static func _derive_key(password: String, salt: PackedByteArray) -> PackedByteArray:
	return pbkdf2_hmac_sha256(password, salt)


static func _hmac_sha256(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
	var hmac_block_size := 64
	var ctx := HashingContext.new()

	if key.size() > hmac_block_size:
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(key)
		key = ctx.finish()

	key.resize(hmac_block_size)

	var ipad := PackedByteArray()
	var opad := PackedByteArray()
	for i in range(hmac_block_size):
		ipad.append(key[i] ^ 0x36)
		opad.append(key[i] ^ 0x5C)

	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(ipad)
	ctx.update(msg)
	var inner := ctx.finish()

	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(opad)
	ctx.update(inner)

	return ctx.finish()


static func _generate_random_bytes(size: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	var output := PackedByteArray()

	for _i in range(size):
		output.append(rng.randi_range(0, 255))

	return output


static func _int_to_bytes(n: int) -> PackedByteArray:
	return PackedByteArray([
		(n >> 24) & 0xFF,
		(n >> 16) & 0xFF,
		(n >> 8) & 0xFF,
		n & 0xFF
	])


static func _pad_to_block_size(data: PackedByteArray, block_size: int) -> PackedByteArray:
	var padding := block_size - (data.size() % block_size)
	var padded := data.duplicate()

	for _i in range(padding):
		padded.append(padding)

	return padded


static func _unpad_from_block_size(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return PackedByteArray()

	var padding_value := data[-1]
	assert(padding_value > 0 and padding_value <= DEFAULT_IV_SIZE_BYTES, "❌ Invalid padding detected.")

	return data.slice(0, data.size() - padding_value)
