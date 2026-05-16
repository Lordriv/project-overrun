# enemy.gd
extends CharacterBody3D

@export var move_speed: float = 3.0
@export var contact_damage: float = 15.0
@export var damage_cooldown: float = 1.0

@onready var health: HealthComponent = $HealthComponent
@onready var aggro: AggroComponent = $AggroComponent

var _damage_timer: float = 0.0

func _ready() -> void:
	EnemyManager.register_enemy(self)
	health.died.connect(_on_died)
	aggro.target_changed.connect(_on_target_changed)

func _physics_process(delta: float) -> void:
	if health.is_dead or not is_inside_tree():
		return
	_damage_timer -= delta
	if aggro.current_target:
		_move_toward_target(delta)
		_check_contact_damage()
	move_and_slide()

func _move_toward_target(delta: float) -> void:
	var direction := global_position.direction_to(aggro.current_target.global_position)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if not is_on_floor():
		velocity.y -= 30.0 * delta
	else:
		velocity.y = 0.0

func _check_contact_damage() -> void:
	if _damage_timer > 0.0:
		return
	
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		var player_health := collider.get_node_or_null("HealthComponent") as HealthComponent
		if player_health:
			player_health.take_damage(contact_damage)
			_damage_timer = damage_cooldown
			break

func _on_target_changed(new_target: Node) -> void:
	if new_target:
		print("Enemy targeting: ", new_target.name)
	else:
		print("Enemy lost target")

func _on_died() -> void:
	EnemyManager.unregister_enemy(self)
	queue_free()
