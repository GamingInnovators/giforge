extends Node
class_name TestRunner


# --- Description ---
##
## TestRunner.gd
##
## Automated test runner for all files inside res://tests/
##
## Loads all "test_*.gd" dynamically and executes "_run_tests()" asynchronously.
##
## Located at: res://tests/test_runner.gd
##
## Recommended to run manually inside editor or setup as a tool.


# --- Constants ---


const TESTS_PATH: String = "res://tests/"


# --- Lifecycle Methods ---


func _ready() -> void:
	print("🧪 TestRunner started...")
	await _execute_all_tests()
	print("✅ All tests finished.")


# --- Private Methods ---


## Loads and executes all test files asynchronously.
func _execute_all_tests() -> void:
	var dir := DirAccess.open(TESTS_PATH)
	if dir == null:
		push_error("❌ Failed to open tests folder.")
		return

	dir.list_dir_begin()

	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			var file_path := "%s%s" % [TESTS_PATH, file_name]
			print("- Loading Test: %s" % file_path)

			var test_scene := load(file_path)
			if test_scene:
				var test_instance = test_scene.new()
				add_child(test_instance)
				await test_instance._run_tests()
				test_instance.queue_free()

		file_name = dir.get_next()

	dir.list_dir_end()
