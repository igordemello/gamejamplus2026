extends Node

var wander_radius: float = 200.0

var sustos: int = 100

var house: House

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Config.carregar()
