extends RefCounted
class_name ArrayUtils


# --- Description ---
##
## ArrayUtils.gd
##
## High-performance utility for safe and deterministic array operations.
## Designed for casino systems to support:
## - History and favorites management
## - Bet normalization and export
## - Statistical validation
##
## Located at: res://scripts/core/utils/array_utils.gd
##
## GLI-19 Compliant:
## - No side effects
## - Fully deterministic
## - Auditable behaviors
##
## Must be loaded manually (NOT Autoload).


# --- Public Static Methods ---


## Removes duplicate values from an array, preserving the original order.
##
## @param array: Source array.
## @return: Array with unique elements only.
static func unique(array: Array) -> Array:
	assert(array is Array, "❌ Provided argument must be an Array.")

	var result: Array = []
	for item in array:
		if not result.has(item):
			result.append(item)

	return result


## Flattens a nested one-level array into a single array.
##
## @param nested_array: Array that may contain other arrays.
## @return: Flattened single-level array.
static func flatten(nested_array: Array) -> Array:
	assert(nested_array is Array, "❌ Provided argument must be an Array.")

	var result: Array = []
	for element in nested_array:
		if element is Array:
			result.append_array(element)
		else:
			result.append(element)

	return result


## Divides an array into sub-arrays (chunks) of a given size.
##
## @param array: Source array.
## @param chunk_size: Size of each chunk (must be > 0).
## @return: Array of chunked arrays.
static func chunk(array: Array, chunk_size: int) -> Array:
	assert(array is Array, "❌ Provided argument must be an Array.")
	assert(chunk_size > 0, "❌ Chunk size must be greater than zero.")

	var result: Array = []
	var i: int = 0

	while i < array.size():
		result.append(array.slice(i, i + chunk_size))
		i += chunk_size

	return result


## Computes the difference between two arrays.
##
## @param array_a: Base array.
## @param array_b: Elements to exclude.
## @return: Array containing elements present in A but not in B.
static func difference(array_a: Array, array_b: Array) -> Array:
	assert(array_a is Array and array_b is Array, "❌ Both arguments must be Arrays.")

	var result: Array = []
	for item in array_a:
		if not array_b.has(item):
			result.append(item)

	return result


## Shuffles an array using the Fisher-Yates algorithm.
##
## @param array: Input array (modified in place).
static func shuffle(array: Array, rng: RandomNumberGenerator = null) -> void:
	assert(array is Array, "❌ Provided argument must be an Array.")
	rng = rng if rng != null else RandomNumberGenerator.new()
	rng.randomize()

	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp


## Picks a random element from an array.
##
## @param array: Source array.
## @return: Random element or null if array is empty.
static func random_element(array: Array, rng: RandomNumberGenerator = null) -> Variant:
	assert(array is Array, "❌ Provided argument must be an Array.")
	if array.is_empty():
		return null

	rng = rng if rng != null else RandomNumberGenerator.new()
	rng.randomize()
	return array[rng.randi_range(0, array.size() - 1)]


## Safely retrieves an element at the specified index.
##
## @param array: Source array.
## @param index: Index to access.
## @param fallback: Value returned if index is invalid (default = null).
## @return: Element at index or fallback if out of bounds.
static func safe_get(array: Array, index: int, fallback: Variant = null) -> Variant:
	assert(array is Array, "❌ Provided argument must be an Array.")

	if index < 0 or index >= array.size():
		return fallback

	return array[index]


## Joins elements into a single delimiter-separated string.
##
## @param array: Array of elements to join.
## @param delimiter: Delimiter to use (default is comma).
## @return: Concatenated string.
static func join_as_string(array: Array, delimiter: String = ",") -> String:
	assert(array is Array, "❌ Provided argument must be an Array.")
	assert(delimiter is String, "❌ Delimiter must be a String.")

	var str_array: Array[String] = array.map(func(element): return str(element))
	return delimiter.join(str_array)
