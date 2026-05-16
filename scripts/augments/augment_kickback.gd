class_name AugmentKickback
extends Augment

@export var projectile_speed_multiplier: float = 3.0   # +200% projectile speed
@export var knockback_addition: float = 8.0            # m/s recoil impulse per shot


func _init() -> void:
	target = Augment.Target.ACTIVE_WEAPON


func apply_to_weapon(weapon: WeaponComponent) -> void:
	weapon.projectile_speed *= projectile_speed_multiplier
	weapon.knockback_per_shot += knockback_addition


func preview_weapon_stats(weapon: WeaponComponent) -> Dictionary:
	return {
		"projectile_speed": weapon.projectile_speed * projectile_speed_multiplier,
		"knockback_per_shot": weapon.knockback_per_shot + knockback_addition,
	}
