extends Node
class_name TestPauseUtils


# --- Description ---
##
## Unit tests for PauseUtils.gd
##
## Covers:
## - Input processing toggle
## - Logic/physics processing toggle
## - Animation processing toggle
## - Recursive pause/resume (deep mode)
## - Scene-wide full pause/resume
##
## Safe, isolated, GLI-19 compliant tests.
##


# --- Setup / Variables ---


var _root: Node
var _child: Node
var _grandchild: Node


## Creates a small scene tree for tests.
func before_each() -> void:
	_root = Node.new()
	add_child(_root)

	_child = Node.new()
	_root.add_child(_child)

	_grandchild = Node.new()
	_child.add_child(_grandchild)


## Cleans up after each test.
func after_each() -> void:
	_root.queue_free()


# --- Tests ---


## Tests if input processing is toggled correctly.
func test_set_input_process_state() -> void:
	PauseUtils.set_input_process_state(_root, true)

	AssertionsUtils.assert_false(_root.is_processing_input(), "❌ Root input should be paused.")
	AssertionsUtils.assert_false(_child.is_processing_input(), "❌ Child input should be paused.")
	AssertionsUtils.assert_false(_grandchild.is_processing_input(), "❌ Grandchild input should be paused.")

	PauseUtils.set_input_process_state(_root, false)

	AssertionsUtils.assert_true(_root.is_processing_input(), "❌ Root input should be resumed.")
	AssertionsUtils.assert_true(_child.is_processing_input(), "❌ Child input should be resumed.")
	AssertionsUtils.assert_true(_grandchild.is_processing_input(), "❌ Grandchild input should be resumed.")


## Tests if logic and physics processing are toggled correctly.
func test_set_logic_process_state() -> void:
	PauseUtils.set_logic_process_state(_root, true)

	AssertionsUtils.assert_false(_root.is_processing(), "❌ Root logic should be paused.")
	AssertionsUtils.assert_false(_child.is_processing(), "❌ Child logic should be paused.")
	AssertionsUtils.assert_false(_grandchild.is_processing(), "❌ Grandchild logic should be paused.")

	PauseUtils.set_logic_process_state(_root, false)

	AssertionsUtils.assert_true(_root.is_processing(), "❌ Root logic should be resumed.")
	AssertionsUtils.assert_true(_child.is_processing(), "❌ Child logic should be resumed.")
	AssertionsUtils.assert_true(_grandchild.is_processing(), "❌ Grandchild logic should be resumed.")


# --- Tests (Continuação) ---


## Tests if animation-related nodes are paused and resumed correctly.
func test_set_animation_process_state() -> void:
	var tween := _root.create_tween()

	var anim_player := AnimationPlayer.new()
	_root.add_child(anim_player)

	var anim_tree := AnimationTree.new()
	_root.add_child(anim_tree)

	PauseUtils.set_animation_process_state(tween, true)
	PauseUtils.set_animation_process_state(anim_player, true)
	PauseUtils.set_animation_process_state(anim_tree, true)

	AssertionsUtils.assert_true(tween.is_paused(), "❌ Tween should be paused.")
	AssertionsUtils.assert_false(anim_player.playback_active, "❌ AnimationPlayer should be paused.")
	AssertionsUtils.assert_false(anim_tree.active, "❌ AnimationTree should be paused.")

	PauseUtils.set_animation_process_state(tween, false)
	PauseUtils.set_animation_process_state(anim_player, false)
	PauseUtils.set_animation_process_state(anim_tree, false)

	AssertionsUtils.assert_false(tween.is_paused(), "❌ Tween should be resumed.")
	AssertionsUtils.assert_true(anim_player.playback_active, "❌ AnimationPlayer should be active.")
	AssertionsUtils.assert_true(anim_tree.active, "❌ AnimationTree should be active.")


## Tests if set_all_process_state correctly pauses everything recursively.
func test_set_all_process_state() -> void:
	PauseUtils.set_all_process_state(_root, true, true)

	AssertionsUtils.assert_false(_root.is_processing_input(), "❌ Root input should be paused (deep).")
	AssertionsUtils.assert_false(_child.is_processing_input(), "❌ Child input should be paused (deep).")
	AssertionsUtils.assert_false(_grandchild.is_processing_input(), "❌ Grandchild input should be paused (deep).")

	AssertionsUtils.assert_false(_root.is_processing(), "❌ Root logic should be paused (deep).")
	AssertionsUtils.assert_false(_child.is_processing(), "❌ Child logic should be paused (deep).")
	AssertionsUtils.assert_false(_grandchild.is_processing(), "❌ Grandchild logic should be paused (deep).")


## Tests if set_scene_process_state correctly applies to whole scene.
func test_set_scene_process_state() -> void:
	PauseUtils.set_scene_process_state(_root, true)

	AssertionsUtils.assert_false(_root.is_processing_input(), "❌ Root input should be paused by scene-wide pause.")
	AssertionsUtils.assert_false(_root.is_processing(), "❌ Root logic should be paused by scene-wide pause.")
	AssertionsUtils.assert_false(_child.is_processing(), "❌ Child logic should be paused by scene-wide pause.")
	AssertionsUtils.assert_false(_grandchild.is_processing_input(), "❌ Grandchild input should be paused by scene-wide pause.")

	PauseUtils.set_scene_process_state(_root, false)

	AssertionsUtils.assert_true(_root.is_processing_input(), "❌ Root input should be resumed after scene-wide resume.")
	AssertionsUtils.assert_true(_root.is_processing(), "❌ Root logic should be resumed after scene-wide resume.")
	AssertionsUtils.assert_true(_child.is_processing(), "❌ Child logic should be resumed after scene-wide resume.")
	AssertionsUtils.assert_true(_grandchild.is_processing_input(), "❌ Grandchild input should be resumed after scene-wide resume.")
