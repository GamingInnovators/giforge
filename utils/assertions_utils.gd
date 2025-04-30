extends RefCounted
class_name AssertionsUtils


# --- Description ---
##
## AssertionsUtils.gd (GLI-19 Test Helper)
##
## Provides standardized assertion methods for unit tests:
## - assert_eq(actual, expected, message)
## - assert_true(condition, message)
##
## Designed for GLI-19 compliant testing environments.
##


# --- Public Assertion Methods ---


## Asserts that two values are equal.
##
## @param actual Variant: Actual value.
## @param expected Variant: Expected value.
## @param message String: Optional custom failure message.
static func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		var error_message := "❌ Assertion Failed:\nExpected: %s\nGot: %s" % [str(expected), str(actual)]
		if message != "":
			error_message += "\nDetails: %s" % message
		push_error(error_message)
		assert(false)


## Asserts that a condition is true.
##
## @param condition bool: Condition that must be true.
## @param message String: Optional custom failure message.
static func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		var error_message := "❌ Assertion Failed: Condition evaluated as false."
		if message != "":
			error_message += "\nDetails: %s" % message
		push_error(error_message)
		assert(false)


## Asserts that a condition is false.
##
## @param condition bool: Condition that must be false.
## @param message String: Optional custom failure message.
static func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


## Checks that a value is not null.
##
## @param value Variant: Value to test.
## @param message String: Error message if assertion fails.
static func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		push_error(message)
		assert(false)
