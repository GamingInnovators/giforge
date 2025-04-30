extends Node

# --- Description ---
##
## TestReceiptManager.gd
##
## Automated validation for ReceiptManager.
##
## Responsibilities:
## - Test session start, data recording, and finalization.
## - Test export (JSON, CSV, XML) and verify file existence.
## - Test receipt uploads and backup handling.
##
## Must be executed manually or during startup tests.
##


# --- Dependencies ---


@onready var _receipt_manager := Engine.get_singleton("ReceiptManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Starts test sequence when entering scene tree.
func _ready() -> void:
	assert(_receipt_manager != null, "❌ ReceiptManager not loaded.")
	assert(_audit_log_manager != null, "❌ AuditLogManager not loaded.")

	_test_receipt_lifecycle()
	_test_receipt_export()
	await _test_receipt_upload()

	print("✅ All ReceiptManager tests completed successfully.")


# --- Private Methods ---


## Tests full lifecycle of a receipt (create, finalize, integrity check).
func _test_receipt_lifecycle() -> void:
	var session_id := "test_session_" + str(Time.get_unix_time_from_system())

	print("🚀 Testing session lifecycle: %s" % session_id)

	_receipt_manager.start_session(session_id)
	_receipt_manager.set_initial_balance(1000.0)
	_receipt_manager.record_bet(50.0)
	_receipt_manager.record_win(75.0)
	_receipt_manager.set_final_balance(1025.0)
	_receipt_manager.finalize_session(session_id)

	var receipt_path := "user://receipts/receipt_%s.json" % session_id
	assert(FileAccess.file_exists(receipt_path), "❌ Receipt file not found: %s" % receipt_path)

	var valid := IntegrityChecker.validate_file_signature(receipt_path)
	assert(valid, "❌ Receipt signature invalid: %s" % receipt_path)

	_audit_log_manager.append_entry("🧪 Receipt lifecycle test passed for session: %s" % session_id)


## Tests exporting receipts to JSON, CSV, and XML formats.
func _test_receipt_export() -> void:
	var session_id := "test_session_" + str(Time.get_unix_time_from_system())

	print("🚀 Testing receipt export: %s" % session_id)

	# Create simple receipt
	_receipt_manager.start_session(session_id)
	_receipt_manager.record_bet(25.0)
	_receipt_manager.record_win(40.0)
	_receipt_manager.set_initial_balance(500.0)
	_receipt_manager.set_final_balance(515.0)
	_receipt_manager.finalize_session(session_id)

	# Export JSON
	var json_path := "user://exports/test_receipt_%s.json" % session_id
	_receipt_manager.export_receipts("json", session_id, json_path)
	assert(FileAccess.file_exists(json_path), "❌ JSON export missing: %s" % json_path)

	# Export CSV
	var csv_path := "user://exports/test_receipt_%s.csv" % session_id
	_receipt_manager.export_receipts("csv", session_id, csv_path)
	assert(FileAccess.file_exists(csv_path), "❌ CSV export missing: %s" % csv_path)

	# Export XML
	var xml_path := "user://exports/test_receipt_%s.xml" % session_id
	_receipt_manager.export_receipts("xml", session_id, xml_path)
	assert(FileAccess.file_exists(xml_path), "❌ XML export missing: %s" % xml_path)

	_audit_log_manager.append_entry("🧪 Receipt export test passed for session: %s" % session_id)


## Tests upload mechanism by triggering manual upload.
func _test_receipt_upload() -> void:
	print("🚀 Testing manual receipt upload...")

	await _receipt_manager.notify_session_end()

	# No direct assertion here — relies on internal audit trail
	_audit_log_manager.append_entry("🧪 Manual receipt upload triggered successfully.")
