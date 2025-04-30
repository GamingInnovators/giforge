extends Node
class_name TestApiClientManager


# --- Description ---
##
## TestApiClientManager.gd
##
## Automated tests for ApiClientManager HTTP operations.
##
## Located at: res://tests/test_api_client_manager.gd
##
## Requires ApiClientManager autoloaded.

# --- Private Variables ---


@onready var _api_client_manager := Engine.get_singleton("ApiClientManager")


# --- Lifecycle Methods ---


## Prepares environment before tests.
func _ready() -> void:
	assert(_api_client_manager != null, "❌ ApiClientManager is required for testing.")
	_run_tests()


# --- Test Cases ---


## Executes all unit tests.
func _run_tests() -> void:
	print("🧪 Running ApiClientManager tests...")
	_test_connectivity()
	await _test_successful_get()
	await _test_failed_get()
	await _test_post_bytes()
	print("✅ ApiClientManager tests finished.")


## Tests basic internet connectivity check.
func _test_connectivity() -> void:
	var result: int = _api_client_manager.is_online()
	assert(result == OK or result == ERR_CANT_CONNECT, "❌ Unexpected connectivity result.")
	print("- Connectivity check passed.")


## Tests GET request to known public API (mocked).
func _test_successful_get() -> void:
	var url := "https://jsonplaceholder.typicode.com/posts/1"  # Free public test API
	var response: Dictionary = await _api_client_manager.get_json(url)

	assert(response.has("ok"), "❌ Response missing 'ok' field.")
	assert(response.ok == true, "❌ GET request failed unexpectedly.")
	assert(response.data.has("id") and response.data.id == 1, "❌ Unexpected JSON structure.")
	print("- Successful GET request passed.")


## Tests failed GET request (invalid domain).
func _test_failed_get() -> void:
	var url := "https://nonexistent.subdomain.invalidtest"
	var response: Dictionary = await _api_client_manager.get_json(url)

	assert(response.has("ok"), "❌ Response missing 'ok' field.")
	assert(response.ok == false, "❌ GET to invalid URL should fail.")
	print("- Failed GET request handled correctly.")


## Tests POST Bytes with invalid URL (expected to fail).
func _test_post_bytes() -> void:
	var url := "https://nonexistent.subdomain.invalidtest"
	var payload := PackedByteArray([1, 2, 3, 4, 5])

	var response: Dictionary = await _api_client_manager.post_bytes(url, payload)

	assert(response.has("ok"), "❌ Response missing 'ok' field.")
	assert(response.ok == false, "❌ POST Bytes should fail on invalid URL.")
	print("- POST Bytes failure handled correctly.")
