extends PhysicsBody

export var angular_velocity = 0.25
export var enabled: bool = true

var start_pos: Vector3

var last_t = 0.0
var t = 0.0

func _ready():
	start_pos = self.transform.origin

func _physics_process(delta):
	t += delta
	
	if not enabled:
		return
		
	self.transform.basis = self.transform.basis.rotated(Vector3.UP, delta * 2 * PI * angular_velocity)
