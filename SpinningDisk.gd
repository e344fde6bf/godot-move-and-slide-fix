extends PhysicsBody

export var angular_velocity: float = 0.25
export var rotation_axis: Vector3 = Vector3.UP
export var enabled: bool = true

var start_pos: Vector3

var last_t = 0.0
var t = 0.0

func _ready():
	start_pos = self.transform.origin
	rotation_axis = rotation_axis.normalized()

func _physics_process(delta):
	t += delta
	
	if not enabled:
		return
		
	self.transform.basis = self.transform.basis.rotated(rotation_axis, delta * 2 * PI * angular_velocity)
