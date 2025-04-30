extends Node

# --- Description ---
##
## TestFileUtils.gd
##
## Tests critical functionality of FileUtils.gd:
## - JSON save/load
## - CSV/XML save
## - File delete
## - File existence check
##
## GLI-19 Compliant Test Plan:
## - Full isolation
## - Audit integrity
## - No side-effects

# --- Dependencies ---

const TEST_JSON_PATH := "user://test_fileutils.json"
const TEST_CSV_PATH := "user://test_fileutils.csv"
const TEST_XML_PATH := "user://test_fileutils.xml"
const TEST_SECURE_BIN_PATH := "user://test_fileutils_secure.dat"
const TEST_PASSWORD := "testpassword123"

# --- Setup and Teardown ---

func before_each() -> void:
	_cleanup_files()


func after_each() -> void:
	_cleanup_files()


func _cleanup_files() -> void:
	var files = [
		TEST_JSON_PATH,
		TEST_CSV_PATH,
		TEST_XML_PATH,
		TEST_SECURE_BIN_PATH
	]

	for file_path in files:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)

		if FileAccess.file_exists(file_path + ".sig"):
			DirAccess.remove_absolute(file_path + ".sig")


# --- Tests ---


## Tests saving and loading JSON data.
func test_save_and_load_json() -> void:
	var data := {
		"test_key": "test_value",
		"number": 12345
	}

	FileUtils.save_json(TEST_JSON_PATH, data)

	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_JSON_PATH), "❌ JSON file not created.")
	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_JSON_PATH + ".sig"), "❌ JSON signature missing.")

	var loaded = FileUtils.load_json(TEST_JSON_PATH)
	AssertionsUtils.assert_eq(loaded.get("test_key", ""), "test_value", "❌ Loaded JSON mismatch.")
	AssertionsUtils.assert_eq(loaded.get("number", 0), 12345, "❌ Loaded number mismatch.")


## Tests saving CSV format.
func test_save_csv() -> void:
	var csv_data := [
		{"name": "Alice", "age": 30},
		{"name": "Bob", "age": 25}
	]

	FileUtils.save_csv(TEST_CSV_PATH, csv_data)

	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_CSV_PATH), "❌ CSV file not created.")
	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_CSV_PATH + ".sig"), "❌ CSV signature missing.")

	var file := FileAccess.open(TEST_CSV_PATH, FileAccess.READ)
	AssertionsUtils.assert_true(file != null, "❌ Cannot open CSV file.")
	file.close()


## Tests saving XML format.
func test_save_xml() -> void:
	var xml_data := [
		{"country": "Brazil", "capital": "Brasília"},
		{"country": "Japan", "capital": "Tokyo"}
	]

	FileUtils.save_xml(TEST_XML_PATH, xml_data)

	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_XML_PATH), "❌ XML file not created.")
	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_XML_PATH + ".sig"), "❌ XML signature missing.")

	var file := FileAccess.open(TEST_XML_PATH, FileAccess.READ)
	AssertionsUtils.assert_true(file != null, "❌ Cannot open XML file.")
	file.close()


## Tests deletion of a file.
func test_delete_file() -> void:
	var dummy_path := "user://dummy_delete.txt"
	var file := FileAccess.open(dummy_path, FileAccess.WRITE)
	AssertionsUtils.assert_true(file != null, "❌ Failed to create dummy file for delete test.")
	file.store_line("Test delete content.")
	file.close()

	AssertionsUtils.assert_true(FileAccess.file_exists(dummy_path), "❌ Dummy file not created before delete.")

	FileUtils.delete_file(dummy_path)

	AssertionsUtils.assert_false(FileAccess.file_exists(dummy_path), "❌ File not deleted properly.")


## Tests is_valid_file correctly detects valid files.
func test_is_valid_file() -> void:
	var valid_path := "user://dummy_valid.txt"
	var file := FileAccess.open(valid_path, FileAccess.WRITE)
	AssertionsUtils.assert_true(file != null, "❌ Failed to create dummy file.")
	file.store_line("Test valid file.")
	file.close()

	AssertionsUtils.assert_true(FileUtils.is_valid_file(valid_path), "❌ Valid file not detected.")

	FileUtils.delete_file(valid_path)

	AssertionsUtils.assert_false(FileUtils.is_valid_file(valid_path), "❌ Invalid file falsely detected as valid.")



func fail_test() -> void:
	assert(false, "❌ Test failure enforced.")


# --- Additional Secure File Tests ---

## Tests saving and loading encrypted binary file securely.
func test_save_and_load_secure_bin() -> void:
	var secure_data := {
		"secure_key": "secure_value",
		"amount": 9876
	}

	var save_result := FileUtils.save_secure_bin(TEST_SECURE_BIN_PATH, secure_data, TEST_PASSWORD)
	AssertionsUtils.assert_true(save_result, "❌ Failed to save secure binary file.")

	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_SECURE_BIN_PATH), "❌ Secure binary file missing.")
	AssertionsUtils.assert_true(FileAccess.file_exists(TEST_SECURE_BIN_PATH + ".sig"), "❌ Secure binary signature missing.")

	var loaded_data: Dictionary = FileUtils.load_secure_bin(TEST_SECURE_BIN_PATH, TEST_PASSWORD)
	AssertionsUtils.assert_true(loaded_data != null, "❌ Failed to load secure binary file.")

	AssertionsUtils.assert_eq(loaded_data.get("secure_key", ""), "secure_value", "❌ Secure binary content mismatch (secure_key).")
	AssertionsUtils.assert_eq(loaded_data.get("amount", 0), 9876, "❌ Secure binary content mismatch (amount).")


## Tests load_secure_bin failure with wrong password.
func test_load_secure_bin_wrong_password() -> void:
	var secure_data := {
		"test_fail": true
	}

	var save_result := FileUtils.save_secure_bin(TEST_SECURE_BIN_PATH, secure_data, TEST_PASSWORD)
	AssertionsUtils.assert_true(save_result, "❌ Failed to save secure binary file for wrong password test.")

	var loaded_data = FileUtils.load_secure_bin(TEST_SECURE_BIN_PATH, "wrongpassword")
	AssertionsUtils.assert_true(loaded_data == null, "❌ Secure binary loaded incorrectly with wrong password.")
