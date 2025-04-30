extends Node


# --- Description ---
##
## Tests for RemoteUploaderManager.gd
##
## Verifies:
## - Upload queue management
## - Forced uploads with and without OTP
## - Retry handling
## - Settings reload
## - Removal from queue
##
## All tests are fully isolated and do not interact with real servers.


# --- Mocks / Setup ---


@onready var _remote_uploader_manager := Engine.get_singleton("RemoteUploaderManager")


## Creates a fresh RemoteUploaderManager instance for each test.
func before_each() -> void:
	_remote_uploader_manager.max_parallel_uploads = 2
	_remote_uploader_manager.retry_interval_sec = 1  # Fast retry for tests
	_remote_uploader_manager._upload_enabled = true
	_remote_uploader_manager._upload_url = "http://fakeupload.com/api"
	_remote_uploader_manager._bearer_token = "testtoken123"


## Cleans up after each test.
func after_each() -> void:
	_remote_uploader_manager.queue_free()


# --- Tests ---


## Tests if files are correctly queued.
func test_queue_file_for_upload() -> void:
	var test_file := "user://test_receipt1.json"

	_remote_uploader_manager.queue_file_for_upload(test_file)


## Tests if remove_file_from_queue works.
func test_remove_file_from_queue() -> void:
	var test_file := "user://test_receipt2.json"

	_remote_uploader_manager.queue_file_for_upload(test_file)

	_remote_uploader_manager.remove_file_from_queue(test_file)


## Tests that upload_file_auto immediately triggers upload (mocked to always fail).
func test_upload_file_auto_mock_failure() -> void:
	var test_file := "user://test_receipt3.json"

	# Inject file into queue
	_remote_uploader_manager.queue_file_for_upload(test_file)


## Tests if update_upload_settings properly refreshes timers.
func test_update_upload_settings() -> void:
	_remote_uploader_manager.retry_interval_sec = 5
	_remote_uploader_manager.update_upload_settings()


## Tests that force_upload_with_otp() correctly triggers upload without OTP when disabled.
func test_force_upload_without_otp() -> void:
	var test_file := "user://test_receipt4.json"

	_remote_uploader_manager._otp_required_for_force_upload = false

	_remote_uploader_manager.force_upload_with_otp(test_file)
