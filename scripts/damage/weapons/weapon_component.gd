extends Node3D
class_name WeaponComponent
## Handles firing projectiles and managing ammo/reload for a single weapon.
## Sits on the player as a child node. Only the "active" weapon reads input;
## inactive weapons keep ticking cooldowns and reloads in the background.

# --- Weapon stats ---
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/projectile.tscn")
@export var fire_rate: float = 8.0
@export var projectile_speed: float = 60.0
@export var projectile_damage: float = 15.0
@export var spread_degrees: float = 0.5
@export var spread_degrees_vertical: float = 0.5
@export var pellets_per_shot: int = 1
@export var max_aim_distance: float = 1000.0
@export var knockback_per_shot: float = 0.0  # m/s impulse applied to shooter per shot
@export var firing_chevron_offset: float = 15.0

# --- Ammo & reload ---
@export var magazine_size: int = 30
@export var reload_duration: float = 1.2  # seconds for a full empty→full reload

# --- Required references (assigned via Inspector) ---
@export var muzzle: Node3D
@export var camera: Camera3D

# --- Public state (read by HUD / crosshair) ---
var current_ammo: int = 0
var is_reloading: bool = false
var reload_progress: float = 0.0  # 0.0 → 1.0

# --- Internal state ---
var _fire_cooldown: float = 0.0
var _is_active: bool = true
var _reload_starting_ammo: int = 0

# --- Signals ---
signal fired(remaining_ammo: int)
signal reload_started()
signal reload_progress_changed(progress: float)
signal reload_completed()
signal reload_cancelled()


func _ready() -> void:
	current_ammo = magazine_size


# Called by WeaponHolder when this weapon becomes the active one (or stops).
func set_active(active: bool) -> void:
	_is_active = active


func _physics_process(delta: float) -> void:
	# Cooldowns and reload progress always tick (so swapping mid-action preserves state)
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if is_reloading:
		_tick_reload(delta)
	
	# Only the active weapon reads input
	if not _is_active:
		return
	
	_handle_input()


func _handle_input() -> void:
	# Manual reload (R)
	if Input.is_action_just_pressed("reload"):
		if not is_reloading and current_ammo < magazine_size:
			_start_reload()
	
	# Fire (left mouse)
	if Input.is_action_pressed("attack1") and _fire_cooldown <= 0.0:
		if is_reloading:
			# Cancellable only on top-off reloads; reloads from empty must complete
			if current_ammo > 0 and _reload_starting_ammo > 0:
				_cancel_reload()
				_fire()
		elif current_ammo > 0:
			_fire()
		else:
			_start_reload()


# --- Firing ---

func _fire() -> void:
	if muzzle == null or camera == null or projectile_scene == null:
		push_error("WeaponComponent: muzzle, camera, or projectile_scene not set")
		return
	
	var aim_point: Vector3 = _get_aim_point()
	var muzzle_pos: Vector3 = muzzle.global_position
	var base_direction: Vector3 = (aim_point - muzzle_pos).normalized()
	
	# Spawn pellets, each with its own random spread
	for i in range(pellets_per_shot):
		var pellet_direction: Vector3 = _apply_spread(base_direction, spread_degrees, spread_degrees_vertical)
		var projectile = projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.launch(muzzle_pos, pellet_direction, projectile_speed, projectile_damage)
	
	current_ammo -= 1
	_fire_cooldown = 1.0 / fire_rate
	
	# Apply knockback to the shooter (if any)
	if knockback_per_shot > 0.0:
		var shooter := _get_shooter()
		if shooter and shooter.has_method("apply_knockback"):
			# Knockback direction is opposite of where we aimed
			shooter.apply_knockback(-base_direction, knockback_per_shot)
	
	fired.emit(current_ammo)


# --- Reload ---

func _start_reload() -> void:
	if is_reloading or current_ammo >= magazine_size:
		return
	is_reloading = true
	reload_progress = 0.0
	_reload_starting_ammo = current_ammo
	reload_started.emit()


func _tick_reload(delta: float) -> void:
	# Reload time scales with how much needs refilling
	# (faster to top off a near-full mag than to refill from empty)
	var missing_at_start: int = magazine_size - _reload_starting_ammo
	if missing_at_start <= 0:
		_complete_reload()
		return
	
	var effective_duration: float = maxf(0.001, reload_duration * (float(missing_at_start) / magazine_size))
	reload_progress += delta / effective_duration
	
	# Continuously update ammo so cancellation keeps partial progress
	var refilled: int = int(reload_progress * missing_at_start)
	current_ammo = mini(_reload_starting_ammo + refilled, magazine_size)
	
	if reload_progress >= 1.0:
		_complete_reload()
	else:
		reload_progress_changed.emit(reload_progress)


func _complete_reload() -> void:
	reload_progress = 1.0
	current_ammo = magazine_size
	is_reloading = false
	reload_completed.emit()


func _cancel_reload() -> void:
	if not is_reloading:
		return
	is_reloading = false
	reload_progress = 0.0
	reload_cancelled.emit()


# --- Aim / spread helpers ---

func _get_aim_point() -> Vector3:
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + (-camera.global_transform.basis.z) * max_aim_distance
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_get_owner_rid()]
	
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.position if not result.is_empty() else to


func _get_owner_rid() -> RID:
	var node := get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node.get_rid()
		node = node.get_parent()
	return RID()

func _get_shooter() -> Node:
	# Walk up parents to find the CharacterBody3D (the player)
	var node := get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _apply_spread(direction: Vector3, h_degrees: float, v_degrees: float) -> Vector3:
	if h_degrees <= 0.0 and v_degrees <= 0.0:
		return direction
	
	var h_radians: float = deg_to_rad(h_degrees)
	var v_radians: float = deg_to_rad(v_degrees)
	var random_pitch: float = randf_range(-v_radians, v_radians)
	var random_yaw: float = randf_range(-h_radians, h_radians)
	
	# Find perpendicular axes to direction for tilting
	var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) <= 0.99 else Vector3.RIGHT
	var right: Vector3 = direction.cross(up).normalized()
	var local_up: Vector3 = right.cross(direction).normalized()
	
	return direction.rotated(local_up, random_yaw).rotated(right, random_pitch).normalized()
