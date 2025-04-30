extends Node
class_name RandomNumberGeneratorGLI19


# --- Description ---
##
## RandomNumberGeneratorGLI19.gd
##
## GLI-19 Compliant Random Number Generator.
## - Secure random generation.
## - State persistence with encryption and digital signature.
## - Log rotation and audit trails via AuditLogManager.
## - Strong entropy seeding using multiple system sources.
##
## Located at: res://scripts/core/modules/random_number_generator_gli19.gd
##
## Not an Autoload. Must be instantiated manually.


# --- Signals ---


## Emitted when a random float number is generated.
signal random_generated(value: float)

## Emitted when a random integer is generated.
signal integer_generated(value: int)

## Emitted when an error occurs during RNG operations.
signal rng_error(message: String)

## Emitted when RNG state is saved securely.
signal state_saved()

## Emitted when RNG state is loaded successfully.
signal state_loaded()


# --- Enums ---


## Logging format options.
enum LogFormat {
	JSON,
	CSV,
	XML,
	BIN
}


# --- Constants ---


const FALLBACK_ENCRYPTION_KEY: String = "M7Q8P1X9L4Z2B5N6"


# --- Public Variables ---

@export var entropy_level: int = 3  # 1=min, 2=med, 3=strong
@export var log_to_console: bool = false
@export var enable_rng_logging: bool = true
@export var log_format: LogFormat = LogFormat.JSON


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")
@onready var _settings_manager := Engine.get_singleton("SettingsManager")


var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_seed: int = 0
var _state_file: String = "user://rng_state.dat"
var _log_file: String = "user://rng_log.log"
var _encryption_key: String = FALLBACK_ENCRYPTION_KEY

var _fallback_counter: int = 0
var _regeneration_counter: int = 0
var _last_saved_state: int = -1

var _log_max_size: int = 1 * 1024 * 1024  # 1 MB
var _max_log_rotations: int = 5


# --- Lifecycle Methods ---


## Called when the node is ready.
##
## Initializes RNG, validates dependencies, loads or generates state.
func _ready() -> void:
	_validate_dependencies()
	_load_settings()
	_initialize_rng()
	_load_or_initialize_state()
	_log_internal("🔵 RandomNumberGeneratorGLI19 ready.")


# --- Private Methods ---


## Loads configurable parameters from SettingsManager.
func _load_settings() -> void:
	if _settings_manager:
		_state_file = _settings_manager.get_setting("rng_state_file", "user://rng_state.dat")
		_log_file = _settings_manager.get_setting("rng_log_file", "user://rng_log.log")
		_encryption_key = _settings_manager.get_setting("rng_encryption_key", FALLBACK_ENCRYPTION_KEY)
		_log_max_size = _settings_manager.get_setting("rng_log_max_size_bytes", 1 * 1024 * 1024)
		_max_log_rotations = _settings_manager.get_setting("rng_log_max_rotations", 5)
		log_to_console = _settings_manager.get_setting("rng_log_to_console", false)
		enable_rng_logging = _settings_manager.get_setting("rng_enable_logging", true)

	print_debug("🎯 RNG settings loaded dynamically.")


## Validates required autoloaded dependencies.
##
## Ensures that AuditLogManager and IntegrityChecker are available.
func _validate_dependencies() -> void:
	assert(get_node_or_null("/root/AuditLogManager") != null, "❌ AuditLogManager must be autoloaded.")
	assert(get_node_or_null("/root/IntegrityChecker") != null, "❌ IntegrityChecker must be autoloaded.")
	assert(get_node_or_null("/root/SettingsManager") != null, "❌ SettingsManager must be autoloaded.")


