class_name SpringSecondaryMotion
extends Node

## Spring-damper secondary physics system (F = -k*x - c*v)
## Simulates organic inertia, drag, and elasticity for tails, cloth, accessories, and floating orbs.

@export var target_node: Node2D
@export var stiffness: float = 120.0
@export var damping: float = 12.0
@export var mass: float = 1.0

@export var rot_stiffness: float = 85.0
@export var rot_damping: float = 10.0
@export var rot_mass: float = 1.0

# Linear state
var base_position: Vector2 = Vector2.ZERO
var current_offset: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var target_offset: Vector2 = Vector2.ZERO

# Angular state (in degrees)
var base_rotation: float = 0.0
var current_rot_offset: float = 0.0
var rot_velocity: float = 0.0
var target_rot_offset: float = 0.0

# Inertia tracking
var previous_parent_pos: Vector2 = Vector2.ZERO
var track_parent_movement: bool = false
var inertia_influence: float = 0.35

var is_active: bool = true

func _ready() -> void:
	if target_node:
		init_from_target(target_node)

func init_from_target(node: Node2D) -> void:
	target_node = node
	base_position = node.position
	base_rotation = node.rotation_degrees
	current_offset = Vector2.ZERO
	velocity = Vector2.ZERO
	target_offset = Vector2.ZERO
	current_rot_offset = 0.0
	rot_velocity = 0.0
	target_rot_offset = 0.0
	var p = node.get_parent()
	if p is Node2D:
		previous_parent_pos = (p as Node2D).global_position

func _process(delta: float) -> void:
	if not is_active or not is_instance_valid(target_node):
		return

	# Prevent numerical instability on huge frame skips
	var dt: float = clampf(delta, 0.001, 0.05)

	# Parent motion lag / inertia
	if track_parent_movement and target_node.get_parent() is Node2D:
		var p_pos: Vector2 = (target_node.get_parent() as Node2D).global_position
		var delta_pos: Vector2 = p_pos - previous_parent_pos
		previous_parent_pos = p_pos
		if delta_pos.length_squared() > 0.001:
			# Apply counter inertia
			velocity -= delta_pos * (inertia_influence * 60.0)
			rot_velocity -= delta_pos.x * 0.8

	# Linear Spring-Damper simulation
	var f_spring: Vector2 = -stiffness * (current_offset - target_offset)
	var f_damp: Vector2 = -damping * velocity
	var accel: Vector2 = (f_spring + f_damp) / maxf(0.01, mass)
	velocity += accel * dt
	current_offset += velocity * dt

	# Angular Spring-Damper simulation
	var rf_spring: float = -rot_stiffness * (current_rot_offset - target_rot_offset)
	var rf_damp: float = -rot_damping * rot_velocity
	var r_accel: float = (rf_spring + rf_damp) / maxf(0.01, rot_mass)
	rot_velocity += r_accel * dt
	current_rot_offset += rot_velocity * dt

	# Clamp to reasonable bounds to avoid visual artifacts
	current_offset.x = clampf(current_offset.x, -60.0, 60.0)
	current_offset.y = clampf(current_offset.y, -60.0, 60.0)
	current_rot_offset = clampf(current_rot_offset, -45.0, 45.0)

	# Apply to target
	target_node.position = base_position + current_offset
	target_node.rotation_degrees = base_rotation + current_rot_offset

## Apply instantaneous linear impulse
func apply_impulse(impulse: Vector2) -> void:
	velocity += impulse / maxf(0.01, mass)

## Apply instantaneous rotational impulse (in degrees/sec)
func apply_angular_impulse(impulse_deg: float) -> void:
	rot_velocity += impulse_deg / maxf(0.01, rot_mass)

## Manually set a target offset to lean into (e.g. card drag gaze)
func set_target_pose(offset: Vector2, rot_deg: float) -> void:
	target_offset = offset
	target_rot_offset = rot_deg

## Snap back to rest position
func reset_to_base() -> void:
	current_offset = Vector2.ZERO
	velocity = Vector2.ZERO
	target_offset = Vector2.ZERO
	current_rot_offset = 0.0
	rot_velocity = 0.0
	target_rot_offset = 0.0
	if is_instance_valid(target_node):
		target_node.position = base_position
		target_node.rotation_degrees = base_rotation

func is_settled(threshold: float = 0.1) -> bool:
	return velocity.length() < threshold and absf(rot_velocity) < threshold and (current_offset - target_offset).length() < threshold and absf(current_rot_offset - target_rot_offset) < threshold
