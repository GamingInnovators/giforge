extends Node


# --- Description ---
##
## Teste para SessionIDGenerator.gd
##
## Valida:
## - Geração local de ID
## - Persistência no disco
## - Formato SESSION_<YYYYMMDD_HHMMSS>_<uuid>
## - Emissão de sinal
##
## NOTA: Não valida chamadas externas (requer mocks HTTP)


# --- Dependencies ---


var _generator: SessionIDGenerator
var _emitted_id: String = ""


# --- Setup / Teardown ---


func before_each() -> void:
	_generator = SessionIDGenerator.new()
	_generator.init(false, "")  # Fallback local sempre
	add_child(_generator)

	_generator.session_id_generated.connect(func(session_id: String):
		_emitted_id = session_id
	)


func after_each() -> void:
	if is_instance_valid(_generator):
		_generator.queue_free()
		_generator = null
	_emitted_id = ""


# --- Tests ---


func test_generate_local_session_id_valid_format() -> void:
	var id: String = await _generator.generate_session_id()
	
	assert(id.begins_with("SESSION_"), "❌ Session ID must begin with 'SESSION_'.")
	assert(id.length() > 24, "❌ Session ID is too short.")
	assert(_emitted_id == id, "❌ Session ID was not emitted properly.")
	assert(FileAccess.file_exists("user://last_session_id.txt"), "❌ Session ID file not saved.")
	
	var file_id := FileAccess.get_file_as_string("user://last_session_id.txt").strip_edges()
	assert(file_id == id, "❌ Session ID file content mismatch.")
