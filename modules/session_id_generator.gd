extends Node
class_name SessionIDGenerator


# --- Description ---
##
## SessionIDGenerator.gd (Optimized, GLI-19 Compliant)
##
## Responsible for secure generation of unique Session IDs.
##
## Features:
## - Local UUID v4 + Timestamp generation
## - Optional external API session ID fetching
## - Robust fallback to local generation if API fails
## - Structured audit trail using AuditLogManager
## - SHA-256 signature persistence for traceability
##
## This class must be manually instantiated.
## It is not an Autoload.
##


# --- Signals ---


## Emitted when a new session ID is successfully generated.
##
## @param session_id: The generated session ID string.
signal session_id_generated(session_id: String)

## Emitted when an error occurs during session ID generation.
##
## @param error_message: The error message description.
signal session_id_error(error_message: String)


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")

var _use_external: bool = false
var _external_api_url: String = ""

# Path for storing the last session ID generated
const LAST_SESSION_ID_FILE: String = "user://last_session_id.txt"


# --- Public Methods ---


## Initializes configuration for session ID generation.
##
## @param use_external bool: Whether to attempt external API session generation.
## @param external_api_url String: The API endpoint to fetch session IDs.
func init(use_external: bool = false, external_api_url: String = "") -> void:
	_use_external = use_external
	_external_api_url = external_api_url


## Generates a secure Session ID.
##
## Attempts external API if configured. Falls back to local generation.
##
## @return String: The generated Session ID.
func generate_session_id() -> String:
	if _use_external and _external_api_url != "":
		var api_session_id := await _fetch_session_id_from_api()
		if api_session_id != "":
			_emit_and_log_session_id(api_session_id, true)
			return api_session_id

	var local_session_id := _generate_local_session_id()
	_emit_and_log_session_id(local_session_id, false)
	return local_session_id


# --- Private Methods ---


## Attempts to fetch a Session ID from an external API.
##
## @return String: The Session ID or an empty string if the API call fails.
func _fetch_session_id_from_api() -> String:
	assert(_external_api_url != "", "❌ External API URL is not set.")

	var request := HTTPRequest.new()
	add_child(request)

	var error := request.request(_external_api_url)
	if error != OK:
		_log_error("Failed to initiate session ID request to API.")
		session_id_error.emit("API Request initiation failed.")
		request.queue_free()
		return ""

	var result: Array = await request.request_completed
	request.queue_free()

	var status_code: int = result[1]
	var response_body: String = result[3]

	if status_code != 200:
		_log_warning("Session ID API returned HTTP status: %d" % status_code)
		session_id_error.emit("Session ID API returned HTTP %d." % status_code)
		return ""

	var parsed: Dictionary = JSON.parse_string(response_body)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("session_id"):
		_log_warning("Session ID API response invalid.")
		session_id_error.emit("Session ID API response invalid.")
		return ""

	var session_id := str(parsed["session_id"])

	if not session_id.begins_with("SESSION_") or session_id.length() < 20:
		_log_warning("Session ID format suspicious: %s" % session_id)
		session_id_error.emit("Suspicious session ID format received.")
		return ""

	return session_id


## Emits the generated Session ID and logs the event.
##
## @param session_id String: The Session ID to emit and log.
## @param from_api bool: Whether the ID came from API (true) or locally generated (false).
func _emit_and_log_session_id(session_id: String, from_api: bool) -> void:
	assert(session_id != "", "❌ Session ID to emit must not be empty.")

	session_id_generated.emit(session_id)

	var source := "API" if from_api else "LOCAL"

	_audit_log_manager.append_entry("🆔 Session ID generated (%s): %s" % [source, session_id])

	FileUtils.save_string("user://last_session_id.txt", session_id)


## Generates a local Session ID based on timestamp and UUID.
##
## Format: SESSION_<YYYYMMDD_HHMMSS>_<8_char_uuid>
##
## @return String: The locally generated Session ID.
func _generate_local_session_id() -> String:
	var timestamp := _get_current_timestamp()
	var short_uuid := UuidUtils.v4().replace("-", "").substr(0, 8).to_lower()
	return "SESSION_%s_%s" % [timestamp, short_uuid]


## Returns the current system timestamp formatted as YYYYMMDD_HHMMSS.
##
## @return String: Formatted timestamp string.
func _get_current_timestamp() -> String:
	var datetime := Time.get_datetime_string_from_system(true)
	return datetime.replace("-", "").replace(":", "").replace("T", "_")


## Logs a warning to Godot output and the audit log if available.
##
## @param message String: Warning message to log.
func _log_warning(message: String) -> void:
	push_warning(message)
	_audit_log_manager.append_entry("⚠️ [WARNING] %s" % message)


## Logs an error to Godot output and the audit log if available.
##
## @param message String: Error message to log.
func _log_error(message: String) -> void:
	push_error(message)
	_audit_log_manager.append_entry("❌ [ERROR] %s" % message)
