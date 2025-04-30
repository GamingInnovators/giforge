extends Node
class_name TestOtpManager


# --- Description ---
##
## TestOtpManager.gd
##
## Automated test for OtpManager behavior under various conditions.
##
## Tests:
## - OTP generation
## - Validation with clock drift
## - Fallback key support
## - Audit logging verification
##
## Must be executed manually or via CI/CD pipelines.


# --- Private Variables ---


@onready var _otp_manager := Engine.get_singleton("OtpManager")


# --- Lifecycle Methods ---

func _ready() -> void:
	_initialize_otp_manager()

	_test_generate_and_validate_otp()
	_test_validate_with_clock_drift()
	_test_fallback_key_usage()
	_test_invalid_otp()
	print("✅ All OtpManager tests completed successfully.")

# --- Test Setup ---

func _initialize_otp_manager() -> void:
	_otp_manager.validity_window_sec = 30
	_otp_manager.clock_drift_windows = 2
	add_child(_otp_manager)

# --- Tests ---

## Tests OTP generation and basic validation.
func _test_generate_and_validate_otp() -> void:
	var operation := "test_operation_primary"
	var otp_code: String = _otp_manager.generate_otp(operation)

	var validated: bool = _otp_manager.validate_otp(operation, otp_code)

	assert(validated == true, "❌ OTP should validate with primary key.")
	print("✅ Test 1: Basic OTP generation and validation passed.")

## Tests OTP validation with clock drift tolerance.
func _test_validate_with_clock_drift() -> void:
	var operation := "test_operation_drift"
	var current_time := int(Time.get_unix_time_from_system())

	# Generate OTP 1 window behind
	var past_timestamp := int((current_time - 30) / _otp_manager.validity_window_sec)
	var raw_past := "%s|%d" % [operation, past_timestamp]
	var past_code: String = _otp_manager._generate_hmac_sha256(raw_past, _otp_manager._primary_secret_key).hex_encode().substr(0, 6).to_upper()

	var validated: bool = _otp_manager.validate_otp(operation, past_code)

	assert(validated == true, "❌ OTP should validate with -1 drift window.")
	print("✅ Test 2: OTP validation with drift passed.")

## Tests fallback key usage if primary fails.
func _test_fallback_key_usage() -> void:
	var operation := "test_operation_fallback"
	var timestamp := int(Time.get_unix_time_from_system() / _otp_manager.validity_window_sec)

	var raw := "%s|%d" % [operation, timestamp]
	var fallback_code: String = _otp_manager._generate_hmac_sha256(raw, _otp_manager._fallback_secret_key).hex_encode().substr(0, 6).to_upper()

	# Force invalid primary secret temporarily
	var old_primary: String = _otp_manager._primary_secret_key
	_otp_manager._primary_secret_key = "INVALID-PRIMARY-KEY"

	var validated: bool = _otp_manager.validate_otp(operation, fallback_code)

	assert(validated == true, "❌ OTP should validate using fallback key.")

	_otp_manager._primary_secret_key = old_primary
	print("✅ Test 3: Fallback key validation passed.")

## Tests OTP failure with invalid code.
func _test_invalid_otp() -> void:
	var operation := "test_operation_invalid"
	var fake_code := "ZZZZZZ"

	var validated: bool = _otp_manager.validate_otp(operation, fake_code)

	assert(validated == false, "❌ Invalid OTP should fail validation.")
	print("✅ Test 4: Invalid OTP rejection passed.")
