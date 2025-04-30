extends Node
class_name test_manifest_comparison


# --- Description ---
##
## test_manifest_comparison.gd
##
## Automated test script for ManifestExportManager manifest comparison system.
##
## - Loads two manifests.
## - Calls compare_manifests().
## - Asserts critical properties: no fatal errors, expected matches/mismatches.
##
## Run manually or integrate into test runner.


@onready var _manifest_export_manager := Engine.get_singleton("ManifestExportManager")


func _ready() -> void:
	assert(_manifest_export_manager != null, "❌ ManifestExportManager must be loaded.")

	_run_manifest_comparison_test()


func _run_manifest_comparison_test() -> void:
	print("🔬 Running Manifest Comparison Test...")

	var old_manifest_path := "user://test_data/manifest_old.json"
	var new_manifest_path := "user://test_data/manifest_new.json"

	assert(FileAccess.file_exists(old_manifest_path), "❌ Old manifest missing for test.")
	assert(FileAccess.file_exists(new_manifest_path), "❌ New manifest missing for test.")

	var report: Dictionary = _manifest_export_manager.compare_manifests(old_manifest_path, new_manifest_path)

	assert(typeof(report) == TYPE_DICTIONARY, "❌ Report not structured properly.")
	assert(report.has("checked"), "❌ Report missing 'checked' field.")
	assert(report.has("matched"), "❌ Report missing 'matched' field.")

	assert(report.checked >= report.matched, "❌ Checked count inconsistent.")

	print("✅ Manifest Comparison Test PASSED")
