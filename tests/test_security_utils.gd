extends Node


# --- Description ---
##
## Tests for SecurityUtils.gd
##
## Covers:
## - AES-CBC encryption/decryption with random salt and IV
## - PBKDF2 key derivation
## - PKCS#7 padding/unpadding
## - HMAC-SHA256 derivation
##
## All tests must be deterministic (with forced seeds where necessary).


# --- Tests ---


## Tests full encryption/decryption cycle using AES-256 CBC.
func test_encrypt_decrypt_cbc() -> void:
	var original := "Confidential Test Message 123 🚀"
	var password := "TestSecret123!"

	var encrypted := SecurityUtils.encrypt_cbc(original, password)
	assert(encrypted is PackedByteArray and encrypted.size() > 0, "❌ Encryption failed.")

	var decrypted := SecurityUtils.decrypt_cbc(encrypted, password)
	assert(decrypted == original, "❌ Decryption did not restore original content.")


## Tests PBKDF2 key derivation produces fixed length.
func test_pbkdf2_key_length() -> void:
	var salt := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8])
	var password := "test-password"

	var key := SecurityUtils.pbkdf2_hmac_sha256(password, salt, 100, 32)
	assert(key.size() == 32, "❌ Derived key length is incorrect.")


## Tests that PKCS#7 padding and unpadding round trip correctly.
func test_padding_roundtrip() -> void:
	var input := PackedByteArray("Test123".to_utf8_buffer())
	var padded := SecurityUtils._pad_to_block_size(input, 16)

	assert(padded.size() % 16 == 0, "❌ Padding failed to align to block size.")

	var unpadded := SecurityUtils._unpad_from_block_size(padded)
	assert(unpadded == input, "❌ Unpadding did not restore original data.")


## Tests that HMAC-SHA256 generates expected output length.
func test_hmac_sha256_output_length() -> void:
	var key := PackedByteArray("key123".to_utf8_buffer())
	var msg := PackedByteArray("message456".to_utf8_buffer())

	var digest := SecurityUtils._hmac_sha256(key, msg)
	assert(digest.size() == 32, "❌ HMAC-SHA256 output is not 32 bytes.")
