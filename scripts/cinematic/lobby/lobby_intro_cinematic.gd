extends Node
## LobbyIntroCinematic

signal finished

const WALK_DURATION     := 4.2
const PLATE_HOLD        := 0.18
const CAMERA_GLIDE      := 0.85
const PAD_FADE_DURATION := 0.35
const INPUT_DELAY       := 0.1

const PAD1_TRIGGER   := 0.05
const PAD2_TRIGGER   := 0.45
const PAD3_TRIGGER   := 1.05
const PAD_MAX_ENERGY := 3.5

var _cinematic_cam: Camera3D
var _start_marker:  Node3D
var _plate_marker:  Node3D
var _pads:          Array
var _character:     Node3D
var _anim_player:   AnimationPlayer
var _spring_arm:    SpringArm3D
var _gameplay_cam:  Camera3D


func play(
		cinematic_cam: Camera3D,
		start_marker:  Node3D,
		plate_marker:  Node3D,
		pads:          Array,
		character:     Node3D
) -> void:
	_cinematic_cam = cinematic_cam
	_start_marker  = start_marker
	_plate_marker  = plate_marker
	_pads          = pads
	_character     = character
	_anim_player   = character.get_node("CharacterBody3D/Dwarf/AnimationPlayer")
	_spring_arm    = character.get_node("CharacterBody3D/SpringArm3D")
	_gameplay_cam  = _spring_arm.get_node("Camera3D")

	for pad in _pads:
		if pad:
			pad.light_energy = 0.0

	var body := _character.get_node("CharacterBody3D")
	body.input_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var crosshair := _character.get_node_or_null("Crosshair")
	if crosshair:
		crosshair.visible = false

	_cinematic_cam.make_current()

	body.global_position = _start_marker.global_position
	body.global_rotation = _start_marker.global_rotation

	# --- Step 1: walk to wall plate ---
	_anim_player.play("dwarf/walking")
	var walk_tween := body.create_tween()
	walk_tween.tween_property(
		body, "global_position",
		_plate_marker.global_position,
		WALK_DURATION
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_face_toward(_plate_marker.global_position, body)
	await walk_tween.finished

	# --- Step 2: plate strike ---
	_anim_player.play("dwarf/idle")
	await get_tree().create_timer(PLATE_HOLD).timeout

	# --- Step 3: LED choreography ---
	_fade_pad_after_delay(0, PAD1_TRIGGER)
	_fade_pad_after_delay(1, PAD2_TRIGGER)
	_fade_pad_after_delay(2, PAD3_TRIGGER)

	await get_tree().create_timer(PAD3_TRIGGER + PAD_FADE_DURATION + 0.2).timeout

	# --- Step 4: camera glide ---
	await _glide_camera_to_springarm()
	if crosshair:
		crosshair.visible = true

	# --- Step 5: unlock input ---
	await get_tree().create_timer(INPUT_DELAY).timeout
	body.input_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	finished.emit()


func _glide_camera_to_springarm() -> void:
	var start_xform := _cinematic_cam.global_transform
	var end_xform   := _gameplay_cam.global_transform

	var elapsed := 0.0
	while elapsed < CAMERA_GLIDE:
		var t := elapsed / CAMERA_GLIDE
		t = t * t * (3.0 - 2.0 * t)
		_cinematic_cam.global_transform = start_xform.interpolate_with(end_xform, t)
		elapsed += get_process_delta_time()
		await get_tree().process_frame

	_gameplay_cam.make_current()


func _fade_pad_after_delay(pad_index: int, delay: float) -> void:
	if _pads.size() == 0:
		return
	await get_tree().create_timer(delay).timeout
	var pad: Light3D = _pads[pad_index]
	if not pad:
		return
	var tween := pad.create_tween()
	tween.tween_property(pad, "light_energy", PAD_MAX_ENERGY, PAD_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _face_toward(target_pos: Vector3, body: Node3D) -> void:
	var dir := (target_pos - body.global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		body.global_rotation.y = atan2(-dir.x, -dir.z)
