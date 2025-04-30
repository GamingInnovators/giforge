extends Node
class_name OtpHelper


# --- Description ---
##
## OtpHelper.gd (Optimized, GLI-19 Compliant)
##
## Secure helper for requesting and validating OTP codes during critical actions.
##
## Responsibilities:
## - Emit signal-based OTP request events with descriptive reason.
## - Safely store and execute callback on successful validation.
## - Fully decoupled from UI or input nodes.
##
## Must be manually instantiated (not Autoload).


# --- Signals ---


## Emitted when an OTP validation is requested.
## @param reason String: The reason or context for the OTP request.
signal otp_requested(reason: String)

## Emitted when an OTP is successfully validated.
signal otp_validated()

## Emitted when OTP validation fails.
## @param reason String: Failure message.
signal otp_failed(reason: String)


# --- Private Variables ---


@onready var _otp_manager := Engine.get_singleton("OtpManager")

var _last_reason: String = ""
var _pending_callback: Callable = Callable()


# --- Lifecycle Methods ---


## Ensures that all required dependencies are valid.
func _ready() -> void:
	assert(_otp_manager != null, "❌ OtpManager is not available. Make sure it's registered as Autoload.")


# --- Public Methods ---


## Requests OTP validation for a secure operation.
##
## @param reason String: The context or action description.
## @param callback Callable: The function to invoke if validation succeeds.
func request_otp(reason: String, callback: Callable) -> void:
	assert(reason != "", "❌ OTP reason must not be empty.")
	assert(callback.is_valid(), "❌ Callback must be a valid callable.")

	_last_reason = reason
	_pending_callback = callback

	emit_signal("otp_requested", reason)


## Validates the provided OTP and handles success/failure appropriately.
##
## @param entered_code String: OTP value provided by the user.
func validate_otp(entered_code: String) -> void:
	assert(entered_code != "", "❌ Entered OTP must not be empty.")
	assert(_otp_manager != null, "❌ OtpManager is required.")

	var is_valid: bool = _otp_manager.validate_otp(_last_reason, entered_code)

	if is_valid:
		otp_validated.emit()
		if _pending_callback.is_valid():
			_pending_callback.call()
	else:
		otp_failed.emit("❌ OTP validation failed for reason: %s" % _last_reason)
