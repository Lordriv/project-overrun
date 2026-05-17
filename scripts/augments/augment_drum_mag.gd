class_name AugmentDrumMag
extends Augment

@export var mag_multiplier:    float = 2.0
@export var reload_multiplier: float = 1.5


func _init() -> void:
	target = Augment.Target.ACTIVE_WEAPON


func apply_to_weapon(weapon: WeaponComponent) -> void:
	weapon.magazine_size   = int(weapon.magazine_size * mag_multiplier)
	weapon.current_ammo    = weapon.magazine_size
	weapon.reload_duration *= reload_multiplier


func preview_weapon_stats(weapon: WeaponComponent) -> Dictionary:
	return {
		"magazine_size":   float(int(weapon.magazine_size * mag_multiplier)),
		"reload_duration": weapon.reload_duration * reload_multiplier,
	}
