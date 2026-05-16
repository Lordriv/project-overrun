extends Node
## AugmentPool — autoloaded singleton.
## Holds all available augments and rolls random selections.
## Later: per-map curated 60-pools. For now: one global flat pool.

const AUGMENTS_DIR: String = "res://resources/augments/"

var _all_augments: Array[Augment] = []


func _ready() -> void:
	_load_all_augments()


func _load_all_augments() -> void:
	var dir := DirAccess.open(AUGMENTS_DIR)
	if dir == null:
		push_error("AugmentPool: cannot open %s" % AUGMENTS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res = load(AUGMENTS_DIR + file_name)
			if res is Augment:
				_all_augments.append(res)
		file_name = dir.get_next()
	print("[AugmentPool] Loaded %d augments" % _all_augments.size())


func roll(count: int) -> Array[Augment]:
	# Sample WITHOUT replacement. If pool < count, just return what we have.
	var pool := _all_augments.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))