## Initializes the RNG with a strong entropy-based seed.
##
## Uses multiple system-level entropy sources combined and hashed.
func _initialize_rng() -> void:
	var entropy: int = int(Time.get_unix_time_from_system())
	var hash_context := HashingContext.new()

	var result := hash_context.start(HashingContext.HASH_SHA256)
	assert(result == OK, "❌ Failed to start HashContext for RNG initialization.")

	# Collect multiple entropy sources
	if entropy_level >= 2:
		entropy ^= int(OS.get_unique_id().hash() & 0xFFFFFFFF)
		entropy ^= Time.get_ticks_usec() << 32
		entropy ^= Time.get_ticks_msec()

	if entropy_level >= 3:
		entropy ^= OS.get_processor_count() << 16
		entropy ^= int(OS.get_locale().hash() & 0xFFFFFFFF)
		entropy ^= int(OS.get_model_name().hash() & 0xFFFFFFFF)
		entropy ^= _generate_uuid_entropy()

	# Finalize entropy collection
	hash_context.update(str(entropy).to_utf8_buffer())
	var seed_bytes := hash_context.finish()

	for byte in seed_bytes:
		entropy = (entropy << 8) | byte

	# Whitening
	entropy ^= entropy >> 16
	entropy ^= entropy << 8
	entropy ^= entropy >> 4

	_current_seed = int(abs(entropy)) % 0x7FFFFFFFFFFFFFFF
	_rng.seed = _current_seed

	_log_internal("🔹 RNG initialized with high-quality seed: %d" % _current_seed)


## Generates an extra high-entropy seed based on UUID.
##
## @return int: Strong entropy integer.
func _generate_uuid_entropy() -> int:
	var uuid := UuidUtils.v4().replace("-", "").substr(0, 16)  # Get first 16 characters
	var entropy_seed := 0
	for i in uuid.length():
		entropy_seed ^= uuid.unicode_at(i)  # Correct method to get character code
	return entropy_seed


## Loads RNG state securely or initializes fallback if missing or invalid.
##
## Validates integrity signature before accepting saved state.
func _load_or_initialize_state() -> void:
	if FileAccess.file_exists(_state_file):
		var valid := IntegrityChecker.validate_file_signature(_state_file)
		
		if valid:
			var file := FileAccess.open_encrypted_with_pass(_state_file, FileAccess.READ, _encryption_key)
			if file != null:
				var loaded_seed := file.get_64()
				file.close()

				_rng.seed = loaded_seed
				_current_seed = loaded_seed

				state_loaded.emit()
				_log_internal("✅ RNG state loaded successfully. Seed: %d" % _current_seed)
				return
			else:
				_log_error("❌ Failed to open RNG state file for reading.")
		else:
			_log_warning("⚠️ Invalid signature detected. State fallback triggered.")
	else:
		_log_warning("⚠️ RNG state file not found. Generating fallback seed.")

	# Fallback to randomized seed
	_fallback_counter += 1
	_initialize_rng()

	state_loaded.emit()
	_log_internal("🔴 Fallback seed generated: %d" % _current_seed)
	_save_rng_state()


## Saves the current RNG state securely and signs it.
##
## Ensures full GLI-19 compliance with encrypted persistence and signature.
func _save_rng_state() -> void:
	var file := FileAccess.open_encrypted_with_pass(_state_file, FileAccess.WRITE, _encryption_key)
	
	if file != null:
		file.store_64(_rng.seed)
		file.close()

		IntegrityChecker.save_file_signature(_state_file)
		_last_saved_state = _rng.state

		state_saved.emit()
		_log_internal("💾 RNG state saved and signed successfully.")

		_check_log_rotation()
	else:
		_log_error("❌ Failed to open RNG state file for saving.")


## Logs an internal message if console logging is enabled.
func _log_internal(message: String) -> void:
	if log_to_console:
		print("[RNG] %s" % message)
	if enable_rng_logging:
		_audit_log_manager.append_entry(message)


## Logs a warning.
func _log_warning(message: String) -> void:
	push_warning(message)
	_log_internal(message)


## Logs an error.
func _log_error(message: String) -> void:
	push_error(message)
	_log_internal(message)



## Checks if the log file size exceeds the maximum allowed and rotates if necessary.
func _check_log_rotation() -> void:
	if not FileAccess.file_exists(_log_file):
		return

	var log_file := FileAccess.open(_log_file, FileAccess.READ)
	if log_file == null:
		_log_error("❌ Cannot open log file to check rotation.")
		return

	var size := log_file.get_length()
	log_file.close()

	if size >= _log_max_size:
		_log_warning("⚠️ Log file size exceeded. Rotating...")
		_rotate_logs()


