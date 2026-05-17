class_name AugmentQuickchamber
extends Augment

@export var reload_multiplier: float = 0.5
@export var mag_multiplier:    float = 0.7


func _init() -> void:
	target = Augment.Target.ACTIVE_WEAPON


func apply_to_weapon(weapon: WeaponComponent) -> void:
	weapon.reload_duration *= reload_multiplier
	weapon.magazine_size    = maxi(1, int(weapon.magazine_size * mag_multiplier))
	weapon.current_ammo     = mini(weapon.current_ammo, weapon.magazine_size)


func preview_weapon_stats(weapon: WeaponComponent) -> Dictionary:
	return {
		"reload_duration": weapon.reload_duration * reload_multiplier,
		"magazine_size":   float(maxi(1, int(weapon.magazine_size * mag_multiplier))),
	}
