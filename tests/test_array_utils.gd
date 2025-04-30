extends Node
class_name TestArrayUtils


# --- Description ---
##
## Unit tests for ArrayUtils.gd
##
## Verifies:
## - Uniqueness removal
## - Array flattening
## - Chunking into sub-arrays
## - Difference calculation
## - Shuffling randomness
## - Random element picking
## - Safe element retrieval
## - String joining
##
## Fully isolated tests without external dependencies.


# --- Lifecycle Methods ---


## Setup before each test if needed.
func before_each() -> void:
	pass


## Cleanup after each test if needed.
func after_each() -> void:
	pass


# --- Tests ---


## Tests the unique() method.
func test_unique() -> void:
	var input := [1, 2, 2, 3, 4, 4, 5]
	var result := ArrayUtils.unique(input)

	AssertionsUtils.assert_eq(result, [1, 2, 3, 4, 5], "❌ Unique did not remove duplicates correctly.")


## Tests the flatten() method.
func test_flatten() -> void:
	var input := [[1, 2], 3, [4, 5], 6]
	var result := ArrayUtils.flatten(input)

	AssertionsUtils.assert_eq(result, [1, 2, 3, 4, 5, 6], "❌ Flatten did not combine nested arrays correctly.")


## Tests the chunk() method.
func test_chunk() -> void:
	var input := [1, 2, 3, 4, 5]
	var result := ArrayUtils.chunk(input, 2)

	AssertionsUtils.assert_eq(result, [[1, 2], [3, 4], [5]], "❌ Chunking did not split array correctly.")


## Tests the difference() method.
func test_difference() -> void:
	var a := [1, 2, 3, 4]
	var b := [2, 4]
	var result := ArrayUtils.difference(a, b)

	AssertionsUtils.assert_eq(result, [1, 3], "❌ Difference computation is incorrect.")


## Tests the shuffle() method.
func test_shuffle() -> void:
	var input := [1, 2, 3, 4, 5]
	var copy := input.duplicate()

	ArrayUtils.shuffle(input)

	# Shuffling should not change array size
	AssertionsUtils.assert_eq(input.size(), copy.size(), "❌ Shuffle altered array size.")

	# Shuffling may occasionally return same order, so we avoid asserting content change strictly.


## Tests the random_element() method.
func test_random_element() -> void:
	var input := ["a", "b", "c", "d"]
	var element: Array = ArrayUtils.random_element(input)

	AssertionsUtils.assert_true(input.has(element), "❌ Random element is not from input array.")


## Tests the safe_get() method with valid and invalid indexes.
func test_safe_get() -> void:
	var input := ["apple", "banana", "cherry"]

	AssertionsUtils.assert_eq(ArrayUtils.safe_get(input, 1), "banana", "❌ Safe get failed on valid index.")
	AssertionsUtils.assert_eq(ArrayUtils.safe_get(input, 5, "none"), "none", "❌ Safe get failed on fallback index.")


## Tests the join_as_string() method.
func test_join_as_string() -> void:
	var input := [1, 2, 3]
	var joined := ArrayUtils.join_as_string(input, "-")

	AssertionsUtils.assert_eq(joined, "1-2-3", "❌ Join as string failed.")
