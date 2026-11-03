extends Node

var wander_radius: float = 200.0

const SUSTOS_INICIAIS = 5
var sustos: int = SUSTOS_INICIAIS
# quantos npcs infartaram nesta partida
var mortes: int = 0

var house: House
# música e efeitos sonoros
var som: Node = preload("res://scripts/som.gd").new()
# um tween só mexe no time_scale da câmera lenta (menu de ações e arraste de carta): quem pede por último vale
var tween_tempo: Tween

# celular: o dedo faz o papel do mouse e a interface da partida fica maior (ajustar_tela)
var toque: bool = OS.has_feature("mobile")
const ESCALA_CELULAR = 1.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_child(som)
	Config.carregar()
	if toque:
		get_tree().node_added.connect(ajustar_tela)

# no celular a partida usa a interface 1,5x maior; menu e créditos foram desenhados em 1920×1080 fixos e
# ficam como são, com faixas nas laterais. roda quando a cena entra, antes do _ready de qualquer filho dela
func ajustar_tela(node: Node) -> void:
	# só a cena nova: prévia de arraste e dica também entram na raiz
	if node.get_parent() != get_tree().root or node.scene_file_path == "":
		return
	var jogo = node is House
	var janela = get_tree().root
	janela.content_scale_factor = ESCALA_CELULAR if jogo else 1.0
	janela.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if jogo else Window.CONTENT_SCALE_ASPECT_KEEP

# o voltar do Android vale o Esc: pausa, fecha a lore, cancela a mira
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for apertado in [true, false]:
			var esc = InputEventAction.new()
			esc.action = &"ui_cancel"
			esc.pressed = apertado
			Input.parse_input_event(esc)

# no celular o "mouse" fica parado onde o dedo saiu: hover só vale com o dedo na tela
func hover_valido() -> bool:
	return not toque or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

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
