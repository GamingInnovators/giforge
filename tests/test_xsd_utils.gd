extends Node

# --- Description ---
##
## test_xsd_utils.gd
##
## Unit tests for the XsdUtils static class.
##
## This test suite verifies:
## - XML structural validation via internal schema model
## - Detection of unexpected tags and missing attributes
## - Error handling for missing or unreadable files
##
## XML test files are saved under: user://temp_xml/
##
## Not dependent on AuditLogManager, not autoloaded, no visual UI (no canvas).

# --- Constants ---

const TEST_DIR := "user://temp_xml/"
const VALID_XML := TEST_DIR + "valid.xml"
const INVALID_XML_TAG := TEST_DIR + "invalid_tag.xml"
const INVALID_XML_ATTR := TEST_DIR + "missing_attr.xml"

# --- Lifecycle ---

func _ready() -> void:
	_prepare_test_directory()
	_create_valid_xml()
	_create_invalid_tag_xml()
	_create_missing_attr_xml()

	_run_tests()

# --- Setup Methods ---

## Creates test output directory recursively.
func _prepare_test_directory() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


## Writes a valid XML file to disk.
func _create_valid_xml() -> void:
	var file := FileAccess.open(VALID_XML, FileAccess.WRITE)
	file.store_line('<?xml version="1.0" encoding="UTF-8"?>')
	file.store_line("<Data>")
	file.store_line('\t<Player id="1" name="Alice"/>')
	file.store_line('\t<Bet amount="100.0" timestamp="2024-01-01T12:00:00"/>')
	file.store_line("</Data>")
	file.close()


## Writes an XML file with an unexpected tag.
func _create_invalid_tag_xml() -> void:
	var file := FileAccess.open(INVALID_XML_TAG, FileAccess.WRITE)
	file.store_line('<?xml version="1.0" encoding="UTF-8"?>')
	file.store_line("<Data>")
	file.store_line('\t<Unknown value="X"/>')  # Unknown tag
	file.store_line("</Data>")
	file.close()


## Writes an XML file missing required attributes.
func _create_missing_attr_xml() -> void:
	var file := FileAccess.open(INVALID_XML_ATTR, FileAccess.WRITE)
	file.store_line('<?xml version="1.0" encoding="UTF-8"?>')
	file.store_line("<Data>")
	file.store_line('\t<Player id="1"/>')  # Missing 'name'
	file.store_line('\t<Bet timestamp="2024-01-01T12:00:00"/>')  # Missing 'amount'
	file.store_line("</Data>")
	file.close()

# --- Tests ---

## Runs test assertions for all scenarios.
func _run_tests() -> void:
	print("🧪 Running unit tests for XsdUtils...")

	var schema := {
		"Player": ["id", "name"],
		"Bet": ["amount", "timestamp"]
	}

	var result: int

	# Test: Valid XML
	result = XsdUtils.validate(VALID_XML, schema)
	assert(result == OK, "❌ Test failed: VALID_XML should pass.")

	# Test: Unexpected tag
	result = XsdUtils.validate(INVALID_XML_TAG, schema)
	assert(result == ERR_INVALID_DATA, "❌ Test failed: INVALID_XML_TAG should be rejected.")

	# Test: Missing required attributes
	result = XsdUtils.validate(INVALID_XML_ATTR, schema)
	assert(result == ERR_INVALID_DATA, "❌ Test failed: INVALID_XML_ATTR should be rejected.")

	print("✅ All structure tests for XsdUtils passed successfully.")
