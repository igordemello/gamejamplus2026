extends Node

var wander_radius: float = 200.0

const SUSTOS_INICIAIS = 25
var sustos: int = SUSTOS_INICIAIS
# quantos npcs infartaram nesta partida
var mortes: int = 0

var house: House

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Config.carregar()

# a casa chama quando começa (também no Jogar de novo)
func comecar_partida() -> void:
	sustos = SUSTOS_INICIAIS
	mortes = 0

# congela o jogo um instante pra dar peso num susto grande;
# não mexe se o menu de ações já estiver em câmera lenta
func hitstop(duracao: float) -> void:
	if Engine.time_scale != 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duracao, true, false, true).timeout
	if Engine.time_scale == 0.05:
		Engine.time_scale = 1.0
