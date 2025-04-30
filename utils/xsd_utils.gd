extends RefCounted
class_name XsdUtils


# --- Description ---
##
## XsdUtils.gd (Standalone XML Validator)
##
## Provides strict XML validation against:
## - External XSD schemas (via `xmllint` binary, if allowed).
## - Internal structural definitions (fallback dictionary).
##
## GLI-19 Compliant:
## - Avoids singleton usage.
## - Modular and testable.
## - No side effects (pure validation).
##
## Usage:
##   var result = XsdUtils.validate_with_xsd("res://file.xml", "res://schema.xsd")
##   var result = XsdUtils.validate("res://file.xml", { "Entry": ["id", "value"] })
##
## Not Autoloaded.


# --- Public Static Methods ---


## Validates an XML file using an external XSD schema.
##
## @param xml_path String: Path to the XML file (must end with `.xml`).
## @param xsd_path String: Path to the XSD file (must end with `.xsd`).
## @return int: OK (0) on success, or error code (ERR_*) on failure.
static func validate_with_xsd(xml_path: String, xsd_path: String) -> int:
	assert(xml_path.ends_with(".xml"), "❌ XML path must end with '.xml'.")
	assert(xsd_path.ends_with(".xsd"), "❌ XSD path must end with '.xsd'.")

	if not FileAccess.file_exists(xml_path):
		push_error("❌ XML file not found: %s" % xml_path)
		return ERR_FILE_NOT_FOUND

	if not FileAccess.file_exists(xsd_path):
		push_error("❌ XSD schema not found: %s" % xsd_path)
		return ERR_FILE_NOT_FOUND

	if not OS.has_feature("standalone"):
		push_warning("⚠️ XSD validation skipped in editor mode.")
		return ERR_UNAVAILABLE

	var args := ["--noout", "--schema", xsd_path, xml_path]
	var output: Array = []

	var result := OS.execute("xmllint", args, output)

	if result != OK:
		push_warning("⚠️ XSD validation failed:\n%s" % String("\n".join(output)))
		return ERR_INVALID_DATA

	return OK


## Validates an XML file using a fallback internal structure definition.
##
## @param xml_path String: Path to the XML file.
## @param expected_structure Dictionary: Tag-based model: { tag: [required_attr1, ...] }
## @return int: OK if valid, otherwise ERR_INVALID_DATA.
static func validate(xml_path: String, expected_structure: Dictionary) -> int:
	assert(xml_path.ends_with(".xml"), "❌ XML path must end with '.xml'.")
	assert(typeof(expected_structure) == TYPE_DICTIONARY, "❌ Expected structure must be a Dictionary.")

	if not FileAccess.file_exists(xml_path):
		push_error("❌ XML file not found: %s" % xml_path)
		return ERR_FILE_NOT_FOUND

	var parser := XMLParser.new()
	var status := parser.open(xml_path)

	if status != OK:
		push_error("❌ Failed to open XML: %s" % xml_path)
		return ERR_CANT_OPEN

	return _validate_structure(parser, expected_structure)


# --- Private Static Methods ---


## Validates XML structure and required attributes using a predefined fallback dictionary.
##
## @param parser XMLParser: Opened XML parser instance.
## @param expected_structure Dictionary: { tag: [required_attribute1, required_attribute2, ...] }
## @return int: OK if structure matches; otherwise ERR_INVALID_DATA.
static func _validate_structure(parser: XMLParser, expected_structure: Dictionary) -> int:
	assert(parser != null, "❌ XML parser instance is null.")
	assert(expected_structure.size() > 0, "❌ Expected structure dictionary must not be empty.")

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()

				# Tag not expected in schema model
				if not expected_structure.has(tag):
					push_warning("⚠️ Unexpected tag found: '%s'" % tag)
					return ERR_INVALID_DATA

				var required_attributes: Array = expected_structure[tag]
				for attribute in required_attributes:
					if not parser.has_attribute(attribute):
						push_warning("⚠️ Missing required attribute '%s' in tag '%s'" % [attribute, tag])
						return ERR_INVALID_DATA

	return OK
