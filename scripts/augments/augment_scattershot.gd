class_name AugmentScattershot
extends Augment

@export var pellets_added:      int   = 4
@export var damage_multiplier:  float = 0.6


func _init() -> void:
	target = Augment.Target.ACTIVE_WEAPON


func apply_to_weapon(weapon: WeaponComponent) -> void:
	weapon.pellets_per_shot  += pellets_added
	weapon.projectile_damage *= damage_multiplier


func preview_weapon_stats(weapon: WeaponComponent) -> Dictionary:
	return {
		"pellets_per_shot":  float(weapon.pellets_per_shot + pellets_added),
		"projectile_damage": weapon.projectile_damage * damage_multiplier,
	}
