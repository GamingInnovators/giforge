extends Node
class_name TestRandomNumberGeneratorGLI19


# --- Description ---
##
## TestRandomNumberGeneratorGLI19.gd
##
## Utility for statistical validation of RandomNumberGeneratorGLI19.
## Generates a large number of random floats and integers.
## Analyzes statistical properties and exports results securely.
##
## GLI-19 Compliant:
## - Results signed with SHA-256 signature.
## - Logging via AuditLogManager.
## - CSV export with FileUtils.
##
## Located at: res://scripts/core/tests/test_random_number_generator_gli19.gd
##
## Not Autoloaded. Must be instantiated manually.


# --- Public Variables ---

@export var number_of_tests: int = 100_000  ## Number of samples to generate.
@export var export_to_csv: bool = true      ## Enable CSV export.
@export var csv_output_path: String = "user://rng_test_results.csv"  ## Output path.


# --- Private Variables ---

@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")

var _rng: RandomNumberGeneratorGLI19 = RandomNumberGeneratorGLI19.new()
var _float_results: Array[float] = []
var _integer_results: Array[int] = []


# --- Lifecycle Methods ---


## Initializes and runs the RNG test automatically.
func _ready() -> void:
	assert(number_of_tests > 0, "❌ Number of tests must be greater than 0.")
	if export_to_csv:
		assert(csv_output_path.ends_with(".csv"), "❌ CSV output path must end with '.csv'.")

	_run_rng_test()
	_process_rng_results()

	if export_to_csv:
		_export_results_to_csv()


# --- Private Methods ---


## Runs the RNG test by generating floats and integers.
func _run_rng_test() -> void:
	print("🔵 Running RNG Stress Test with %d samples..." % number_of_tests)

	for _i in number_of_tests:
		_float_results.append(_rng.get_random_float())
		_integer_results.append(_rng.get_random_integer() % 100)


## Processes the generated results and prints statistics.
func _process_rng_results() -> void:
	print("🔵 Processing RNG Test Results...")

	var float_mean: float = _calculate_mean(_float_results)
	var float_stddev: float = _calculate_standard_deviation(_float_results, float_mean)

	print("🎲 Float Distribution:")
	print(" - Mean: %.6f" % float_mean)
	print(" - Standard Deviation: %.6f" % float_stddev)

	var histogram: Array[int] = _generate_histogram(_integer_results, 100)

	print("🎲 Integer Histogram (Modulo 100 Bins):")
	for i in range(100):
		print(" %02d: %d" % [i, histogram[i]])


## Exports the generated results to a CSV file for external audit.
func _export_results_to_csv() -> void:
	var rows: Array = []
	rows.append(["type", "value"])

	for value in _float_results:
		rows.append(["float", "%.6f" % value])

	for value in _integer_results:
		rows.append(["integer", "%d" % value])

	FileUtils.save_csv(csv_output_path, rows)
	IntegrityChecker.save_file_signature(csv_output_path)

	if _audit_log_manager:
		_audit_log_manager.append_entry("✅ RNG Test results exported and signed: %s" % csv_output_path)

	print("💾 RNG Test CSV Export and Signature Completed: %s" % csv_output_path)


## Calculates the mean (average) value of an array of floats.
##
## @param values: Array of float values.
## @return: Mean value as float.
static func _calculate_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0

	var sum: float = 0.0
	for value in values:
		sum += value

	return sum / values.size()


## Calculates the standard deviation of an array of floats.
##
## @param values: Array of float values.
## @param mean: Precomputed mean.
## @return: Standard deviation as float.
static func _calculate_standard_deviation(values: Array, mean: float) -> float:
	if values.is_empty():
		return 0.0

	var variance_sum: float = 0.0
	for value in values:
		variance_sum += pow(value - mean, 2)

	return sqrt(variance_sum / values.size())


## Generates a histogram for integer values between 0 and bins-1.
##
## @param values: Array of integer values.
## @param bins: Number of bins.
## @return: Array containing the count of values in each bin.
static func _generate_histogram(values: Array, bins: int) -> Array:
	var histogram: Array = []
	histogram.resize(bins)
	for i in range(bins):
		histogram[i] = 0

	for value in values:
		if value >= 0 and value < bins:
			histogram[value] += 1

	return histogram
