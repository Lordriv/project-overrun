class_name Augment
extends Resource
## Base class for all augments. Subclasses override apply_to_player() or
## apply_to_weapon() to define their effect.

enum Scope { PERSONAL, AURA, SQUAD, CONDITIONAL }
enum Target { PLAYER, ACTIVE_WEAPON }

@export var id: StringName
@export var display_name: String = "Unnamed Augment"
@export_multiline var description_upside: String = ""
@export_multiline var description_downside: String = ""
@export var scope: Scope = Scope.PERSONAL
@export var target: Target = Target.PLAYER


# Override these in subclasses depending on target:
func apply_to_player(_player: Node) -> void:
	pass

func apply_to_weapon(_weapon: WeaponComponent) -> void:
	pass


# Returns a dict of stat_name → projected_new_value for the preview panel.
# Only weapon-targeted augments need to implement this.
# Format: {"fire_rate": 12.0, "spread_degrees": 0.7, ...}
func preview_weapon_stats(_weapon: WeaponComponent) -> Dictionary:
	return {}


# Dispatcher — called by AugmentPickUI. Picks the right method based on target.
func apply(player: Node, active_weapon: WeaponComponent) -> void:
	match target:
		Target.PLAYER:
			apply_to_player(player)
		Target.ACTIVE_WEAPON:
			if active_weapon != null:
				apply_to_weapon(active_weapon)
			else:
				push_warning("Augment %s targets weapon but no active weapon" % id)


func get_scope_label() -> String:
	match scope:
		Scope.PERSONAL: return "PERSONAL"
		Scope.AURA: return "AURA"
		Scope.SQUAD: return "SQUAD"
		Scope.CONDITIONAL: return "CONDITIONAL"
		_: return "?"


func get_target_label() -> String:
	match target:
		Target.PLAYER: return "SELF"
		Target.ACTIVE_WEAPON: return "WEAPON"
		_: return "?"
