extends StaticBody

export var gradient: float = 0.01
export var width: float = 20.0
export var length: float = 100.0
export var thick: float = 5.0
export var steps: int = 200
export var slope_type: String = "quadratic"

func linear(x):
	return gradient*x

func quadratic(x):
	return gradient*x*x
	
func cubic(x):
	return gradient*x*x*x
	
func sinusoidal(x):
	return gradient*abs(sin(PI*x/length))

func sinusoidal_inv(x):
	return gradient*(1 - abs(sin(PI*x/length)))

func _ready():
	#var new_mesh = create_mesh(length, width, slope_type, thickness, steps)
	var new_mesh = create_mesh(slope_type)
	$MeshInstance.mesh = new_mesh
	
	var collosion_shape = CollisionShape.new()
	collosion_shape.shape = new_mesh.create_trimesh_shape()
	self.add_child(collosion_shape)

#func create_mesh(length, width, height_func, thick, steps=100):
func create_mesh(height_func):
	var st = SurfaceTool.new()

	var h = float(length) / steps
	var x = 0
	var z0 = call(height_func, x)
	var z1 = call(height_func, x+h)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var norm = Vector3(0, 0, 1)
	# first tri
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x, z0-thick, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(x, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x, z0-thick, width))
	# second tri
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(x, z0, width))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x, z0-thick, width))

	for i in steps:
		x = i * h
		z0 = call(height_func, x)
		z1 = call(height_func, x + h)
		
		norm = Vector3(-(z1 - z0), h, 0).normalized()

		# first tri
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 1))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x, z0, width))
		# second tri
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 0))
		st.add_vertex(Vector3(x+h, z1, width))
		
		
		# side-tri tri 1
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 1))
		st.add_vertex(Vector3(x, z0-thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1-thick, 0))
		# side-tri tri 2
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 0))
		st.add_vertex(Vector3(x+h, z1-thick, 0))
		
		# side-tri tri 3
		st.add_normal(norm)
		st.add_uv(Vector2(0, 1))
		st.add_vertex(Vector3(x, z0-thick, width))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1-thick, width))
		# side-tri tri 4
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 0))
		st.add_vertex(Vector3(x+h, z1-thick, width))
		
		z0 -= thick
		z1 -= thick
		# third tri
		st.add_normal(norm)
		st.add_uv(Vector2(0, 1))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x, z0, width))
		# fourth tri
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 0))
		st.add_vertex(Vector3(x+h, z1, width))

	
	# Create indices, indices are optional.
	st.index()

	# Commit to a mesh.
	# var mesh = st.commit()
	var mesh = st.commit()
	return mesh
