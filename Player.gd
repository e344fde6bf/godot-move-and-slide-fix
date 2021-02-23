extends KinematicBody

const physics_speed = 1
const GRAVITY = -120 * physics_speed
const JUMP_SPEED = 50 * physics_speed
const PLAYER_SPEED = 30 * physics_speed
const MAX_SLOPE_ANGLE = deg2rad(60)
const CAMERA_CLAMP_ANGLE = deg2rad(89)
const MAX_SLIDES = 4

export(float, 0.1, 100.0) var camera_distance = 12.0
export var follow_floor_rotation: bool = true
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

export var use_improved_approximation: bool = true

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_position.translate_object_local(Vector3(0, 0, camera_distance))
	debug_info.add("fps", 0)
	debug_info.add("time", 0)
	debug_info.add("use_improved_approximation", use_improved_approximation)

func _process(_delta):
	pass

func _physics_process(delta):
	debug_info.add("fps", Engine.get_frames_per_second())
	debug_info.add("time", OS.get_ticks_msec() / 1000.0)
	debug_info.add("use_improved_approximation", use_improved_approximation)
	process_input(delta)
	process_movement(delta)
	add_position_marker(delta)
	debug_info.render()

func improved_floor_velocity_estimate(delta):
	"""
	This function returns an estimate of the floor velocity for use in
	move_and_slide(). The result should be added to the `velocity` argument of
	`move_and_slide()`.
	
	NOTE: since `move_and_slide()` adds `get_floor_velocity()` internally,
	this function includes `-get_floor_velocity()` in the result to cancel this
	out.
	"""
	if !is_on_floor():
		debug_info.add("angular_velocity", null)
		return Vector3()
	
	return -get_floor_velocity() + floor_velocity_due_to_rotation(delta)

func get_floor_displacement():
	"""
	This function returns how much the floor has moved since the start of the frame
	"""
	# FIXME: don't assume that the first object we collided with was the floor 
	var floor_node = get_slide_collision(0).collider
	var floor_start_pos = PhysicsServer.body_get_direct_state(floor_node.get_rid()).transform.origin
	var intra_frame_motion = floor_node.global_transform.origin - floor_start_pos
	
	return intra_frame_motion
		
func floor_velocity_due_to_rotation(delta):
	# FIXME: don't assume that the first object we collided with was the floor 
	var collision = get_slide_collision(0)
	var floor_node: Node = collision.collider
	var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
	
	if ang_vel == Vector3():
		return Vector3()
	
	# the origin point in global coordinates
	var rotation_origin = floor_node.global_transform.origin
	# updated based on how much we moved this frame already
	var current_collision_pos = self.global_transform.origin + get_floor_displacement()
	var collision_pos_relative = current_collision_pos - rotation_origin
	var next_rotated_xform = Transform().rotated(ang_vel.normalized(), ang_vel.length()*delta)
	var collision_pos_relative_next = next_rotated_xform.xform(collision_pos_relative)
	
	var v_avg = (collision_pos_relative_next - collision_pos_relative) / delta

	debug_info.add("angular_velocity", ang_vel)
	return v_avg

func process_movement(delta):
	var cam_transform = camera.get_global_transform()
	dir = Vector3.ZERO

	if input_movement_vector != Vector2():
		dir += cam_transform.basis.x * input_movement_vector[0]
		dir += -cam_transform.basis.z * input_movement_vector[1]
		dir.y = 0
		dir = dir.normalized()

	var player_vel = dir * PLAYER_SPEED
	var floor_vel_adjust = improved_floor_velocity_estimate(delta)
	
	if is_on_floor() and jump_frame_buffering > 0:
		gravity_vel.y = JUMP_SPEED
		# `move_and_slide()` adds `get_floor_velocity()` internally so we add
		# `-get_floor_velocity()` to counteract this in `floor_vel_adjust`.
		# However, now we are goin to jump, we won't collide with the floor,
		# so `move_and_slide()` won't add this value internally, so we don't
		# need to cancel it out this time
		floor_vel_adjust += get_floor_velocity()
		jump_frame_buffering = 0
	else:
		gravity_vel += Vector3.UP * delta * GRAVITY
		jump_frame_buffering -= 1

	vel = player_vel + gravity_vel + floor_vel_adjust * int(use_improved_approximation)
	vel = player.move_and_slide(vel, Vector3.UP, false, MAX_SLIDES)
	gravity_vel = vel.project(Vector3.UP)
	
	if is_on_floor() and use_improved_approximation:
		self.transform.origin += get_floor_displacement()
		gravity_vel = Vector3()

	if is_on_floor() and follow_floor_rotation:
		var collision = get_slide_collision(0)
		var floor_node: Node = collision.collider
		var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
		if ang_vel.length_squared() != 0:
			player_body.transform.basis = player_body.transform.basis.rotated(ang_vel.normalized(), ang_vel.length()*delta)
			# Only rotate around UP-axis for camera
			camera_rotation += ang_vel.project(Vector3.UP)*delta
			camera_helper.rotation = camera_rotation
		
	debug_info.plot_bool("is_on_floor", is_on_floor())
	debug_info.plot_float("floor_velocity()", get_floor_velocity().length())
	debug_info.add("velocity", vel)
	
	
func process_input(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("toggle_vel_func"):
		use_improved_approximation = !use_improved_approximation
			
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
		new_marker.transform = self.transform
		$"..".add_child(new_marker)
		marker_timer = 0.0

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var yaw = camera_rotation.y + event.relative.x * mouse_sensitivity * -1
		var pitch = camera_rotation.x + -event.relative.y * mouse_sensitivity
		yaw = fmod(yaw, 2*PI)
		pitch = clamp(pitch, -CAMERA_CLAMP_ANGLE, CAMERA_CLAMP_ANGLE)
		camera_rotation = Vector3(pitch, yaw, 0)
		
		camera_helper.rotation = camera_rotation
