extends HTTPRequest
class_name MockHTTPRequestSuccess


func new_request(url: String, custom_headers := [], ssl_validate_domain := true, method := HTTPClient.METHOD_GET, request_data := "") -> int:
	return OK


func _ready() -> void:
	await get_tree().process_frame
	emit_signal("request_completed", 0, 200, [], '{"session_id": "SESSION_REMOTE_9999"}')
