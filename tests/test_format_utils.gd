extends Node

# --- Description ---
##
## Tests for FormatUtils.gd
##
## Verifies:
## - Monetary formatting
## - Percentage formatting
## - Abbreviated number formatting
## - Compact monetary formatting
## - Timer formatting
## - Datetime human-readable and ISO8601 formatting
##
## All tests deterministic and isolated.


# --- Dependencies ---


var _format_utils := FormatUtils


# --- Tests ---


## Tests formatting monetary values in default locale.
func test_format_monetary_default_locale() -> void:
	var formatted := _format_utils.format_monetary(1234.56, true)
	AssertionsUtils.assert_true(formatted.find("1") >= 0, "❌ Failed to format monetary (default locale).")


## Tests formatting percentage values.
func test_format_percentage_basic() -> void:
	var formatted := _format_utils.format_percentage(0.25)
	AssertionsUtils.assert_eq(formatted, "25.00%", "❌ Incorrect basic percentage formatting.")

	var formatted_full := _format_utils.format_percentage(75.0)
	AssertionsUtils.assert_eq(formatted_full, "75.00%", "❌ Incorrect raw 0–100 percentage formatting.")


## Tests formatting abbreviated numbers.
func test_format_abbreviated_numbers() -> void:
	AssertionsUtils.assert_eq(_format_utils.format_abbreviated_number(999), "999", "❌ Incorrect abbreviated for < 1000.")
	AssertionsUtils.assert_eq(_format_utils.format_abbreviated_number(1200), "1.2K", "❌ Incorrect abbreviated for 1.2K.")
	AssertionsUtils.assert_eq(_format_utils.format_abbreviated_number(2500000), "2.5M", "❌ Incorrect abbreviated for 2.5M.")
	AssertionsUtils.assert_eq(_format_utils.format_abbreviated_number(4500000000), "4.5B", "❌ Incorrect abbreviated for 4.5B.")


## Tests compact monetary formatting.
func test_format_compact_monetary() -> void:
	var compact := _format_utils.format_compact_monetary(2500)
	AssertionsUtils.assert_true(compact.find("K") > 0, "❌ Compact monetary should contain 'K' for thousands.")


## Tests timer formatting in MM:SS.
func test_format_timer() -> void:
	AssertionsUtils.assert_eq(_format_utils.format_timer(75), "01:15", "❌ Incorrect timer formatting for 75 seconds.")
	AssertionsUtils.assert_eq(_format_utils.format_timer(600), "10:00", "❌ Incorrect timer formatting for 600 seconds.")


## Tests human-readable datetime formatting.
func test_format_datetime_readable_valid() -> void:
	var dt := {
		"year": 2024, "month": 4, "day": 27,
		"hour": 14, "minute": 30, "second": 15
	}
	var formatted := _format_utils.format_datetime_readable(dt)
	AssertionsUtils.assert_eq(formatted, "2024-04-27 14:30:15", "❌ Incorrect human-readable datetime formatting.")


## Tests ISO 8601 datetime formatting.
func test_format_datetime_iso_valid() -> void:
	var dt := {
		"year": 2024, "month": 4, "day": 27,
		"hour": 14, "minute": 30, "second": 15
	}
	var formatted := _format_utils.format_datetime_iso(dt)
	AssertionsUtils.assert_eq(formatted, "2024-04-27T14:30:15Z", "❌ Incorrect ISO8601 datetime formatting.")
