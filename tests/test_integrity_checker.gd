extends Node


# --- Description ---
##
## Tests for IntegrityChecker.gd
##
## Validates:
## - String signature generation and verification
## - File signature generation and validation
## - Companion `.sig` handling
##
## Mocks and cleanup are included to ensure no side effects persist.


# --- Dependencies ---


var _test_file_path := "user://test_audit.txt"
var _sig_file_path := "user://test_audit.txt.sig"


# --- Lifecycle ---


func before_each() -> void:
	if FileAccess.file_exists(_test_file_path):
		DirAccess.remove_absolute(_test_file_path)
	if FileAccess.file_exists(_sig_file_path):
		DirAccess.remove_absolute(_sig_file_path)


func after_each() -> void:
	before_each()


# --- Tests ---


## Tests SHA-256 signature generation for string input.
func test_generate_signature_from_string() -> void:
	var text := "GLI-19 Audit"
	var signature := IntegrityChecker.generate_signature(text)
	assert(signature.length() == 64, "❌ Signature length invalid (should be 64 chars).")


## Tests verification of string signature (positive case).
func test_verify_signature_string_pass() -> void:
	var text := "123456"
	var signature := IntegrityChecker.generate_signature(text)
	var result := IntegrityChecker.verify_signature(text, signature)
	assert(result == true, "❌ Signature verification should pass.")


## Tests verification of string signature (negative case).
func test_verify_signature_string_fail() -> void:
	var text := "abc"
	var correct_signature := HashUtils.sha256_from_string(text)

	# Modify the correct signature to create an invalid one (flip the first character)
	var wrong_signature := correct_signature.substr(1) + "0"

	var result := IntegrityChecker.verify_signature(text, wrong_signature)
	assert(result == false, "❌ Signature verification should fail on mismatch.")


## Tests file signature generation and persistence.
func test_generate_file_signature_and_save() -> void:
	var file := FileAccess.open(_test_file_path, FileAccess.WRITE)
	file.store_string("Session Started: 2025")
	file.close()

	var save_result := IntegrityChecker.save_file_signature(_test_file_path)
	assert(save_result, "❌ Failed to save file signature.")

	var sig_content := FileAccess.get_file_as_string(_sig_file_path).strip_edges()
	assert(sig_content.length() == 64, "❌ Invalid .sig file content length.")


## Tests file signature validation (positive case).
func test_validate_file_signature_success() -> void:
	var file := FileAccess.open(_test_file_path, FileAccess.WRITE)
	file.store_string("OK")
	file.close()

	IntegrityChecker.save_file_signature(_test_file_path)
	var valid := IntegrityChecker.validate_file_signature(_test_file_path)

	assert(valid, "❌ Expected valid signature match.")


## Tests file signature validation (negative case after tampering).
func test_validate_file_signature_failure_on_tamper() -> void:
	var file := FileAccess.open(_test_file_path, FileAccess.WRITE)
	file.store_string("DATA OK")
	file.close()

	IntegrityChecker.save_file_signature(_test_file_path)

	# Tamper with file
	var file2 := FileAccess.open(_test_file_path, FileAccess.WRITE)
	file2.store_string("DATA TAMPERED")
	file2.close()

	var result := IntegrityChecker.validate_file_signature(_test_file_path)
	assert(not result, "❌ Tampered file should fail signature check.")
