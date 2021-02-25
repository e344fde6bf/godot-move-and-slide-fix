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
var floor_node = null

var global_parent = null
var current_parent = null
var is_reparenting = false

func _enter_tree():
	if current_parent == null:
		print("entering the tree for the first time")
		return
	print("entering the tree again from: ", current_parent.name)
	
func _exit_tree():
	print("exiting the tree from: ", current_parent.name)

func _ready():
	if is_reparenting:
		print("reparenting now, this is so")
		is_reparenting = false
		return
	else:
		print("not reparenting")
	print("readying myself")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_position.translate_object_local(Vector3(0, 0, camera_distance))
	debug_info.add("fps", 0)
	debug_info.add("time", 0)
	
	global_parent = get_parent()
	current_parent = global_parent
	print("global_parent set to ", global_parent.name)
	print("current_parent set to ", current_parent.name)

func _process(_delta):
	pass

func _physics_process(delta):
	print("executing physics farme: ", Engine.get_physics_frames())
	debug_info.add("fps", Engine.get_frames_per_second())
	debug_info.add("time", OS.get_ticks_msec() / 1000.0)
	process_input(delta)
	process_movement(delta)
	# add_position_marker(delta)
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

func closure_remove_child(parent, child):
	parent.call_deferred("remove_child", child)

func closure_add_child(parent, child):
	yield(parent.get_tree(), "idle_frame")
	print("added child.  in_physics_frame: ", Engine.is_in_physics_frame())
	parent.call_deferred("add_child", child)

func make_parent(new_parent):
	assert(new_parent != current_parent)
	is_reparenting = true
	var old_transform = self.global_transform
	# closure_remove_child(current_parent, self)
	# closure_add_child(new_parent, self)
	#current_parent.call_deferred("remove_child", self)
	#new_parent.call_deferred("add_child", self)
	current_parent.remove_child(self)
	self.transform.origin = Vector3(9e9, 9e9, 9e9)
	new_parent.add_child(self)
	#print("requesting added child")
	#call_deferred("closure_add_child", new_parent, self)
	# self.owner = new_parent
	self.global_transform = old_transform
	# self.set_physics_process(false)
	# self.call_deferred("set_physics_process", true)
	current_parent = new_parent

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
	else:
		gravity_vel += Vector3.UP * delta * GRAVITY
		jump_frame_buffering -= 1

	vel = player_vel + gravity_vel - get_floor_velocity()
	vel = player.move_and_slide(vel, Vector3.UP, false, MAX_SLIDES)
	gravity_vel = vel.project(Vector3.UP)

	if is_on_floor():
		floor_node = get_floor_node()

	if is_on_floor() and !follow_floor_rotation:
		var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
		if ang_vel != Vector3():
			player_body.transform.basis = player_body.transform.basis.rotated(ang_vel.normalized(), ang_vel.length()*delta)
			# Only rotate around UP-axis for camera
			camera_rotation -= ang_vel.project(Vector3.UP)*delta
			camera_helper.rotation = camera_rotation
		
	debug_info.plot_bool("is_on_floor", is_on_floor())
	debug_info.plot_float("floor_velocity()", get_floor_velocity().length())
	debug_info.add("velocity", vel)
	debug_info.add("parent.name", str(current_parent) + " : " + current_parent.name)
	
	if is_on_floor() and current_parent != floor_node:
		# yield(get_tree(), "idle_frame")
		print("\n", current_parent.name, " -> ", floor_node.name)
		print("in physics frame: ", Engine.get_physics_frames())
		make_parent(floor_node)
		# call_deferred("make_parent", floor_node)
	elif !is_on_floor() and current_parent != global_parent:
		print("\n", current_parent.name, " -> ", global_parent.name)
		print("in physics frame: ", Engine.get_physics_frames())
		# call_deferred("make_parent", global_parent)
		# yield(get_tree(), "idle_frame")
		make_parent(global_parent)


func process_input(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
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
