extends Node
## PlayerSpawner — autoloaded singleton.
## Instantiates Character scenes at given spawn points.

const CHARACTER_SCENE: PackedScene = preload("res://characters/character.tscn")

## Spawn a character at the given spawn point.
## Adds it to `parent` (or current scene root if null) and returns the instance.
func spawn_player(spawn_point: Node3D, parent: Node = null) -> Node3D:
	if spawn_point == null:
		push_error("PlayerSpawner.spawn_player: spawn_point is null")
		return null

	var character: Node3D = CHARACTER_SCENE.instantiate()

	if parent == null:
		parent = get_tree().current_scene

	parent.add_child(character)
	character.global_transform = spawn_point.global_transform

	print("[PlayerSpawner] Spawned character at ", spawn_point.global_position)
	return character
