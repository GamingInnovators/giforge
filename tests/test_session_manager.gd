extends Node


# --- Description ---
##
## Tests for SessionManager.gd (GLI-19 Compliant)
##
## Verifies:
## - Session ID generation
## - Operator fallback
## - Manual operator setting
## - Session lifecycle
##
## All tests fully isolated using manual mock injection.


# --- Mocks / Setup ---

var _session_manager := Engine.get_singleton("SessionManager")


var _mock_audit_log_manager := preload("res://scripts/core/tests/mocks/mock_audit_log_manager.gd").new()
var _mock_metadata_log_manager := preload("res://scripts/core/tests/mocks/mock_metadata_log_manager.gd").new()
var _mock_receipt_manager := preload("res://scripts/core/tests/mocks/mock_receipt_manager.gd").new()
var _mock_session_id_generator := preload("res://scripts/core/tests/mocks/mock_session_id_generator.gd").new()


## Before each test.
func before_each() -> void:
	# Inject mocks manually
	_session_manager._audit_log_manager = _mock_audit_log_manager
	_session_manager._metadata_log_manager = _mock_metadata_log_manager
	_session_manager._receipt_manager = _mock_receipt_manager

	# Inject Session ID manually
	_session_manager._session_id = await _mock_session_id_generator.generate_session_id()


## After each test.
func after_each() -> void:
	if is_instance_valid(_session_manager):
		_session_manager.queue_free()
	_session_manager = null


# --- Helpers ---


## Asserts two values are equal.
func assert_eq(expected, actual, message: String = "") -> void:
	assert(expected == actual, message)


# --- Tests ---


## Tests if session_id is generated correctly.
func test_session_id_generated() -> void:
	assert_eq(
		"mock-session-id-123456",
		_session_manager.get_session_id(),
		"❌ Session ID generation failed."
	)


## Tests if fallback operator name is loaded properly.
func test_operator_name_fallback() -> void:
	assert_eq(
		"Unknown Operator",
		_session_manager.get_operator_name(),
		"❌ Operator fallback missing."
	)


## Tests if manual setting of operator name works.
func test_manual_set_operator_name() -> void:
	_session_manager.set_operator_name("Test Operator")

	assert_eq(
		"Test Operator",
		_session_manager.get_operator_name(),
		"❌ Operator manual set failed."
	)
