extends Node


# --- Description ---
##
## BackupManager.gd (Enhanced and GLI-19 Compliant)
##
## Centralized manager for scheduled and manual secure backups.
##
## Responsibilities:
## - Perform scheduled backups of critical folders and files.
## - Compress data into ZIP format and apply SHA-256 digital signatures.
## - Ensure persistence, redundancy, and traceability as per GLI-19.
##
## Must be registered as Autoload (singleton).
##


# --- Signals ---


## Emitted when a backup operation completes.
##
## @param success bool: Whether backup succeeded.
## @param details String: Path to archive or error message.
signal backup_completed(success: bool, details: String)


# --- Constants ---


## Paths (relative to user://) to include in backups.
const DEFAULT_BACKUP_PATHS: Array[String] = [
	"audit_logs/",
	"metadata/",
	"receipts/",
	"rng_state.dat"
]


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")

var _backup_interval_sec: int = 3600
var _backup_output_dir: String = "user://backups/"
var _compression_enabled: bool = true

var _timer: Timer = Timer.new()


# --- Lifecycle Methods ---


## Initializes the backup manager and schedules periodic backups.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")
	assert(_settings_manager != null, "❌ SettingsManager is required.")

	_load_backup_settings()
	_prepare_directories()
	_initialize_timer()

	_audit_log_manager.append_entry("🗂️ BackupManager initialized successfully.")


# --- Initialization Methods ---


## Loads backup-related settings from SettingsManager.
func _load_backup_settings() -> void:
	_backup_interval_sec = _settings_manager.get_setting("backup_interval_sec", 3600)
	_backup_output_dir = _settings_manager.get_setting("backup_output_dir", "user://backups/")
	_compression_enabled = _settings_manager.get_setting("backup_compression_enabled", true)

	assert(_backup_output_dir != "", "❌ Backup output directory must not be empty.")
	print_debug("🛠️ BackupManager settings loaded: Interval %d sec | Compression: %s" % [_backup_interval_sec, str(_compression_enabled)])


## Creates backup output directory if missing.
func _prepare_directories() -> void:
	DirAccess.make_dir_recursive_absolute(_backup_output_dir)


## Initializes and starts the periodic backup timer.
func _initialize_timer() -> void:
	_timer.one_shot = false
	_timer.wait_time = _backup_interval_sec
	_timer.timeout.connect(_on_backup_timer_timeout)
	add_child(_timer)
	_timer.start()

	print_debug("⏲️ Backup timer started (%d seconds)." % _backup_interval_sec)


# --- Public Methods ---


## Triggers backup immediately (manual mode).
func create_backup() -> void:
	var timestamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	var archive_name := "backup_%s.zip" % timestamp
	var archive_path := "%s%s" % [_backup_output_dir, archive_name]

	var zip := ZIPPacker.new()
	if zip.open(archive_path, ZIPPacker.APPEND_CREATE) != OK:
		push_error("❌ Failed to create ZIP archive: %s" % archive_path)
		backup_completed.emit(false, "Failed to create ZIP archive.")
		return

	for relative_path in DEFAULT_BACKUP_PATHS:
		var full_path := "user://%s" % relative_path
		if FileAccess.file_exists(full_path):
			zip.start_file(relative_path.get_file())
			zip.write_file(FileAccess.get_file_as_bytes(full_path))
		elif DirAccess.dir_exists_absolute(full_path):
			_backup_directory(zip, full_path, relative_path)
		else:
			push_warning("⚠️ Skipping non-existent backup path: %s" % full_path)

	zip.close()

	# Sign the archive
	if IntegrityChecker:
		IntegrityChecker.save_file_signature(archive_path)
	else:
		push_warning("⚠️ IntegrityChecker unavailable. Backup unsigned.")

	_audit_log_manager.append_entry("📦 Backup archive successfully created: %s" % archive_path)
	backup_completed.emit(true, archive_path)


# --- Private Methods ---


## Handles timer timeout event to trigger scheduled backup.
func _on_backup_timer_timeout() -> void:
	create_backup()


## Recursively includes a directory and its contents into the ZIP archive.
##
## @param zip ZIPPacker: Archive instance.
## @param source_dir String: Absolute source directory path.
## @param base_path String: Relative path inside archive.
func _backup_directory(zip: ZIPPacker, source_dir: String, base_path: String) -> void:
	var dir := DirAccess.open(source_dir)
	if dir == null:
		push_warning("⚠️ Failed to open directory for backup: %s" % source_dir)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var absolute_path := "%s/%s" % [source_dir, file_name]
		var relative_path := "%s/%s" % [base_path, file_name]

		if dir.current_is_dir():
			_backup_directory(zip, absolute_path, relative_path)
		else:
			var file_data := FileAccess.get_file_as_bytes(absolute_path)
			if file_data and file_data.size() > 0:
				zip.start_file(relative_path)
				zip.write_file(file_data)

		file_name = dir.get_next()

	dir.list_dir_end()
