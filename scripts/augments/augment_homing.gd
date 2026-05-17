class_name AugmentHoming
extends Augment

@export var homing_strength: float = 120.0   # degrees/sec turn rate
@export var speed_multiplier: float = 0.6    # slower — seeker rounds, not lasers


func _init() -> void:
	target = Augment.Target.ACTIVE_WEAPON


func apply_to_weapon(weapon: WeaponComponent) -> void:
	weapon.homing_strength    = homing_strength
	weapon.projectile_speed  *= speed_multiplier


func preview_weapon_stats(weapon: WeaponComponent) -> Dictionary:
	return {
		"homing_strength":  homing_strength,
		"projectile_speed": weapon.projectile_speed * speed_multiplier,
	}
