class_name AugmentFireRate
extends Augment

@export var fire_rate_multiplier: float = 1.5
@export var spread_multiplier: float = 1.4


func _init() -> void:
	target = Augment.Target.ACTIVE_WEAPON


func apply_to_weapon(weapon: WeaponComponent) -> void:
	weapon.fire_rate *= fire_rate_multiplier
	weapon.spread_degrees *= spread_multiplier
	weapon.spread_degrees_vertical *= spread_multiplier


func preview_weapon_stats(weapon: WeaponComponent) -> Dictionary:
	return {
		"fire_rate": weapon.fire_rate * fire_rate_multiplier,
		"spread_degrees": weapon.spread_degrees * spread_multiplier,
		"spread_degrees_vertical": weapon.spread_degrees_vertical * spread_multiplier,
	}
