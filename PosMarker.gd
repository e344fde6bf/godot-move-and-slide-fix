extends MeshInstance

onready var time_to_live = $TimeToLive

func _ready():
	time_to_live.start()

func _on_TimeToLive_timeout():
	queue_free()
