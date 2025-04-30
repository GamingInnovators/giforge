extends Node

# --- Description ---
##
## test_otp_helper.gd
##
## Unit tests for OtpHelper.gd
##
## Covers:
## - Signal emission during OTP request
## - Callback execution upon success
## - Failure propagation on invalid OTP
##
## Mocks OtpManager (no singleton), no canvas or visual nodes.

# --- Mock OtpManager (Fake) ---

class MockOtpManager:
	var _valid_codes := {
		"delete_account": "123456",
		"confirm_payment": "987654"
	}

	func validate_otp(reason: String, code: String) -> bool:
		return _valid_codes.get(reason, "") == code


# --- Lifecycle ---

func _ready() -> void:
	_run_tests()


# --- Tests ---

## Runs the full suite for OtpHelper
func _run_tests() -> void:
	print("🧪 Starting OtpHelper test suite...")

	var helper := preload("res://scripts/core/helpers/otp_helper.gd").new()
	helper.set_script(preload("res://scripts/core/helpers/otp_helper.gd"))
	helper._otp_manager = MockOtpManager.new()

	_test_otp_request_and_success(helper)
	_test_otp_failure_signal(helper)

	print("✅ OtpHelper tests completed.")


# --- Test Cases ---

## Verifies that requesting OTP emits signal and validates correctly
func _test_otp_request_and_success(helper: Node) -> void:
	var request_emitted := false
	var validated := false

	# Connect to signals
	helper.otp_requested.connect(func(reason):
		request_emitted = (reason == "delete_account")
	)

	helper.otp_validated.connect(func():
		validated = true
	)

	# Call request with valid reason and callback
	var callback := func(): validated = true
	helper.request_otp("delete_account", callback)

	assert(request_emitted, "❌ Signal 'otp_requested' was not emitted correctly.")

	# Call validate with correct code
	helper.validate_otp("123456")
	assert(validated, "❌ Callback was not executed after valid OTP.")


## Verifies that invalid OTP triggers failure signal
func _test_otp_failure_signal(helper: Node) -> void:
	var failure_reason := ""

	helper.otp_failed.connect(func(reason):
		failure_reason = reason
	)

	helper.request_otp("confirm_payment", func(): assert(false, "❌ Should not call success callback."))

	# Provide wrong code
	helper.validate_otp("WRONG_CODE")

	assert(failure_reason.find("OTP validation failed") != -1, "❌ otp_failed signal not emitted correctly.")