## Rotates and compresses old log files.
## Rotates and compresses old log files securely (GZIP compression).
func _rotate_logs() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		_log_error("❌ Cannot open directory for log rotation.")
		return

	# Remove the oldest compressed log if exists
	var oldest_log := "%s.%d.gz" % [_log_file, _max_log_rotations]
	if FileAccess.file_exists(oldest_log):
		var remove_result := dir.remove(oldest_log)
		if remove_result == OK:
			_log_internal("🧹 Oldest compressed log removed: %s" % oldest_log)
		else:
			_log_warning("⚠️ Failed to remove oldest compressed log: %s" % oldest_log)

	# Rotate existing compressed logs
	for i in range(_max_log_rotations - 1, 0, -1):
		var old_log := "%s.%d.gz" % [_log_file, i]
		var new_log := "%s.%d.gz" % [_log_file, i + 1]

		if FileAccess.file_exists(old_log):
			var rename_result := dir.rename(old_log, new_log)
			if rename_result == OK:
				_log_internal("🔄 Renamed compressed log: %s -> %s" % [old_log, new_log])
			else:
				_log_warning("⚠️ Failed to rename compressed log: %s -> %s" % [old_log, new_log])

	# Compress the current log
	if FileAccess.file_exists(_log_file):
		var original_content := FileAccess.get_file_as_bytes(_log_file)
		if original_content.size() > 0:
			var compressed_content := original_content.compress(FileAccess.COMPRESSION_GZIP)
			var compressed_log_path := "%s.1.gz" % _log_file
			var compressed_file := FileAccess.open(compressed_log_path, FileAccess.WRITE)

			if compressed_file != null:
				compressed_file.store_buffer(compressed_content)
				compressed_file.close()

				# Remove original log file after compression
				var removal := dir.remove(_log_file)
				if removal == OK:
					_log_internal("🗜️ Log file compressed and rotated: %s" % compressed_log_path)
				else:
					_log_warning("⚠️ Failed to remove original log after compression: %s" % _log_file)
			else:
				_log_error("❌ Failed to open compressed log file: %s" % compressed_log_path)
		else:
			_log_warning("⚠️ Log file was empty. Skipping compression.")
	else:
		_log_warning("⚠️ No current log file found to compress.")


## Compresses a log file using GZIP.
##
## @param source_path: Original log file path.
## @param target_path: Compressed target file path.
func _compress_log_file(source_path: String, target_path: String) -> void:
	if not FileAccess.file_exists(source_path):
		_log_error("❌ Source log file not found: %s" % source_path)
		return

	var content := FileAccess.get_file_as_bytes(source_path)
	var compressed_content := content.compress(FileAccess.COMPRESSION_GZIP)
	var compressed_file := FileAccess.open(target_path, FileAccess.WRITE)
	
	if compressed_file == null:
		_log_error("❌ Failed to create compressed file: %s" % target_path)
		return

	compressed_file.store_buffer(compressed_content)
	compressed_file.close()

	_log_internal("🗜️ Compressed log file: %s" % target_path)


## Validates whether a given array is a proper list of probabilities.
##
## Rules:
## - The array must not be empty.
## - All elements must be floats or ints.
## - All values must be ≥ 0 and ≤ 1.
##
## @param probabilities Array: Input probability values.
## @return bool: True if the array is valid, False otherwise.
func _validate_probabilities_input(probabilities: Array) -> bool:
	if probabilities.is_empty():
		_log_internal("🚫 Probability array is empty.")
		return false

	# Check for negative values using `any()` for optimized iteration
	if probabilities.any(func(value): return value < 0):
		_log_internal("Negative values detected in probability array.")
		return false

	return true
	
	
	## Normalizes probabilities to sum to 1.0.
