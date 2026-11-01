extends Node

var wander_radius: float = 200.0

const SUSTOS_INICIAIS = 0
var sustos: int = SUSTOS_INICIAIS
# quantos npcs infartaram nesta partida
var mortes: int = 0

var house: House
# um tween só mexe no time_scale da câmera lenta (menu de ações e arraste de carta): quem pede por último vale
var tween_tempo: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Config.carregar()

# a casa chama quando começa (também no Jogar de novo)
func comecar_partida() -> void:
	sustos = SUSTOS_INICIAIS
	mortes = 0

# a câmera lenta entra e sai deslizando (em tempo real, e termina mesmo se pausar no meio)
func mudar_tempo(alvo: float, duracao: float) -> void:
	if tween_tempo:
		tween_tempo.kill()
	tween_tempo = create_tween().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_tempo.tween_property(Engine, "time_scale", alvo, duracao)

# volta ao normal na hora (saiu da casa, pausou pro menu ou acabou a partida no meio da câmera lenta)
func tempo_normal() -> void:
	if tween_tempo:
		tween_tempo.kill()
	Engine.time_scale = 1.0

# congela o jogo um instante pra dar peso num susto grande;
# não mexe se o menu de ações já estiver em câmera lenta
func hitstop(duracao: float) -> void:
	if Engine.time_scale != 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duracao, true, false, true).timeout
	if Engine.time_scale == 0.05:
		Engine.time_scale = 1.0
