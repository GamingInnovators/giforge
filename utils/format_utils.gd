extends RefCounted
class_name FormatUtils


# --- Description ---
##
## FormatUtils.gd
##
## Provides standardized and secure formatting utilities:
## - Localization for monetary, percentage, and abbreviated numbers.
## - Compact representation (e.g., 1.2K, 3.5M).
## - ISO 8601 and human-readable date/time formatting.
##
## All methods are static, deterministic, and side-effect free.
##
## Location: res://scripts/core/utils/format_utils.gd
##
## Not Autoloaded. Used manually by managers and UI systems.


# --- Public Static Methods ---


## Formats a float into a localized monetary string.
##
## @param value float: Monetary value.
## @param with_symbol bool: Prepend the currency symbol if true.
## @return String: Localized formatted string.
static func format_monetary(value: float, with_symbol: bool = false) -> String:
	var locale := TranslationServer.get_locale()
	var decimal_separator := ","
	var thousand_separator := "."
	var symbol := "R$"

	match locale:
		"pt_BR":
			decimal_separator = ","
			thousand_separator = "."
			symbol = "R$"
		"en_US":
			decimal_separator = "."
			thousand_separator = ","
			symbol = "$"
		"es_CR":
			symbol = "₡"
		"fr_FR", "es_ES", "de_DE":
			decimal_separator = ","
			thousand_separator = " "
			symbol = "€"
		_:
			symbol = ""

	if value <= 0.0:
		var zero_value := "0%s00" % decimal_separator
		return "%s %s" % [symbol, zero_value] if with_symbol and symbol != "" else zero_value

	var parts := ("%0.2f" % value).split(".")
	var integer_part := parts[0]
	var decimal_part := parts[1]

	var formatted := ""
	var counter := 0
	for i in range(integer_part.length() - 1, -1, -1):
		formatted = integer_part[i] + formatted
		counter += 1
		if counter % 3 == 0 and i != 0:
			formatted = thousand_separator + formatted

	var result := formatted + decimal_separator + decimal_part
	return "%s %s" % [symbol, result] if with_symbol and symbol != "" else result


## Formats a float value as a percentage string.
##
## @param value float: Value between 0–1 or raw 0–100.
## @param decimals int: Number of decimal places.
## @return String: Percentage string.
static func format_percentage(value: float, decimals: int = 2) -> String:
	var raw := value * 100.0 if value <= 1.0 else value
	return "%.*f%%" % [decimals, raw]


## Formats a float as an abbreviated number string (e.g., 1.2K, 3.4M).
##
## @param value float: Numeric value.
## @return String: Abbreviated number.
static func format_abbreviated_number(value: float) -> String:
	if value >= 1_000_000_000:
		return "%.1fB" % (value / 1_000_000_000.0)
	elif value >= 1_000_000:
		return "%.1fM" % (value / 1_000_000.0)
	elif value >= 1_000:
		return "%.1fK" % (value / 1_000.0)
	else:
		return "%.0f" % value


## Formats a monetary value into a compact form (e.g., R$ 1.2K).
##
## @param value float: Monetary value.
## @return String: Compact monetary string with symbol.
static func format_compact_monetary(value: float) -> String:
	var short_form := format_abbreviated_number(value)
	var locale := TranslationServer.get_locale()
	var symbol := ""

	match locale:
		"en_US": symbol = "$"
		"pt_BR": symbol = "R$"
		"es_CR": symbol = "₡"
		"fr_FR", "es_ES", "de_DE": symbol = "€"
		_: symbol = ""

	return "%s %s" % [symbol, short_form]


## Formats a duration in seconds into MM:SS format.
##
## @param seconds int: Total seconds.
## @return String: Time formatted as MM:SS.
static func format_timer(seconds: int) -> String:
	var minutes := floori(float(seconds) / 60.0)
	var secs := seconds % 60
	return "%02d:%02d" % [minutes, secs]


## Formats a date-time dictionary into a human-readable string.
##
## @param datetime Dictionary: Fields: ["year", "month", "day", "hour", "minute", "second"].
## @return String: Human-readable datetime string.
static func format_datetime_readable(datetime: Dictionary) -> String:
	const REQUIRED_KEYS := ["year", "month", "day", "hour", "minute", "second"]

	for key in REQUIRED_KEYS:
		if not datetime.has(key):
			push_error("❌ Missing required key in datetime: %s" % key)
			return ""

	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
		datetime["second"]
	]


## Formats a date-time dictionary into an ISO 8601 UTC string.
##
## @param datetime Dictionary: Fields: ["year", "month", "day", "hour", "minute", "second"].
## @return String: ISO 8601 formatted UTC string.
static func format_datetime_iso(datetime: Dictionary) -> String:
	const REQUIRED_KEYS := ["year", "month", "day", "hour", "minute", "second"]

	for key in REQUIRED_KEYS:
		if not datetime.has(key):
			push_error("❌ Missing required key in datetime: %s" % key)
			return ""

	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
		datetime["second"]
	]
