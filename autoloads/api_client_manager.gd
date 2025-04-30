extends Node


# --- Description ---
##
## ApiClientManager.gd
##
## Centralized, secure, GLI-19 compliant HTTP client manager.
##
## Responsibilities:
## - Secure asynchronous HTTP communication
## - Retry and timeout management
## - Bearer Token / API Key header injection
## - Structured response parsing
## - Full audit logging
##
## Must be registered as Autoload (singleton).


# --- Private Variables ---


@onready var _audit_log_manager := Engine.get_singleton("AuditLogManager")

var _bearer_token: String = ""
var _api_key: String = ""


# --- Lifecycle Methods ---


## Initializes the API client.
func _ready() -> void:
	assert(_audit_log_manager != null, "❌ AuditLogManager is required.")
	_audit_log_manager.append_entry("🌐 ApiClientManager initialized successfully.")


# --- Public Methods ---


## Sets the Bearer Token for Authorization header.
##
## @param token String: Bearer token string.
func set_bearer_token(token: String) -> void:
	_bearer_token = token.strip_edges()


## Sets the API Key for x-api-key header.
##
## @param key String: API Key string.
func set_api_key(key: String) -> void:
	_api_key = key.strip_edges()


## Verifies internet connectivity by connecting to 8.8.8.8:53.
##
## @return int: OK if online, otherwise ERR_CANT_CONNECT.
func is_online() -> int:
	var client := HTTPClient.new()
	return OK if client.connect_to_host("8.8.8.8", 53) == OK else ERR_CANT_CONNECT


## Sends a generic asynchronous HTTP request.
##
## @param url String: Target URL.
## @param method int: HTTPClient.METHOD_* constant.
## @param headers Array: Array of request headers.
## @param body Variant: Request body, String or PackedByteArray.
## @param raw bool: Whether the body is raw binary.
## @param retries int: Number of retry attempts on failure.
## @param timeout_sec float: Timeout in seconds.
##
## @return Dictionary: Structured response dictionary.
func send_request(
	url: String,
	method: int,
	headers: Array,
	body: Variant,
	raw: bool = false,
	retries: int = 2,
	timeout_sec: float = 10.0
) -> Dictionary:
	return await _send_request_with_retries(url, method, headers, body, raw, retries, timeout_sec)


## Sends a GET request.
##
## @param url String: Target URL.
## @param extra_headers Array: Additional headers.
## @param retries int: Retry attempts.
## @param timeout_sec float: Timeout in seconds.
##
## @return Dictionary: Structured response dictionary.
func get_json(url: String, extra_headers: Array = [], retries: int = 2, timeout_sec: float = 10.0) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid GET URL: %s" % url)
	return await send_request(url, HTTPClient.METHOD_GET, _prepare_headers(extra_headers), "", false, retries, timeout_sec)


## Sends a POST request with JSON payload.
##
## @param url String: Target URL.
## @param payload Dictionary: Payload data.
## @param extra_headers Array: Additional headers.
## @param retries int: Retry attempts.
## @param timeout_sec float: Timeout in seconds.
##
## @return Dictionary: Structured response dictionary.
func post_json(url: String, payload: Dictionary, extra_headers: Array = [], retries: int = 2, timeout_sec: float = 10.0) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid POST URL: %s" % url)
	return await send_request(url, HTTPClient.METHOD_POST, _prepare_headers(extra_headers), JSON.stringify(payload), false, retries, timeout_sec)


## Sends a PUT request with JSON payload.
func put_json(url: String, payload: Dictionary, extra_headers: Array = [], retries: int = 2, timeout_sec: float = 10.0) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid PUT URL: %s" % url)
	return await send_request(url, HTTPClient.METHOD_PUT, _prepare_headers(extra_headers), JSON.stringify(payload), false, retries, timeout_sec)


## Sends a PATCH request with JSON payload.
func patch_json(url: String, payload: Dictionary, extra_headers: Array = [], retries: int = 2, timeout_sec: float = 10.0) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid PATCH URL: %s" % url)
	return await send_request(url, HTTPClient.METHOD_PATCH, _prepare_headers(extra_headers), JSON.stringify(payload), false, retries, timeout_sec)


## Sends a DELETE request.
func delete_request(url: String, extra_headers: Array = [], retries: int = 2, timeout_sec: float = 10.0) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid DELETE URL: %s" % url)
	return await send_request(url, HTTPClient.METHOD_DELETE, _prepare_headers(extra_headers), "", false, retries, timeout_sec)


