extends Node


# --- Description ---
##
## Unit tests for StringUtils.gd.
## Location: res://scripts/core/tests/test_string_utils.gd
##
## Covered Methods:
## - sanitize()
## - slugify()
## - truncate()
## - capitalize_words()
## - contains_only_letters()
##
## All tests must pass deterministically.


const StringUtils = preload("res://scripts/core/utils/string_utils.gd")


# --- Lifecycle ---


func before_each():
	pass

func after_each():
	pass


# --- Tests ---


## Tests sanitize() removes accents and symbols.
func test_sanitize() -> void:
	var input := "Çãó_á!# -"
	var expected := "caoa"
	var result := StringUtils.sanitize(input).replace(" ", "")
	AssertionsUtils.assert_eq(result, expected, "❌ sanitize failed: %s" % result)


## Tests slugify() converts to kebab-case.
func test_slugify() -> void:
	var input := "Título Especial!!"
	var expected := "titulo-especial"
	var result := StringUtils.slugify(input)
	AssertionsUtils.assert_eq(result, expected, "❌ slugify failed: %s" % result)


## Tests truncate() returns full or ellipsed string.
func test_truncate_no_cut() -> void:
	var input := "Short"
	var result := StringUtils.truncate(input, 10)
	AssertionsUtils.assert_eq(result, "Short", "❌ truncate should not cut.")

func test_truncate_cut() -> void:
	var input := "This is a very long sentence"
	var result := StringUtils.truncate(input, 10)
	AssertionsUtils.assert_eq(result, "This is...", "❌ truncate failed with ellipsis.")


## Tests capitalize_words() handles typical cases.
func test_capitalize_words() -> void:
	var input := "hello world from godot"
	var result := StringUtils.capitalize_words(input)
	AssertionsUtils.assert_eq(result, "Hello World From Godot", "❌ capitalize_words failed: %s" % result)


## Tests contains_only_letters with valid and invalid inputs.
func test_contains_only_letters_valid() -> void:
	AssertionsUtils.assert_true(StringUtils.contains_only_letters("OnlyLetters"), "❌ Expected letters only.")


func test_contains_only_letters_invalid() -> void:
	AssertionsUtils.assert_false(StringUtils.contains_only_letters("Letters123"), "❌ Digits not allowed.")
	AssertionsUtils.assert_false(StringUtils.contains_only_letters("With Space"), "❌ Spaces not allowed.")
	AssertionsUtils.assert_false(StringUtils.contains_only_letters("@Symbols!"), "❌ Symbols not allowed.")
