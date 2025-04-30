extends RefCounted
class_name DateTimeUtils


# --- Description ---
##
## DateTimeUtils.gd (GLI-19 Compliant, Optimized)
##
## Utility class for handling date and time operations safely.
##
## Responsibilities:
## - Deterministic datetime parsing and formatting
## - System UTC and local time retrieval
## - ISO-8601 and custom format support
## - Time difference computation
##
## Usage: Must be loaded manually when needed (NOT Autoload).
##
## Fully compliant with GLI-19 for timestamping and logging critical operations.


# --- Public Static Methods ---


## Returns the current system time in ISO-8601 UTC format.
##
## @return String: Timestamp string (e.g., "2025-04-29T12:34:56Z").
static func get_utc_timestamp() -> String:
	var time := Time.get_datetime_dict_from_system(true)
	return _format_datetime_dict(time) + "Z"


## Returns the current system time in ISO-8601 local time format.
##
## @return String: Timestamp string (e.g., "2025-04-29T09:34:56").
static func get_local_timestamp() -> String:
	var time := Time.get_datetime_dict_from_system(false)
	return _format_datetime_dict(time)


## Returns the current system date in "YYYY-MM-DD" format.
##
## @return String: Formatted date string.
static func get_current_date() -> String:
	var date := Time.get_date_dict_from_system(false)
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]


## Returns the current system time in "HH:MM:SS" format.
##
## @return String: Formatted time string.
static func get_current_time() -> String:
	var time := Time.get_time_dict_from_system(false)
	return "%02d:%02d:%02d" % [time.hour, time.minute, time.second]


## Computes the difference between two ISO-8601 timestamps (in seconds).
##
## @param start_ts String: ISO-8601 formatted start timestamp.
## @param end_ts String: ISO-8601 formatted end timestamp.
## @return int: Difference in seconds (positive or negative) or null.
static func compute_time_difference(start_ts: String, end_ts: String) -> Variant:
	assert(start_ts != "", "❌ Start timestamp must not be empty.")
	assert(end_ts != "", "❌ End timestamp must not be empty.")

	var start_time := _parse_iso8601(start_ts)
	var end_time := _parse_iso8601(end_ts)

	if start_time == 0 or end_time == 0:
		push_warning("⚠️ Timestamp parsing failed. Returning null.")
		return null

	return int(end_time - start_time)


## Parses an ISO-8601 datetime string into a Unix timestamp (seconds since epoch).
##
## @param iso_string String: ISO-8601 formatted datetime string.
## @return int: Unix timestamp.
static func _parse_iso8601(iso_string: String) -> int:
	assert(iso_string != "", "❌ ISO string must not be empty.")

	# Expected format: "YYYY-MM-DDTHH:MM:SSZ" or "YYYY-MM-DDTHH:MM:SS"
	var date_time := iso_string.replace("T", " ").replace("Z", "")
	var parts := date_time.split(" ")

	assert(parts.size() == 2, "❌ Invalid ISO-8601 timestamp format: %s" % iso_string)

	var date_parts := parts[0].split("-")
	var time_parts := parts[1].split(":")

	if date_parts.size() != 3 or time_parts.size() != 3:
		push_error("❌ Invalid ISO date/time components: %s" % iso_string)
		return 0

	assert(date_parts[0].is_valid_int(), "❌ Invalid year component in ISO string.")
	var year := int(date_parts[0])
	var month := int(date_parts[1])
	var day := int(date_parts[2])
	var hour := int(time_parts[0])
	var minute := int(time_parts[1])
	var second := int(time_parts[2])

	var datetime := {
		"year": year, 
		"month": month, 
		"day": day, 
		"hour": hour, 
		"minute": minute, 
		"second": second
	}

	return Time.get_unix_time_from_datetime_dict(datetime)


## Formats a datetime dictionary into an ISO-8601 string (without 'Z').
##
## @param dt_dict Dictionary: Dictionary with datetime keys.
## @return String: Formatted ISO-8601 string.
static func _format_datetime_dict(dt_dict: Dictionary) -> String:
	assert(typeof(dt_dict) == TYPE_DICTIONARY, "❌ Expected dictionary input for datetime formatting.")

	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		dt_dict.get("year", 1970),
		dt_dict.get("month", 1),
		dt_dict.get("day", 1),
		dt_dict.get("hour", 0),
		dt_dict.get("minute", 0),
		dt_dict.get("second", 0)
	]
