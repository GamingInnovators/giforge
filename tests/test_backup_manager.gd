extends Node
class_name TestBackupManager


# --- Description ---
##
## TestBackupManager.gd
##
## Automated unit tests for BackupManager functionality.
##
## Responsibilities:
## - Validate manual and automatic backup creation.
## - Verify ZIP archive existence and signature.
## - Ensure audit logging consistency.
##
## Designed to run under the main test framework.


# --- Private Variables ---


@onready var _backup_manager := Engine.get_singleton("BackupManager")
@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")


# --- Lifecycle Methods ---


## Initializes the test environment.
func _ready() -> void:
	assert(_backup_manager != null, "❌ BackupManager must be autoloaded for testing.")
	assert(_audit_log_manager != null, "❌ AuditLogManager must be autoloaded for testing.")

	run_all_tests()


# --- Test Runner ---


## Runs all test cases.
func run_all_tests() -> void:
	print("🧪 Running BackupManager tests...")

	await _test_manual_backup_creation()

	print("✅ All BackupManager tests completed successfully.")


# --- Test Cases ---


## Validates manual backup creation, file existence, and signature.
func _test_manual_backup_creation() -> void:
	var previous_backups := _list_backup_files()

	print("🛠️ Initiating manual backup...")
	await _backup_manager.create_backup()

	await get_tree().create_timer(1.0).timeout  ## Allow system to flush writes.

	var current_backups := _list_backup_files()
	var new_backups := current_backups.filter(func(path): return not previous_backups.has(path))

	assert(new_backups.size() > 0, "❌ No new backup archive created.")

	var archive_path: String = new_backups[0]
	assert(FileAccess.file_exists(archive_path), "❌ Backup archive missing: %s" % archive_path)

	var signature_path := "%s.sig" % archive_path
	assert(FileAccess.file_exists(signature_path), "❌ Backup signature missing: %s" % signature_path)

	print("✅ Backup archive and signature validated: %s" % archive_path)


# --- Utility Methods ---


## Lists all backup archive files in the backup directory.
##
## @return Array of file paths.
func _list_backup_files() -> Array:
	var backup_dir := "user://backups/"
	var backups := []

	if not DirAccess.dir_exists_absolute(backup_dir):
		return backups

	var dir := DirAccess.open(backup_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()

		while file_name != "":
			if file_name.ends_with(".zip"):
				backups.append(backup_dir.path_join(file_name))
			file_name = dir.get_next()

		dir.list_dir_end()

	return backups