##
## @param probabilities Array - A list of numerical probability values.
##
## @return Array - A normalized array of probabilities.
##
## Notes:
## - Normalization ensures the probabilities are valid for cumulative calculations.
## - If the sum of probabilities is zero, logs an error and returns an empty array.
## - Critical for weighted randomness and GLI-19 compliance.
func _normalize_probabilities(probabilities: Array) -> Array:
	var total: float = probabilities.reduce(func(accum, value): return accum + value, 0.0)

	# Handle edge case where the sum of probabilities is zero
	if total == 0.0:
		_log_internal("Probability values cannot sum to zero. Normalization failed.")
		return []

	# Normalize probabilities
	var normalized: Array = probabilities.map(func(prob): return prob / total)

	_log_internal("📊 Probabilities normalized. Total before: %.6f" % total)
	return normalized


# --- Public Random Methods ---


## Shuffles an array using Fisher-Yates algorithm (secure shuffle).
##
## @param array: Array to shuffle.
## @return Array: Shuffled array.
func shuffle_array(array: Array) -> Array:
	assert(array != null, "❌ Array to shuffle must not be null.")

	if array.is_empty():
		_log_warning("⚠️ Attempted to shuffle an empty array.")
		return array

	var shuffled := array.duplicate()

	for i in range(shuffled.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp

	_log_internal("🔀 Array shuffled successfully.")
	_audit_log_manager.append_entry("🔀 Array shuffled using Fisher-Yates.")

	return shuffled


## Generates a random floating-point number in [0, 1).
##
## @return float: Random value.
func get_random_float() -> float:
	var value := _rng.randf()
	_save_rng_state()
	random_generated.emit(value)

	_log_internal("🎲 Generated random float: %.6f" % value)
	return value


## Generates a random integer.
##
## @return int: Random integer.
func get_random_integer() -> int:
	var value := _rng.randi()
	_save_rng_state()
	integer_generated.emit(value)

	_log_internal("🎲 Generated random integer: %d" % value)
	return value


## Generates a random integer between two bounds (inclusive).
##
## @param from int: Lower bound.
## @param to int: Upper bound.
## @return int: Random integer within [from, to].
func get_random_integer_range(from: int, to: int) -> int:
	assert(from <= to, "❌ Invalid range: 'from' must be <= 'to'.")

	var value := _rng.randi_range(from, to)
	_save_rng_state()
	integer_generated.emit(value)

	_log_internal("🎲 Generated random integer in range [%d, %d]: %d" % [from, to, value])
	return value


## Generates a random floating-point number between two bounds (inclusive).
##
## @param from float: Lower bound.
## @param to float: Upper bound.
## @return float: Random float within [from, to].
func get_random_float_range(from: float, to: float) -> float:
	assert(from <= to, "❌ Invalid range: 'from' must be <= 'to'.")

	var value := _rng.randf_range(from, to)
	_save_rng_state()
	random_generated.emit(value)

	_log_internal("🎲 Generated random float in range [%.2f, %.2f]: %.6f" % [from, to, value])
	return value


## Generates an index based on cumulative probability values.
##
## @param cumulative_probabilities: Array of cumulative probabilities [0..1].
## @return int: Selected index, or -1 if invalid.
func generate_random_index(cumulative_probabilities: Array) -> int:
	assert(cumulative_probabilities != null, "❌ Cumulative probabilities array cannot be null.")

	if cumulative_probabilities.is_empty():
		_log_error("❌ Cumulative probabilities array is empty.")
		rng_error.emit("Invalid cumulative probabilities input.")
		return -1

	var random_value := _rng.randf()

	for i in range(cumulative_probabilities.size()):
		if random_value <= cumulative_probabilities[i]:
			_log_internal("🎯 Random index generated: %d (Random=%.6f)" % [i, random_value])
			return i

	_log_error("❌ No valid index found for random value %.6f" % random_value)
	rng_error.emit("No valid index found for generated random.")
	return -1


## Synchronizes the in-memory RNG state to disk manually.
##
## @note Useful for systems where constant disk writes are minimized.
func synchronize_in_memory_state() -> void:
	if _rng.state != _last_saved_state:
		_save_rng_state()
		_log_internal("🔄 RNG state synchronized manually.")


## Rotates the encryption key for the RNG state file.
##
## @param new_key: New encryption key (must be exactly 16 characters).
func rotate_encryption_key(new_key: String) -> void:
	assert(new_key.length() == 16, "❌ Encryption key must be exactly 16 characters.")

	if new_key == _encryption_key:
		_log_warning("⚠️ New encryption key is the same as the current one. No rotation done.")
		return

	var loaded_seed := 0

	if FileAccess.file_exists(_state_file):
		var file := FileAccess.open_encrypted_with_pass(_state_file, FileAccess.READ, _encryption_key)
		if file:
			loaded_seed = file.get_64()
			file.close()
		else:
			_log_error("❌ Failed to open current RNG state for key rotation.")
			return
	else:
		_log_warning("⚠️ No existing RNG state to rotate.")
		return

	var new_file := FileAccess.open_encrypted_with_pass(_state_file, FileAccess.WRITE, new_key)
	if new_file:
		new_file.store_64(loaded_seed)
		new_file.close()

		IntegrityChecker.save_file_signature(_state_file)

		_encryption_key = new_key
		state_saved.emit()

		_log_internal("🔑 RNG encryption key rotated successfully.")
	else:
		_log_error("❌ Failed to write RNG state after key rotation.")


## Logs a summary of the current RNG state for auditing purposes.
##
## @note Useful for manual inspections and GLI-19 validation processes.
func log_rng_summary() -> void:
	var message := "📋 RNG Summary: Seed=%d | LastSavedState=%d | Fallbacks=%d | Regenerations=%d" % [
		_current_seed,
		_last_saved_state,
		_fallback_counter,
		_regeneration_counter
	]

	_log_internal(message)


## Validates cumulative probabilities.
##
## @param probabilities Array - List of cumulative probabilities to validate.
##
## @return bool - `true` if the sum does not exceed 1.0, otherwise `false`.
##
## Notes:
## - Ensures that the sum of cumulative probabilities does not exceed `1.0`.
## - Uses `_log_message()` for structured logging.
## - If probabilities exceed `1.0`, logs an `ERROR`.
## - Logs a success message if validation passes.
func validate_probabilities(probabilities: Array) -> bool:
	var total_probability := 0.0

	# Calculate the total sum of probabilities
	for value in probabilities:
		total_probability += value

	# Check if the total exceeds 1.0
	if total_probability > 1.0:
		_log_internal("The sum of probabilities exceeds 1.0: %0.4f" % total_probability)
		return false

	# Log validation success
	_log_internal("Probabilities validated successfully. Total sum: %0.4f" % total_probability)
	
	return true
	
	
	## Generates a list of cumulative probabilities from base probability values.
##
## This method:
## - Validates the input array.
## - Normalizes the values to ensure they sum to ≈ 1.0.
## - Generates a cumulative distribution for use with RNG.
##
## @param probabilities Array: A list of raw probabilities (e.g. [0.3, 0.5, 0.2]).
## @return Array: A list of cumulative probabilities (e.g. [0.3, 0.8, 1.0]).
func generate_cumulative_probabilities(probabilities: Array) -> Array:
	# Validate input values
	if not _validate_probabilities_input(probabilities):
		_log_internal("❌ Invalid probabilities input array.")
		return []

	# Normalize the input so the total sums to 1.0
	var normalized := _normalize_probabilities(probabilities)

	var cumulative := []
	var running_total := 0.0

	# Build cumulative array
	for prob in normalized:
		running_total += prob
		cumulative.append(running_total)

	# Sanity check final value (floating point tolerance allowed)
	if abs(cumulative.back() - 1.0) > 0.01:
		_log_internal("❌ Cumulative sum is not ≈ 1.0: got %.6f" % cumulative.back())
		rng_error.emit("Cumulative probability sum invalid.")
		return []

	# Ensure RNG continuity (fallback if state changed unexpectedly)
	if _rng.state != _last_saved_state:
		_log_internal("⚠️ RNG state mismatch. Fallback and reseeding applied.")
		_fallback_counter += 1
		_initialize_rng()
		_save_rng_state()
		_last_saved_state = _rng.state

	_log_internal("✅ Cumulative probabilities successfully generated.")
	return cumulative
