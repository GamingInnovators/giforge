extends Node
class_name MockSessionIDGenerator


## Mocks async generation of a predictable session ID.
func generate_session_id() -> String:
	await get_tree().create_timer(0.1).timeout
	return "mock-session-id-123456"
