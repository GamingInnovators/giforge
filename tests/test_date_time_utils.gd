extends Node
class_name TestDateTimeUtils


# --- Description ---
##
## TestDateTimeUtils.gd
##
## Automated unit tests for DateTimeUtils.gd.
##
## Coverage:
## - UTC timestamp generation
## - Local timestamp generation
## - Current date and time retrieval
## - ISO-8601 parsing and formatting
## - Time difference calculation
##
## GLI-19 Compliant: All tests deterministic, isolated and audit-traceable.


# --- Lifecycle Methods ---


## Prepares environment before each test (no-op here).
func before_each() -> void:
	pass


## Cleans up after each test (no-op here).
func after_each() -> void:
	pass


# --- Utility Methods ---


# --- Tests ---


## Tests UTC timestamp generation (basic format check).
func test_get_utc_timestamp_format() -> void:
	var ts := DateTimeUtils.get_utc_timestamp()
	AssertionsUtils.assert_not_null(ts, "❌ UTC timestamp should not be null.")
	assert(ts.contains("T"), "❌ UTC timestamp missing 'T' separator.")
	assert(ts.ends_with("Z"), "❌ UTC timestamp must end with 'Z'.")


## Tests Local timestamp generation (basic format check).
func test_get_local_timestamp_format() -> void:
	var ts := DateTimeUtils.get_local_timestamp()
	AssertionsUtils.assert_not_null(ts, "❌ Local timestamp should not be null.")
	assert(ts.contains("T"), "❌ Local timestamp missing 'T' separator.")
	assert(!ts.ends_with("Z"), "❌ Local timestamp should not end with 'Z'.")


## Tests Current Date retrieval.
func test_get_current_date_format() -> void:
	var date := DateTimeUtils.get_current_date()
	AssertionsUtils.assert_not_null(date, "❌ Date should not be null.")
	assert(date.split("-").size() == 3, "❌ Date format invalid (expected 3 parts).")


## Tests Current Time retrieval.
func test_get_current_time_format() -> void:
	var time := DateTimeUtils.get_current_time()
	AssertionsUtils.assert_not_null(time, "❌ Time should not be null.")
	assert(time.split(":").size() == 3, "❌ Time format invalid (expected 3 parts).")


## Tests ISO-8601 parsing and basic timestamp consistency.
func test_parse_iso8601_valid() -> void:
	var iso_string := "2025-04-29T15:45:30Z"
	var parsed := DateTimeUtils._parse_iso8601(iso_string)
	assert(parsed > 0, "❌ Parsed timestamp should be positive.")
	

## Tests time difference computation.
func test_compute_time_difference_positive() -> void:
	var start_ts := "2025-04-29T12:00:00Z"
	var end_ts := "2025-04-29T13:00:00Z"
	var diff = DateTimeUtils.compute_time_difference(start_ts, end_ts)
	AssertionsUtils.assert_eq(diff, 3600, "❌ Time difference calculation failed (expected 3600 seconds).")


## Tests time difference computation with inverted timestamps.
func test_compute_time_difference_negative() -> void:
	var start_ts := "2025-04-29T14:00:00Z"
	var end_ts := "2025-04-29T13:00:00Z"
	var diff = DateTimeUtils.compute_time_difference(start_ts, end_ts)
	AssertionsUtils.assert_eq(diff, -3600, "❌ Negative time difference calculation failed (expected -3600 seconds).")
