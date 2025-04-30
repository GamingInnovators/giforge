extends Node
class_name MockMetadataLogManager


func start_session(session_id: String, operator_name: String, system_version: String) -> void:
	pass


func append_entry(entry: Dictionary) -> void:
	print("📑 [MockMetadataLogManager] Entry: %s" % entry)


func finalize_session() -> void:
	pass
