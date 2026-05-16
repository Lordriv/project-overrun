# health_component.gd
class_name HealthComponent
extends Node

@export var max_hp: float = 100.0
@export var max_shield: float = 75.0
@export var armor: float = 25.0 ## percent damage reduction 0-100
@export var shield_regen_rate: float = 20.0
@export var hp_regen_rate: float = 5.0
@export var regen_delay: float = 1.5
@export var bleedout_time: float = 10.0

var current_hp: float
var current_shield: float
var is_downed: bool = false
var is_dead: bool = false

var _regen_timer: float = 0.0
var _in_combat: bool = false
var _bleedout_timer: float = 0.0

signal damaged(amount: float, current_hp: float, current_shield: float)
signal healed(amount: float, current_hp: float)
signal shield_broken
signal shield_restored
signal downed
signal revived
signal died

func _ready() -> void:
	current_hp = max_hp
	current_shield = max_shield

func _process(delta: float) -> void:
	if is_dead:
		return
	if is_downed:
		_tick_bleedout(delta)
		return
	_tick_regen(delta)

func _tick_regen(delta: float) -> void:
	if _in_combat:
		_regen_timer += delta
		if _regen_timer >= regen_delay:
			_in_combat = false
			_regen_timer = 0.0
		return
	if current_shield < max_shield:
		current_shield = minf(current_shield + shield_regen_rate * delta, max_shield)
		if current_shield >= max_shield:
			emit_signal("shield_restored")
	if current_hp < max_hp:
		current_hp = minf(current_hp + hp_regen_rate * delta, max_hp)

func _tick_bleedout(delta: float) -> void:
	_bleedout_timer += delta
	if _bleedout_timer >= bleedout_time:
		_die()

func take_damage(amount: float, _damage_type: String = "physical") -> void:
	if is_dead or is_downed:
		return
	_in_combat = true
	_regen_timer = 0.0
	var remaining := amount
	if current_shield > 0.0:
		var shield_hit := minf(remaining, current_shield)
		current_shield -= shield_hit
		remaining -= shield_hit
		if current_shield <= 0.0:
			current_shield = 0.0
			emit_signal("shield_broken")
	if remaining > 0.0:
		remaining = remaining * (1.0 - armor / 100.0)
		current_hp -= remaining
		if current_hp <= 0.0:
			current_hp = 0.0
			_enter_downed()
			emit_signal("damaged", amount, current_hp, current_shield)
			return
	emit_signal("damaged", amount, current_hp, current_shield)

func heal(amount: float) -> void:
	if is_dead or is_downed:
		return
	current_hp = minf(current_hp + amount, max_hp)
	emit_signal("healed", amount, current_hp)

func lifesteal(damage_dealt: float, multiplier: float = 0.15) -> void:
	heal(damage_dealt * multiplier)

func restore_shield(amount: float) -> void:
	if is_dead:
		return
	current_shield = minf(current_shield + amount, max_shield)

func revive(hp_percent: float = 0.3) -> void:
	if not is_downed or is_dead:
		return
	is_downed = false
	_bleedout_timer = 0.0
	current_hp = max_hp * hp_percent
	current_shield = 0.0
	emit_signal("revived")

func kill() -> void:
	_die()

func _enter_downed() -> void:
	is_downed = true
	_bleedout_timer = 0.0
	emit_signal("downed")

func _die() -> void:
	is_dead = true
	is_downed = false
	emit_signal("died")

func get_hp_percent() -> float:
	return current_hp / max_hp

func get_shield_percent() -> float:
	return current_shield / max_shield

func is_alive() -> bool:
	return not is_dead and not is_downed
