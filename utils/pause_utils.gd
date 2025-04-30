extends RefCounted
class_name PauseUtils


# --- Description ---
##
## PauseUtils.gd
##
## Provides deterministic utilities to control game scene pausing and resuming.
##
## Responsibilities:
## - Toggle input, logic, physics, and animation processing.
## - Deep recursive traversal of scene trees (optional).
## - No hidden state. Fully stateless static methods.
##
## Location: res://scripts/core/utils/pause_utils.gd
##
## GLI-19/GLI-11 Compliant:
## - Deterministic
## - No side effects
## - Security-validated node handling
##
## Not Autoloaded. Used manually by systems needing scene-wide process control.
##
## Example usage:
## - PauseUtils.set_scene_process_state(get_tree().root, true)
##


# --- Public Static Methods ---


## Sets input processing state for a node (and optionally its children).
##
## @param node Node: Target node.
## @param paused bool: True to pause input; False to resume input.
## @param deep bool: Apply recursively to children if true.
static func set_input_process_state(node: Node, paused: bool, deep: bool = false) -> void:
	assert(node != null, "❌ Node must not be null.")

	node.set_process_input(not paused)
	node.set_process_unhandled_input(not paused)
	node.set_process_unhandled_key_input(not paused)
	node.set_process_shortcut_input(not paused)

	# Apply input processing state recursively to all child nodes
	if deep:
		for child in node.get_children():
			if child is Node:
				set_input_process_state(child, paused, true)


## Sets logic and physics processing state for a node (and optionally its children).
##
## @param node Node: Target node.
## @param paused bool: True to pause logic and physics; False to resume.
## @param deep bool: Apply recursively to children if true.
static func set_logic_process_state(node: Node, paused: bool, deep: bool = false) -> void:
	assert(node != null, "❌ Node must not be null.")

	node.set_process(not paused)
	node.set_physics_process(not paused)
	node.set_process_internal(not paused)
	node.set_physics_process_internal(not paused)

	# Apply input processing state recursively to all child nodes
	if deep:
		for child in node.get_children():
			if child is Node:
				set_logic_process_state(child, paused, true)


## Sets animation playback state for a single node (Tween, AnimationPlayer, AnimationTree).
##
## @param node Variant: Variant to modify.
## @param paused bool: True to pause animations; False to resume.
static func set_animation_process_state(node: Variant, paused: bool) -> void:
	assert(node != null, "❌ Node must not be null.")

	if node is Tween:
		node.set_paused(paused)
	elif node is AnimationPlayer:
		node.playback_active = not paused
	elif node is AnimationTree:
		node.active = not paused


## Sets all process states (logic, input, animation) for a node (and optionally its children).
##
## @param node Node: Target node.
## @param paused bool: True to pause all processes; False to resume.
## @param deep bool: Apply recursively to children if true.
static func set_all_process_state(node: Node, paused: bool, deep: bool = false) -> void:
	assert(node != null, "❌ Node must not be null.")

	set_logic_process_state(node, paused)
	set_input_process_state(node, paused)
	set_animation_process_state(node, paused)

	# Apply input processing state recursively to all child nodes
	if deep:
		for child in node.get_children():
			if child is Node:
				set_all_process_state(child, paused, true)


## Sets scene-wide logic, physics, input, and animation state.
##
## @param root Node: Root node of the scene tree.
## @param paused bool: True to pause everything; False to resume everything.
static func set_scene_process_state(root: Node, paused: bool) -> void:
	assert(root != null, "❌ Root node must not be null.")

	set_all_process_state(root, paused, true)


## Sets scene-wide input processing state only.
##
## @param root Node: Root node of the scene tree.
## @param paused bool: True to pause input only; False to resume input.
static func set_scene_input_state(root: Node, paused: bool) -> void:
	assert(root != null, "❌ Root node must not be null.")

	set_input_process_state(root, paused, true)
