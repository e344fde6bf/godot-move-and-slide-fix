extends Container

export var label_min_width: float = 100.0

class KeyValueHelper:
	var data = []
	var label_to_index = {}
	var index_to_label = {}
	
	func clear():
		data = []
		label_to_index = {}
		index_to_label = {}
	
	func get(label: String):
		return data[label_to_index[label]]
	
	func add(label: String, value):
		if label in label_to_index:
			data[label_to_index[label]] = value
		else:
			var new_index = data.size()
			label_to_index[label] = new_index
			index_to_label[new_index] = label
			data.append(value)


onready var text_info_node = $TextInfo
onready var item_list_node = $DebugPlots

const plotter_bool = preload("res://DebugPlotterBool.tscn")
const plotter_float = preload("res://DebugPlotterFloat.tscn")

var info_data
var plot_data

func _ready():
	info_data = KeyValueHelper.new()
	plot_data = KeyValueHelper.new()
	
func add(label: String, value):
	info_data.add(label, str(value))

func plot_bool(label: String, value: bool):
	if label in plot_data.label_to_index:
		plot_data.get(label).add_data_point(value)
	else:
		var plot = plotter_bool.instance()
		plot.label = label
		plot.name_min_width = label_min_width
		item_list_node.add_child(plot)
		plot.add_data_point(value)
		plot_data.add(label, plot)
		
func plot_float(label: String, value: float, y_min = 0.0, y_max = 1.0):
	if label in plot_data.label_to_index:
		plot_data.get(label).add_data_point(value, y_min, y_max)
	else:
		var plot = plotter_float.instance()
		plot.label = label
		plot.name_min_width = label_min_width
		item_list_node.add_child(plot)
		plot.add_data_point(value, y_min, y_max)
		plot_data.add(label, plot)
		
func plot_vec3(label: String, value: Vector3, y_min = 0.0, y_max = 1.0):
	if label+".x" in plot_data.label_to_index:
		plot_data.get(label+".x").add_data_point(value.x, y_min, y_max)
		plot_data.get(label+".y").add_data_point(value.y, y_min, y_max)
		plot_data.get(label+".z").add_data_point(value.z, y_min, y_max)
	else:
		var plot_x = plotter_float.instance()
		var plot_y = plotter_float.instance()
		var plot_z = plotter_float.instance()
		plot_x.label = label + ".x"
		plot_y.label = label + ".y"
		plot_z.label = label + ".z"
		plot_x.name_min_width = label_min_width
		plot_y.name_min_width = label_min_width
		plot_z.name_min_width = label_min_width
		item_list_node.add_child(plot_x)
		item_list_node.add_child(plot_y)
		item_list_node.add_child(plot_z)
		plot_x.add_data_point(value.x, y_min, y_max)
		plot_y.add_data_point(value.y, y_min, y_max)
		plot_z.add_data_point(value.z, y_min, y_max)
		plot_data.add(label+".x", plot_x)
		plot_data.add(label+".y", plot_y)
		plot_data.add(label+".z", plot_z)

func render():
	var result = ""
	for i in info_data.data.size():
		var label = info_data.index_to_label[i]
		result += "%s: %s\n" % [label, info_data.data[info_data.label_to_index[label]]]
	text_info_node.text = result
	
	for i in plot_data.data.size():
		plot_data.data[i].update()

