class_name AugmentStoneSlug
extends Augment

@export var damage_multiplier:   float = 2.0
@export var fire_rate_multiplier: float = 0.5


func _init() -> void:
	target = Augment.Target.ACTIVE_WEAPON


func apply_to_weapon(weapon: WeaponComponent) -> void:
	weapon.projectile_damage *= damage_multiplier
	weapon.fire_rate         *= fire_rate_multiplier


func preview_weapon_stats(weapon: WeaponComponent) -> Dictionary:
	return {
		"projectile_damage": weapon.projectile_damage * damage_multiplier,
		"fire_rate":          weapon.fire_rate         * fire_rate_multiplier,
	}
