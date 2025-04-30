extends Node
class_name MetadataLogManager


# --- Description ---
##
## Unit Test: MetadataLogManager
##
## Tests complete metadata tracking lifecycle:
## - Start session
## - Record metadata
## - Finalize session
## - Export to JSON, XML, CSV
## - Validate signatures
## - Validate compression archive
##
## Location: res://tests/core/test_metadata_log_manager.gd
##
## Requires: MetadataLogManager Autoload
##


# --- Test Constants ---


const TEST_SESSION_ID := "test_session_001"
const TEST_OPERATOR_NAME := "test_operator"
const TEST_SYSTEM_VERSION := "1.0.0"

const JSON_EXPORT_PATH := "user://test_metadata/test_metadata.json"
const XML_EXPORT_PATH := "user://test_metadata/test_metadata.xml"
const CSV_EXPORT_PATH := "user://test_metadata/test_metadata.csv"
const ZIP_EXPORT_PATH := "user://metadata/meta_test_session_001.zip"


# --- Private Variables ---


@onready var _metadata_log_manager := Engine.get_singleton("MetadataLogManager")


# --- Lifecycle Methods ---


func _ready() -> void:
	print("🚀 Running MetadataLogManager Tests...")
	_prepare_test_environment()
	_run_all_tests()
	print("✅ MetadataLogManager Tests Completed.")


# --- Test Methods ---


## Runs all unit tests sequentially.
func _run_all_tests() -> void:
	_test_start_session()
	_test_finalize_session()
	_test_export_metadata_formats()
	_test_validate_integrity()
	_test_validate_compression()


## Prepares the environment before tests.
func _prepare_test_environment() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_metadata/")
	DirAccess.make_dir_recursive_absolute("user://metadata/")
	DirAccess.make_dir_recursive_absolute("user://schemas/")
	print("🛠️ Test environment prepared.")


## Tests starting a session.
func _test_start_session() -> void:
	_metadata_log_manager.start_session(TEST_SESSION_ID, TEST_OPERATOR_NAME, TEST_SYSTEM_VERSION)
	assert(_metadata_log_manager._current_session_id == TEST_SESSION_ID, "❌ Session ID not set correctly.")
	print("✅ Test: Session start.")


## Tests finalizing a session.
func _test_finalize_session() -> void:
	_metadata_log_manager.finalize_session()
	assert(not _metadata_log_manager._current_session_id.is_empty(), "❌ Session ID should still exist until cleanup.")
	print("✅ Test: Session finalized.")


## Tests exporting to JSON, XML, and CSV formats.
func _test_export_metadata_formats() -> void:
	_metadata_log_manager.export_session_json(JSON_EXPORT_PATH, TEST_SESSION_ID)
	_metadata_log_manager.export_session_xml(XML_EXPORT_PATH, TEST_SESSION_ID)
	_metadata_log_manager.export_session_csv(CSV_EXPORT_PATH, TEST_SESSION_ID)

	assert(FileAccess.file_exists(JSON_EXPORT_PATH), "❌ JSON export failed.")
	assert(FileAccess.file_exists(XML_EXPORT_PATH), "❌ XML export failed.")
	assert(FileAccess.file_exists(CSV_EXPORT_PATH), "❌ CSV export failed.")

	print("✅ Test: Metadata export (JSON/XML/CSV).")


## Tests validating SHA-256 signatures.
func _test_validate_integrity() -> void:
	assert(IntegrityChecker.validate_file_signature(JSON_EXPORT_PATH), "❌ JSON signature validation failed.")
	assert(IntegrityChecker.validate_file_signature(XML_EXPORT_PATH), "❌ XML signature validation failed.")
	assert(IntegrityChecker.validate_file_signature(CSV_EXPORT_PATH), "❌ CSV signature validation failed.")
	print("✅ Test: Signature integrity validated.")


## Tests compression archive creation.
func _test_validate_compression() -> void:
	assert(FileAccess.file_exists(ZIP_EXPORT_PATH), "❌ Compressed metadata archive missing.")
	assert(IntegrityChecker.validate_file_signature(ZIP_EXPORT_PATH), "❌ Compressed archive signature invalid.")
	print("✅ Test: Metadata compression and signing validated.")
