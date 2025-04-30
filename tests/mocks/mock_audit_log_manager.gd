extends Node
class_name MockAuditLogManager


func start_session(session_id: String, operator_name: String) -> void:
	pass


func append_entry(message: String) -> void:
	print("📝 [MockAuditLogManager] %s" % message)


func finalize_session() -> void:
	pass
