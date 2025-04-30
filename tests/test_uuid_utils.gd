extends Node


# --- Description ---
##
## test_uuid_utils.gd
##
## Testes para UuidUtils.gd
## Valida os formatos e comportamentos dos UUIDs v3, v4 e v5.
##
## Local: res://scripts/core/tests/test_uuid_utils.gd
##
## GLI-19 Compliant:
## - Validação segura de UUIDs
## - Hashing determinístico
##


func test_uuid_v4_format() -> void:
	var uuid := UuidUtils.v4()
	assert(uuid is String and uuid.length() == 36, "❌ UUID v4 deve ter 36 caracteres.")
	assert(uuid[14] == "4", "❌ UUID v4 deve ter versão 4 no índice 14.")


func test_uuid_v3_determinism() -> void:
	var ns := UuidUtils.NAMESPACE_DNS
	var uuid1 := UuidUtils.v3(ns, "example")
	var uuid2 := UuidUtils.v3(ns, "example")
	assert(uuid1 == uuid2, "❌ UUID v3 deve ser determinístico.")
	assert(uuid1[14] == "3", "❌ UUID v3 deve ter versão 3 no índice 14.")


func test_uuid_v5_determinism() -> void:
	var ns := UuidUtils.NAMESPACE_DNS
	var uuid1 := UuidUtils.v5(ns, "example")
	var uuid2 := UuidUtils.v5(ns, "example")
	assert(uuid1 == uuid2, "❌ UUID v5 deve ser determinístico.")
	assert(uuid1[14] == "5", "❌ UUID v5 deve ter versão 5 no índice 14.")


func test_uuid_variant_bits() -> void:
	var uuid := UuidUtils.v4()
	var variant_char := uuid[19]
	var variant := variant_char.hex_to_int()
	assert(variant >= 8 and variant <= 11, "❌ Bits de variante inválidos em: %s" % variant_char)


func test_uuid_v4_uniqueness() -> void:
	var uuid1 := UuidUtils.v4()
	var uuid2 := UuidUtils.v4()
	assert(uuid1 != uuid2, "❌ UUID v4 deve ser único por chamada.")
