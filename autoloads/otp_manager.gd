extends Node
class_name OtpManager


# --- Description ---
##
## OtpManager.gd (GLI-19 Certified, Unified Version)
##
## Centralized manager for secure One-Time Password (OTP) generation, validation, and UI-integrated requests.
##
## Responsibilities:
## - TOTP-like secure OTP generation using HMAC-SHA256
## - Clock drift and fallback key tolerance
## - Full audit logging (AuditLogManager)
## - Signal-based validation requests (replacing OtpHelper)
##
## Must be registered as Autoload (singleton).
##


# --- Signals ---


## Emitted to trigger OTP validation UI.
signal otp_requested(reason: String)

## Emitted when OTP validation succeeds.
signal otp_validated(operation: String)

## Emitted when OTP validation fails.
signal otp_validation_failed(operation: String)


# --- Constants ---


const DEFAULT_VALIDITY_WINDOW_SEC := 30
const DEFAULT_CLOCK_DRIFT_WINDOWS := 1
const DEFAULT_SECRET_KEY := "DEFAULT-OTP-KEY-012345"
const DEFAULT_FALLBACK_KEY := "DEFAULT-FALLBACK-KEY-6789"


# --- Public Variables ---


@export var validity_window_sec: int = DEFAULT_VALIDITY_WINDOW_SEC
@export var clock_drift_windows: int = DEFAULT_CLOCK_DRIFT_WINDOWS


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")

var _primary_secret_key: String = DEFAULT_SECRET_KEY
var _fallback_secret_key: String = DEFAULT_FALLBACK_KEY

var _last_reason: String = ""
var _pending_callback: Callable = Callable()


# --- Lifecycle Methods ---


## Initializes the OtpManager and loads secure keys.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")
	assert(_settings_manager != null, "❌ SettingsManager is required.")

	_load_settings()

	assert(_primary_secret_key.length() >= 16, "❌ Primary secret key must be at least 16 characters.")
	assert(_fallback_secret_key.length() >= 16, "❌ Fallback secret key must be at least 16 characters.")

	_audit_log_manager.append_entry("🔐 OtpManager initialized | Window: %ds | Drift: ±%d" % [validity_window_sec, clock_drift_windows])


## Loads keys and drift settings from SettingsManager.
func _load_settings() -> void:
	_primary_secret_key = _settings_manager.get_setting("otp_primary_key", DEFAULT_SECRET_KEY)
	_fallback_secret_key = _settings_manager.get_setting("otp_fallback_key", DEFAULT_FALLBACK_KEY)
	validity_window_sec = _settings_manager.get_setting("otp_validity_window_sec", DEFAULT_VALIDITY_WINDOW_SEC)
	clock_drift_windows = _settings_manager.get_setting("otp_clock_drift_windows", DEFAULT_CLOCK_DRIFT_WINDOWS)


# --- Public Methods ---


## Emits a signal to request OTP input for a specific operation.
##
## @param reason String: The reason or context (e.g. "Force Upload", "Backup Wipe").
## @param callback Callable: Function to execute if validation succeeds.
func request_otp(reason: String, callback: Callable) -> void:
	assert(reason != "", "❌ OTP reason must not be empty.")
	assert(callback.is_valid(), "❌ Callback must be a valid Callable.")

	_last_reason = reason
	_pending_callback = callback

	emit_signal("otp_requested", reason)


## Handles validation of a submitted OTP from user input.
##
## @param entered_code String: Code entered by user.
func validate_otp_input(entered_code: String) -> void:
	assert(entered_code != "", "❌ Entered OTP must not be empty.")
	assert(_last_reason != "", "❌ No OTP reason available for validation.")

	if validate_otp(_last_reason, entered_code):
		if _pending_callback.is_valid():
			_pending_callback.call()
	else:
		emit_signal("otp_validation_failed", _last_reason)


## Generates an OTP code for the current timestamp.
##
## @param operation String: Logical operation name.
## @return String: 6-digit OTP code.
func generate_otp(operation: String) -> String:
	assert(operation != "", "❌ Operation name is required.")

	var timestamp := int(Time.get_unix_time_from_system() / validity_window_sec)
	var raw := "%s|%d" % [operation, timestamp]

	var otp := _generate_hmac_sha256(raw, _primary_secret_key).hex_encode().substr(0, 6).to_upper()

	_audit_log_manager.append_entry("🔑 OTP generated for: %s" % operation)

	return otp


## Validates OTP with primary and fallback keys across drift.
##
## @param operation String: Operation name.
## @param submitted_code String: User-provided OTP.
## @return bool: True if valid.
func validate_otp(operation: String, submitted_code: String) -> bool:
	assert(operation != "", "❌ Operation name must not be empty.")
	assert(submitted_code != "", "❌ OTP input must not be empty.")

	var window := int(Time.get_unix_time_from_system() / validity_window_sec)

	if _check_drift(operation, submitted_code, _primary_secret_key, window):
		emit_signal("otp_validated", operation)
		return true

	if _check_drift(operation, submitted_code, _fallback_secret_key, window):
		_audit_log_manager.append_entry("⚡ OTP fallback validated for: %s" % operation)
		emit_signal("otp_validated", operation)
		return true

	_audit_log_manager.append_entry("⛔ OTP validation failed for: %s" % operation)
	emit_signal("otp_validation_failed", operation)
	return false


# --- Private Methods ---


## Validates an OTP across allowed drift range for a given key.
##
## @param operation String: Logical operation name.
## @param submitted_code String: OTP provided by user.
## @param key String: Secret key to use.
## @param window int: Current time window.
## @return bool: True if match found.
func _check_drift(operation: String, submitted_code: String, key: String, window: int) -> bool:
	for offset in range(-clock_drift_windows, clock_drift_windows + 1):
		var adjusted_window := window + offset
		var raw := "%s|%d" % [operation, adjusted_window]
		var expected := _generate_hmac_sha256(raw, key).hex_encode().substr(0, 6).to_upper()

		if expected == submitted_code.to_upper():
			_audit_log_manager.append_entry("✅ OTP drift offset %d matched for: %s" % [offset, operation])
			return true

	return false


## Performs HMAC-SHA256 using the given key.
##
## @param message String: Raw message.
## @param key String: Secret key.
## @return PackedByteArray: Digest.
func _generate_hmac_sha256(message: String, key: String) -> PackedByteArray:
	assert(message != "", "❌ Message cannot be empty.")
	assert(key != "", "❌ Secret key cannot be empty.")

	var key_bytes := key.to_utf8_buffer()

	# Step 1: If key is longer than 64 bytes, hash it first
	if key_bytes.size() > 64:
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(key_bytes)
		key_bytes = ctx.finish()

	# Step 2: Pad key to 64 bytes
	if key_bytes.size() < 64:
		key_bytes.resize(64)

	# Step 3: Create o_key_pad and i_key_pad
	var o_key_pad := PackedByteArray()
	var i_key_pad := PackedByteArray()

	for i in range(64):
		o_key_pad.append(key_bytes[i] ^ 0x5C)
		i_key_pad.append(key_bytes[i] ^ 0x36)

	# Step 4: Inner SHA256
	var inner := HashingContext.new()
	inner.start(HashingContext.HASH_SHA256)
	inner.update(i_key_pad)
	inner.update(message.to_utf8_buffer())
	var inner_result := inner.finish()

	# Step 5: Outer SHA256
	var outer := HashingContext.new()
	outer.start(HashingContext.HASH_SHA256)
	outer.update(o_key_pad)
	outer.update(inner_result)

	return outer.finish()
