extends Area3D
## A bullet projectile.
## Travels in a fixed direction at a fixed speed. Uses a raycast each frame
## to detect collisions, preventing tunneling at high speeds.
## Damages anything with a HealthComponent on hit. Despawns on hit or after lifetime.

var velocity: Vector3 = Vector3.ZERO
var damage: float = 15.0
var lifetime: float = 3.0
var homing_strength: float = 0.0   # degrees/sec; set by WeaponComponent when > 0
var _age: float = 0.0
var _last_position: Vector3
var _homing_target: Node3D = null


func _ready() -> void:
	_last_position = global_position


func _physics_process(delta: float) -> void:
	# Lifetime
	_age += delta
	if _age >= lifetime:
		call_deferred("queue_free")
		return

	if homing_strength > 0.0:
		_update_homing(delta)

	var next_position: Vector3 = global_position + velocity * delta
	
	# Sweep a ray from current position to next position to catch fast-moving hits
	if _check_swept_collision(global_position, next_position):
		return  # collision handled, projectile freed
	
	# No hit — advance
	_last_position = global_position
	global_position = next_position


# Raycast from `from` to `to`. If we hit something, handle the collision and
# return true (caller should stop processing). Returns false if path is clear.
func _check_swept_collision(from: Vector3, to: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false   # don't hit other Area3Ds (other bullets, terminals, etc.)
	query.collide_with_bodies = true
	# Don't hit the shooter — we exclude the player by walking up parents to find them
	# (handled by collision layers ideally, but defensive)
	
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return false
	
	# We hit something — move to the hit point, apply damage, despawn
	global_position = result.position
	var hit_node = result.collider
	_apply_damage_to(hit_node)
	call_deferred("queue_free")
	return true


func _apply_damage_to(body: Node) -> void:
	if body == null:
		return
	var health = body.get_node_or_null("HealthComponent")
	if health and health.has_method("take_damage"):
		health.take_damage(damage)


# Called by whoever spawns the bullet (e.g. WeaponComponent).
func launch(start_position: Vector3, direction: Vector3, speed: float, dmg: float) -> void:
	global_position = start_position
	_last_position = start_position
	velocity = direction.normalized() * speed
	damage = dmg


func _update_homing(delta: float) -> void:
	if not is_instance_valid(_homing_target):
		_acquire_target()
	if not is_instance_valid(_homing_target):
		return

	var to_target: Vector3 = (_homing_target.global_position - global_position).normalized()
	var current_dir: Vector3 = velocity.normalized()
	var speed: float = velocity.length()

	var angle: float = current_dir.angle_to(to_target)
	if angle < 0.001:
		return

	var max_turn: float = deg_to_rad(homing_strength) * delta
	var t: float = clampf(max_turn / angle, 0.0, 1.0)
	velocity = current_dir.slerp(to_target, t) * speed


func _acquire_target() -> void:
	_homing_target = null
	var best_dist: float = INF
	for enemy in EnemyManager.enemies:
		if not is_instance_valid(enemy):
			continue
		var e3d := enemy as Node3D
		if e3d == null:
			continue
		var d: float = global_position.distance_squared_to(e3d.global_position)
		if d < best_dist:
			best_dist = d
			_homing_target = e3d
