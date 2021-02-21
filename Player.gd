extends KinematicBody

const physics_speed = 1
const GRAVITY = -120 * physics_speed
const JUMP_SPEED = 45 * physics_speed
const PLAYER_SPEED = 30 * physics_speed
const MAX_SLOPE_ANGLE = deg2rad(60)
const CAMERA_CLAMP_ANGLE = deg2rad(89)
const MAX_SLIDES = 4

export(float, 0.1, 100.0) var camera_distance = 15.0
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

export var use_improved_approximation: bool = true
var frames_on_floor_count: int = 0
var linear_vel_1: Vector3 # linear velocity of the floor at t[i-1]
var linear_vel_2: Vector3 # linear velocity of the floor at t[i-2]

export var enable_jerk_smoothing: bool = true
export var jerk_limit: float = 2.0
export var smoothing_factor: float = 0.05
var catch_up_vector: Vector3


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_position.translate_object_local(Vector3(0, 0, camera_distance))
	debug_info.add("fps", 0)
	debug_info.add("time", 0)
	debug_info.add("use_improved_approximation", use_improved_approximation)
	debug_info.add("jerk_smoothing", enable_jerk_smoothing)

func _process(_delta):
	debug_info.add("fps", Engine.get_frames_per_second())
	debug_info.add("time", OS.get_ticks_msec() / 1000.0)
	debug_info.add("use_improved_approximation", use_improved_approximation)
	debug_info.add("jerk_smoothing", enable_jerk_smoothing)
	debug_info.render()

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)
	add_position_marker(delta)

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
		debug_info.add("floor_linear_vel", null)
		debug_info.add("floor_linear_accel", null)
		debug_info.add("floor_linear_jerk", null)
		debug_info.add("angular_velocity", null)
		frames_on_floor_count = 0
		return Vector3()
	frames_on_floor_count += 1
	
	return -get_floor_velocity() + floor_linear_velocity(delta) + floor_angular_velocity(delta)

func floor_linear_velocity(delta):
	# FIXME: don't assume that the first object we collided with was the floor 
	var floor_node = get_slide_collision(0).collider
	# get_floor_velocity() uses the velocity of floor stored in the KinematicCollision 
	# created last frame in move_and_slide(). This is one frame out of date when
	# the next frame is being processed so query the PhysicsServer to get the
	# floor's current velocity.
	# FIXME: handle the case were floor node gets deleted between frames, etc
	var floor_vel_newer = PhysicsServer.body_get_direct_state(floor_node.get_rid()).linear_velocity  
	var v0 = floor_vel_newer # velocity of the floor at time t[i]
	
	if frames_on_floor_count == 1:
		linear_vel_1 = v0
		linear_vel_2 = v0
		catch_up_vector = Vector3()
		return v0
	elif frames_on_floor_count >= 2:
		# use finite differences to approximate the floor's velocity during this frame
		var accel_0 = (v0 - linear_vel_1) # acceleration t[i]
		var accel_1 = (linear_vel_1 - linear_vel_2) # acceleration t[i-1]
		var jerk = (accel_0 - accel_1) # jerk t[i]
		
		var jerk_limit_exceeded = (jerk.length_squared() > jerk_limit*jerk_limit) and frames_on_floor_count > 3
		debug_info.plot_bool("excessive jerk", jerk_limit_exceeded)
		jerk_limit_exceeded = jerk_limit_exceeded and enable_jerk_smoothing
		
		var estimated_floor_vel = Vector3()
		
		if frames_on_floor_count == 1:
			estimated_floor_vel = v0
		elif jerk_limit_exceeded:
			estimated_floor_vel = linear_vel_1 + accel_0*0.5
			catch_up_vector += accel_0 + (v0-estimated_floor_vel)
		else:
			estimated_floor_vel = v0 + accel_0 + jerk
			estimated_floor_vel += catch_up_vector * smoothing_factor
			catch_up_vector *= (1 - smoothing_factor)

		
		debug_info.add("floor_linear_vel", v0)
		debug_info.add("floor_linear_accel", accel_0 / delta)
		debug_info.add("floor_linear_jerk", jerk / delta)
		debug_info.plot_float("catch up len", catch_up_vector.length(), 0, 50)
		
		if jerk_limit_exceeded:
			linear_vel_2 = v0
			linear_vel_1 = v0
		else:
			linear_vel_2 = linear_vel_1
			linear_vel_1 = v0
		
		return estimated_floor_vel
		
func floor_angular_velocity(delta):
	# FIXME: don't assume that the first object we collided with was the floor 
	var collision = get_slide_collision(0)
	var floor_node: Node = collision.collider
	var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
	
	if ang_vel.length_squared() == 0:
		return Vector3()
	
	# the origin point in global coordinates
	var rotation_origin = floor_node.global_transform.origin
	# NOTE: collision.point is out of date compared to floor_node current position
	# so want to estimate it for this frame
	# TODO: work this out better
	var current_collision_pos = self.global_transform.origin
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
	
	var floor_vel_adjust 
	if use_improved_approximation:
		floor_vel_adjust = improved_floor_velocity_estimate(delta)
	else:
		floor_vel_adjust = Vector3()
	
	# debug_info.plot_float("floor speed", get_floor_velocity().length(), 0.0, 50.0)
	var floor_vel = (floor_vel_adjust + get_floor_velocity())
	debug_info.plot_float("speed adjust", floor_vel.length(), 0.0, 50.0)

	vel = player_vel + gravity_vel + floor_vel_adjust
	vel = player.move_and_slide(vel, Vector3.UP, false, MAX_SLIDES)
	gravity_vel = vel.project(Vector3.UP)
	
	gravity_vel += Vector3.UP * delta * GRAVITY
	
	debug_info.plot_bool("is_on_floor", is_on_floor())
	debug_info.add("velocity", vel)
	debug_info.add("floor_velocity", get_floor_velocity())

	if is_on_floor() and follow_floor_rotation:
		var collision = get_slide_collision(0)
		var floor_node: Node = collision.collider
		var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
		if ang_vel.length_squared() != 0:
			player_body.transform.basis = player_body.transform.basis.rotated(ang_vel.normalized(), ang_vel.length()*delta)
			# Only rotate around UP-axis for camera
			camera_rotation += ang_vel.project(Vector3.UP)*delta
			camera_helper.rotation = camera_rotation


func process_input(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("toggle_vel_func"):
		use_improved_approximation = !use_improved_approximation
	if Input.is_action_just_pressed("toggle_jerk_smoothing"):
		enable_jerk_smoothing = !enable_jerk_smoothing
			
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
		gravity_vel.y = JUMP_SPEED

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
