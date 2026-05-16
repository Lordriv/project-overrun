extends Node
class_name WeaponHolder
## Manages the character's equipped weapons and which one is currently active.
## Two primary slots (toggled by Q) plus a secondary slot.
## Listeners (HUD, crosshair, sounds) bind to weapon_changed to react to swaps.

# --- Slot references (assigned via Inspector or at runtime) ---
@export var slot_1: WeaponComponent = null    # primary 1 (e.g. rifle)
@export var slot_2: WeaponComponent = null    # primary 2 (e.g. shotgun)
@export var slot_3: WeaponComponent = null    # secondary (e.g. pistol)

# --- Active state ---
var active_slot: int = 1                      # which slot is currently in hands
var active_weapon: WeaponComponent = null

signal weapon_changed(new_weapon: WeaponComponent)


func _ready() -> void:
	# Activate slot 1 by default
	_activate_slot(active_slot)


func _process(_delta: float) -> void:
	# Q: toggle between slot 1 and slot 2 (the two primaries)
	if Input.is_action_just_pressed("weapon_swap"):
		_swap_primaries()
	
	# Direct slot selects
	if Input.is_action_just_pressed("weapon_slot_1"):
		_activate_slot(1)
	elif Input.is_action_just_pressed("weapon_slot_2"):
		_activate_slot(2)
	elif Input.is_action_just_pressed("weapon_slot_3"):
		_activate_slot(3)


func _swap_primaries() -> void:
	# Q toggles between the two primary slots only
	if active_slot == 1:
		_activate_slot(2)
	elif active_slot == 2:
		_activate_slot(1)
	else:
		# If currently on secondary (slot 3), Q returns to slot 1
		_activate_slot(1)


func _activate_slot(slot_number: int) -> void:
	var target_weapon: WeaponComponent = _get_slot(slot_number)
	if target_weapon == null:
		# Slot is empty — do nothing (keeps current weapon active)
		return
	if target_weapon == active_weapon:
		# Already active — do nothing
		return
	
	active_slot = slot_number
	active_weapon = target_weapon
	_update_weapon_active_states()
	weapon_changed.emit(active_weapon)


func _get_slot(slot_number: int) -> WeaponComponent:
	match slot_number:
		1: return slot_1
		2: return slot_2
		3: return slot_3
	return null


func _update_weapon_active_states() -> void:
	# Tell each weapon whether it's active (only active weapon reads input + fires)
	for slot in [slot_1, slot_2, slot_3]:
		if slot != null:
			slot.set_active(slot == active_weapon)
