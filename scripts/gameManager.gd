extends Node

var wander_radius: float = 200.0

var sustos: int = 100

var house: House

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Config.carregar()

# congela o jogo um instante pra dar peso num susto grande;
# não mexe se o menu de ações já estiver em câmera lenta
func hitstop(duracao: float) -> void:
	if Engine.time_scale != 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duracao, true, false, true).timeout
	if Engine.time_scale == 0.05:
		Engine.time_scale = 1.0
