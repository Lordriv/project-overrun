extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const DASH_SPEED = 25.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 1.0

var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector3.ZERO

var knockback_timer: float = 0.0
const KNOCKBACK_LOCKOUT: float = 0.25

var _mouse_sens_x: float = 0.003
var _mouse_sens_y: float = 0.002
var camera_pitch: float  = 0.0

var _shake_trauma: float = 0.0
var _shake_scale:  float = 1.0

var idle_timer = randf_range(10.0, 20.0)
var playing_variant = false
var input_locked: bool = false

@onready var spring_arm            = $SpringArm3D
@onready var _camera: Camera3D     = $SpringArm3D/Camera3D
@onready var health: HealthComponent = $HealthComponent
@onready var anim_player: AnimationPlayer = $Dwarf/AnimationPlayer


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health.downed.connect(_on_downed)
	health.died.connect(_on_died)
	EnemyManager.register_player(self)
	PlayerData.apply_to_character(self)
	anim_player.animation_finished.connect(_on_animation_finished)
	_apply_sensitivity(float(SettingsManager.get_value("video/mouse_sensitivity")))
	SettingsManager.mouse_sensitivity_changed.connect(_apply_sensitivity)
	_camera.fov = float(SettingsManager.get_value("video/fov"))
	SettingsManager.fov_changed.connect(func(v: float) -> void: _camera.fov = v)
	_shake_scale = float(SettingsManager.get_value("video/screen_shake")) / 100.0
	SettingsManager.screen_shake_changed.connect(func(v: float) -> void: _shake_scale = v / 100.0)
	var crosshair_node = get_parent().get_node_or_null("Crosshair")
	var weapon_holder = $WeaponHolder
	if crosshair_node and weapon_holder:
		var crosshair_control = crosshair_node.get_child(0) if crosshair_node.get_child_count() > 0 else null
		if crosshair_control and crosshair_control.has_method("set_weapon_holder"):
			crosshair_control.set_weapon_holder(weapon_holder)


func _on_downed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	WaveManager.stop_run()
	get_tree().change_scene_to_file("res://scenes/levels/Lobby.tscn")


func _on_died() -> void:
	EnemyManager.unregister_player(self)
	queue_free()


func _exit_tree() -> void:
	PlayerData.save_from_character(self)
	# unregister_player also called in _on_died — this is a safety net for non-death exits
	EnemyManager.unregister_player(self)


func _input(event):
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * _mouse_sens_x)
		camera_pitch -= event.relative.y * _mouse_sens_y
		camera_pitch = clamp(camera_pitch, -1.2, 0.8)
		spring_arm.rotation.x = camera_pitch


func _physics_process(delta):
	if input_locked:
		move_and_slide()
		return

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		return

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		var dash_input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		dash_direction = (transform.basis * Vector3(dash_input_dir.x, 0, dash_input_dir.y)).normalized()
		if dash_direction == Vector3.ZERO:
			dash_direction = -transform.basis.z
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

	if knockback_timer > 0.0:
		knockback_timer -= delta

	var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var kb_influence: float = clamp(knockback_timer / KNOCKBACK_LOCKOUT, 0.0, 1.0)

	var desired_x: float = direction.x * speed if direction else 0.0
	var desired_z: float = direction.z * speed if direction else 0.0

	velocity.x = lerp(desired_x, velocity.x, kb_influence)
	velocity.z = lerp(desired_z, velocity.z, kb_influence)

	if kb_influence <= 0.0 and not direction:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	_update_animation()
	_process_shake(delta)


func _apply_sensitivity(value: float) -> void:
	_mouse_sens_x = value * 0.0006
	_mouse_sens_y = value * 0.0004


func apply_screen_shake(trauma: float) -> void:
	_shake_trauma = min(_shake_trauma + trauma, 1.0)


func apply_knockback(kick_direction: Vector3, force: float) -> void:
	if is_dashing:
		return
	var vertical_dampening: float = 0.35
	velocity.x += kick_direction.x * force
	velocity.y += kick_direction.y * force * vertical_dampening
	velocity.z += kick_direction.z * force
	knockback_timer = KNOCKBACK_LOCKOUT


func _process_shake(delta: float) -> void:
	if _shake_trauma > 0.0:
		_shake_trauma = max(_shake_trauma - delta * 2.5, 0.0)
		var amount := pow(_shake_trauma, 2) * _shake_scale * 0.06
		_camera.h_offset = randf_range(-amount, amount)
		_camera.v_offset = randf_range(-amount, amount)
	elif _camera.h_offset != 0.0 or _camera.v_offset != 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


func _update_animation():
	if not is_on_floor():
		if anim_player.current_animation != "dwarf/jumping":
			anim_player.play("dwarf/jumping")
		_reset_idle()
		return

	var horizontal_speed = Vector2(velocity.x, velocity.z).length()

	if horizontal_speed > 0.1:
		if Input.is_action_pressed("sprint"):
			anim_player.play("dwarf/running")
		else:
			anim_player.play("dwarf/walking")
		_reset_idle()
		return

	if playing_variant:
		return

	idle_timer -= get_physics_process_delta_time()
	if idle_timer <= 0.0:
		_play_random_variant()
	else:
		anim_player.play("dwarf/idle")


func _reset_idle():
	playing_variant = false
	idle_timer = randf_range(10.0, 20.0)


func _play_random_variant():
	var variants = ["dwarf/idle_2", "dwarf/idle_3"]
	var pick = variants[randi() % variants.size()]
	playing_variant = true
	anim_player.play(pick)


func _on_animation_finished(anim_name):
	var s = String(anim_name)
	if s == "dwarf/idle_2" or s == "dwarf/idle_3":
		playing_variant = false
		idle_timer = randf_range(10.0, 20.0)
