extends RefCounted
class_name StringUtils


# --- Description ---
##
## StringUtils.gd (Casino Grade, Optimized)
##
## Utility class for advanced and secure string manipulation.
## Designed for casino systems to handle:
## - Localization
## - Normalization
## - Presentation formatting
##
## Characteristics:
## - Static-only deterministic methods
## - No side effects
## - GLI-19 compliant
##
## Location: res://scripts/core/utils/string_utils.gd
## Not Autoloaded — must be loaded manually where needed.


# --- Public Static Methods ---


## Removes accents, diacritics, and common symbols from a string.
##
## @param input String: Input text.
## @return String: Normalized string without accents or symbols.
static func sanitize(input: String) -> String:
	assert(input is String, "❌ Provided input must be a String.")

	var clean := input.strip_edges().to_lower()

	const DIACRITICS := {
		"ç": "c", "ã": "a", "á": "a", "â": "a", "à": "a",
		"é": "e", "ê": "e", "è": "e",
		"í": "i", "ì": "i",
		"ó": "o", "ô": "o", "õ": "o",
		"ú": "u", "ù": "u",
		"ñ": "n"
	}

	for from in DIACRITICS.keys():
		clean = clean.replace(from, DIACRITICS[from])

	clean = clean.replace("-", " ") \
		.replace("_", " ") \
		.replace(".", " ") \
		.replace(",", " ")

	return clean


## Converts a string into a clean URL-safe slug.
##
## @param input String: Input string.
## @return String: Slugified version (kebab-case).
static func slugify(input: String) -> String:
	var base := sanitize(input).replace(" ", "-")

	while base.find("--") >= 0:
		base = base.replace("--", "-")

	var regex := RegEx.new()
	assert(regex.compile("^[-]+|[-]+$") == OK, "❌ RegEx compile error in slugify.")

	return regex.sub(base, "", true)


## Truncates a string safely and appends ellipsis ("...") if exceeded.
##
## @param input String: Input text.
## @param max_length int: Maximum allowed characters.
## @return String: Possibly truncated text.
static func truncate(input: String, max_length: int) -> String:
	assert(input is String, "❌ Input must be a String.")
	assert(max_length > 0, "❌ Max length must be greater than zero.")

	if input.length() <= max_length:
		return input

	return input.substr(0, max_length - 3) + "..."


## Capitalizes each word in a sentence.
##
## @param input String: Raw input.
## @return String: Capitalized result (title case).
static func capitalize_words(input: String) -> String:
	assert(input is String, "❌ Input must be a String.")

	var words := input.strip_edges().to_lower().split(" ")

	for i in words.size():
		if words[i].length() > 0:
			words[i] = words[i][0].to_upper() + words[i].substr(1)

	return " ".join(words)


## Validates if a string contains **only alphabetic** characters (no numbers, spaces or symbols).
##
## @param input String: Input to check.
## @return bool: True if valid, false otherwise.
static func contains_only_letters(input: String) -> bool:
	assert(input is String, "❌ Input must be a String.")

	var regex := RegEx.new()
	assert(regex.compile("^[A-Za-z]+$") == OK, "❌ Failed to compile RegEx.")

	return regex.search(input) != null
