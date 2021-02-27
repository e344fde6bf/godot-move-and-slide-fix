extends KinematicBody

const physics_speed = 1
const GRAVITY = -120 * physics_speed * physics_speed
const JUMP_SPEED = 50 * physics_speed
const PLAYER_SPEED = 30 * physics_speed
const MAX_SLOPE_ANGLE = deg2rad(85)
const CAMERA_CLAMP_ANGLE = deg2rad(89)
const MAX_SLIDES = 4

export(float, 0.1, 100.0) var camera_distance = 12.0
export var follow_floor_rotation: bool = true
export var use_global_up: bool = true
export var fix_enabled: bool = true
export var use_position_markers: bool = true
var mouse_sensitivity = 0.01

onready var player = $"."
onready var player_body = $PlayerBody
onready var model = $PlayerBody
onready var camera_helper = $CameraHelper
onready var camera = $CameraHelper/CameraPosition/Camera
onready var camera_position = $CameraHelper/CameraPosition
onready var debug_info = $DebugInfo

const pos_marker = preload("res://PosMarker.tscn")

var dir: Vector3
var input_movement_vector: Vector2
var vel: Vector3 = Vector3()
var camera_rotation = Vector3()
var gravity_vel: Vector3 = Vector3()
const JUMP_BUFFER_FRAME_COUNT = 3
var jump_frame_buffering: int = 0
var floor_node = null

var global_parent = null
var current_parent = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_position.translate_object_local(Vector3(0, 0, camera_distance))
	debug_info.add("fps", 0)
	debug_info.add("time", 0)
	global_parent = get_parent()
	current_parent = global_parent

func _process(_delta):
	pass

func _physics_process(delta):
	debug_info.add("fps", Engine.get_frames_per_second())
	debug_info.add("time", OS.get_ticks_msec() / 1000.0)
	debug_info.add("fix_enabled", str(fix_enabled) + " (Press Q to Toggle)")
	debug_info.add("use_global_up", str(use_global_up) + " (Press E to Toggle)")
	process_input(delta)
	process_movement(delta)
	if use_position_markers:
		add_position_marker(delta)
	debug_info.render()

func get_floor_node():
	""" a hacky function to find the floor node """
	assert(is_on_floor())
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal != get_floor_normal():
			continue
		if collision.collider_velocity != get_floor_velocity():
			continue
		return collision.collider
	assert(false)

func make_parent(new_parent):
	assert(new_parent != current_parent)
	var old_transform = self.global_transform
	current_parent.remove_child(self)
	new_parent.add_child(self)
	self.global_transform = old_transform
	current_parent = new_parent

func get_floor_displacement(delta):
	return get_floor_linear_displacement()

func get_floor_linear_displacement():
	"""
	This function returns how much the floor has moved since the start of the frame
	"""
	var floor_start_pos = PhysicsServer.body_get_direct_state(floor_node.get_rid()).transform.origin
	return floor_node.global_transform.origin - floor_start_pos

func lock_basis_up_direction():
	# Want to keep the players up direction set to (0, 1, 0)
	var old_basis = global_transform.basis
	var new_basis = Basis()
	# use fixed up direction
	new_basis.y = Vector3.UP
	# keep forward direction (yaw) by projecting it onto the xz plane
	var z_planar = old_basis.z - old_basis.z.project(Vector3.UP)
	new_basis.z = z_planar.normalized()
	# choose x as the direction orthognal to these two
	new_basis.x = new_basis.y.cross(new_basis.z)
	global_transform.basis = new_basis

func handle_player_rotations(delta):
	var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
	debug_info.add("floor angular_vel", ang_vel)
	if ang_vel == Vector3():
		return
		
	var vertical = ang_vel.project(Vector3.UP)
		
	if !follow_floor_rotation:
		camera_rotation -= vertical*delta
		camera_helper.rotation = camera_rotation
	
	if use_global_up:
		lock_basis_up_direction()
		
		# another way to do this, but numerical errors means our up direction won't be exact
#		var planar = ang_vel - vertical
#		global_transform.basis = global_transform.basis.rotated(planar.normalized(), -planar.length()*delta)


func process_movement(delta):
	var cam_transform = camera.get_global_transform()
	dir = Vector3.ZERO

	if input_movement_vector != Vector2():
		dir += cam_transform.basis.x * input_movement_vector[0]
		dir += -cam_transform.basis.z * input_movement_vector[1]
		dir.y = 0
		dir = dir.normalized()

	var player_vel = dir * PLAYER_SPEED
	
	if is_on_floor() and jump_frame_buffering > 0:
		gravity_vel.y = JUMP_SPEED
		jump_frame_buffering = 0
		player_vel += get_floor_velocity()
	else:
		gravity_vel += Vector3.UP * delta * GRAVITY
		jump_frame_buffering -= 1
	
	if floor_node != null and fix_enabled:
		self.transform.origin -= get_floor_displacement(delta)
	
	vel = player_vel + gravity_vel - get_floor_velocity()
	vel = move_and_slide(vel, Vector3.UP, false, MAX_SLIDES, MAX_SLOPE_ANGLE)
		
	floor_node = get_floor_node() if is_on_floor() else null
	if is_on_floor():
		gravity_vel = Vector3()
	
	if floor_node != null:
		handle_player_rotations(delta)
	
	if floor_node != null and fix_enabled:
		self.transform.origin += get_floor_displacement(delta)
		
	if is_on_floor() and current_parent != floor_node:
		make_parent(floor_node)
	elif !is_on_floor() and current_parent != global_parent:
		make_parent(global_parent)
		lock_basis_up_direction()
		
	debug_info.plot_bool("is_on_floor", is_on_floor())
	debug_info.plot_float("floor_velocity()", get_floor_velocity().length())
	debug_info.add("parent", str(current_parent) + " : " + current_parent.name)
	
	debug_info.add("local.basis.x", transform.basis.x)
	debug_info.add("local.basis.y", transform.basis.y)
	debug_info.add("local.basis.z", transform.basis.z)
	
	debug_info.add("global.basis.x", global_transform.basis.x)
	debug_info.add("global.basis.y", global_transform.basis.y)
	debug_info.add("global.basis.z", global_transform.basis.z)


func process_input(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("toggle_fix1"):
		fix_enabled = !fix_enabled
	if Input.is_action_just_pressed("toggle_fix2"):
		use_global_up = ! use_global_up

	input_movement_vector = Vector2()
	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1

	input_movement_vector = input_movement_vector.normalized()

	if is_on_floor() and Input.is_action_just_pressed("movement_jump"):
		jump_frame_buffering = JUMP_BUFFER_FRAME_COUNT

var marker_timer: float = 0.0
func add_position_marker(delta):
	marker_timer += delta
	if marker_timer > 0.1:
		var new_marker = pos_marker.instance()
		new_marker.global_transform = self.global_transform
		global_parent.add_child(new_marker)
		marker_timer = 0.0

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var yaw = camera_rotation.y + event.relative.x * mouse_sensitivity * -1
		var pitch = camera_rotation.x + -event.relative.y * mouse_sensitivity
		yaw = fmod(yaw, 2*PI)
		pitch = clamp(pitch, -CAMERA_CLAMP_ANGLE, CAMERA_CLAMP_ANGLE)
		camera_rotation = Vector3(pitch, yaw, 0)
		
		camera_helper.rotation = camera_rotation