## Sends a HEAD request.
func head_request(url: String, extra_headers: Array = [], retries: int = 2, timeout_sec: float = 10.0) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid HEAD URL: %s" % url)
	return await send_request(url, HTTPClient.METHOD_HEAD, _prepare_headers(extra_headers), "", false, retries, timeout_sec)


## Sends a POST request with binary (raw) payload.
##
## @param url String: Target URL.
## @param body PackedByteArray: Raw binary body.
## @param extra_headers Array: Additional headers.
##
## @return Dictionary: Structured response dictionary.
func post_bytes(url: String, body: PackedByteArray, extra_headers: Array = [], retries: int = 2, timeout_sec: float = 10.0) -> Dictionary:
	assert(url.begins_with("http"), "❌ Invalid POST Bytes URL: %s" % url)
	assert(body.size() > 0, "❌ POST body must not be empty.")
	return await send_request(url, HTTPClient.METHOD_POST, _prepare_headers(extra_headers), body, true, retries, timeout_sec)


# --- Private Methods ---


## Prepares request headers.
##
## @param extra_headers Array: Additional headers.
##
## @return Array: Complete headers.
func _prepare_headers(extra_headers: Array) -> Array:
	var headers := extra_headers.duplicate()
	if _bearer_token != "":
		headers.append("Authorization: Bearer %s" % _bearer_token)
	if _api_key != "":
		headers.append("x-api-key: %s" % _api_key)
	return headers


## Retries an HTTP request multiple times if necessary.
##
## @return Dictionary: Final structured response.
func _send_request_with_retries(
	url: String,
	method: int,
	headers: Array,
	body: Variant,
	raw: bool,
	retries: int,
	timeout_sec: float
) -> Dictionary:
	var result: Dictionary

	while retries >= 0:
		_audit_log_manager.append_entry("🌐 HTTP Attempt %d for: %s" % [retries, url])

		result = await _send_http_request(url, method, headers, body, raw, timeout_sec)

		if result.get("ok", false):
			_audit_log_manager.append_entry("✅ HTTP Success: %s" % url)
			return result

		if result.get("error_code", ERR_QUERY_FAILED) not in [ERR_TIMEOUT, ERR_CANT_CONNECT]:
			_audit_log_manager.append_entry("❌ Non-retryable HTTP failure: %s" % url)
			return result

		retries -= 1
		_audit_log_manager.append_entry("🔁 Retrying HTTP: %s" % url)

	_audit_log_manager.append_entry("⛔ Permanent HTTP failure: %s" % url)
	return result


## Sends a single HTTP request.
##
## @return Dictionary: Structured result.
func _send_http_request(
	url: String,
	method: int,
	headers: Array,
	body: Variant,
	raw: bool,
	timeout_sec: float
) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = timeout_sec
	get_tree().get_root().add_child(request)

	var err := request.request_raw(url, headers, method, body) if raw else request.request(url, headers, method, body)

	if err != OK:
		if is_instance_valid(request):
			request.queue_free()
		return {
			"ok": false,
			"error_code": err,
			"error_message": "❌ HTTP request initialization error.",
			"url": url
		}

	var result: Array = await request.request_completed

	if is_instance_valid(request):
		request.queue_free()

	var http_status: int = result[1]
	var response_body: String= result[3]

	if http_status < 200 or http_status >= 300:
		return {
			"ok": false,
			"http_status": http_status,
			"body": response_body,
			"url": url,
			"error_code": ERR_QUERY_FAILED
		}

	if raw:
		return {
			"ok": true,
			"http_status": http_status,
			"raw_content": response_body,
			"url": url
		}

	return _parse_json_response(response_body, url, http_status)


## Parses a JSON response safely.
##
## @return Dictionary: Structured JSON parsing result.
func _parse_json_response(response_body: Variant, url: String, http_status: int) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(response_body)

	if typeof(parsed) == TYPE_DICTIONARY:
		return {
			"ok": true,
			"http_status": http_status,
			"data": parsed,
			"url": url
		}

	_audit_log_manager.append_entry("⚠️ Invalid JSON parsing from: %s" % url)

	return {
		"ok": false,
		"http_status": http_status,
		"body": response_body,
		"url": url,
		"error_code": ERR_QUERY_FAILED
	}
