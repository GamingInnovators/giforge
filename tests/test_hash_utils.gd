extends Node


# --- Description ---
##
## testHashUtils.gd
##
## Automated unit tests for HashUtils.gd.
##
## Verifies:
## - SHA-256 hashing from strings
## - SHA-256 hashing from bytes
## - SHA-256 hashing from files (existing and non-existing)
##
## Fully deterministic and isolated.
##


# --- Setup and Teardown ---


## Runs before each test.
func before_each() -> void:
	_prepare_test_files()


## Runs after each test.
func after_each() -> void:
	_cleanup_test_files()


# --- Tests ---


## Tests SHA-256 hashing of a known string.
func test_sha256_from_string() -> void:
	var text := "HelloWorld"
	var expected := "872e4bdc3e6c9c81b38b676bbfa7c6f7a4d09a35f9c94e7d2d0e6f6e5b2f5b6b"

	var result := HashUtils.sha256_from_string(text)
	AssertionsUtils.assert_eq(result, expected, "❌ String hash mismatch.")


## Tests SHA-256 hashing of a PackedByteArray.
func test_sha256_from_bytes() -> void:
	var bytes := PackedByteArray([72, 101, 108, 108, 111]) # "Hello"
	var expected := "185f8db32271fe25f561a6fc938b2e264306ec304eda518007d1764826381969"

	var result := HashUtils.sha256_from_bytes(bytes)
	AssertionsUtils.assert_eq(result, expected, "❌ Byte array hash mismatch.")


## Tests SHA-256 hashing of a real file.
func test_sha256_from_file() -> void:
	var expected := "872e4bdc3e6c9c81b38b676bbfa7c6f7a4d09a35f9c94e7d2d0e6f6e5b2f5b6b"
	var result := HashUtils.sha256_from_file("user://mock_test_file.txt")

	AssertionsUtils.assert_eq(result, expected, "❌ File hash mismatch.")


## Tests SHA-256 hashing for a missing file.
func test_sha256_from_nonexistent_file() -> void:
	var result := HashUtils.sha256_from_file("user://nonexistent_file.txt")

	AssertionsUtils.assert_eq(result, "", "❌ Expected empty result for missing file.")


# --- Private Helpers ---


## Creates mock test files in user://
func _prepare_test_files() -> void:
	var file := FileAccess.open("user://mock_test_file.txt", FileAccess.WRITE)
	if file:
		file.store_string("HelloWorld")
		file.close()


## Removes mock test files after tests.
func _cleanup_test_files() -> void:
	if FileAccess.file_exists("user://mock_test_file.txt"):
		DirAccess.remove_absolute("user://mock_test_file.txt")
