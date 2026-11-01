extends Control

# as cartas da loja em leque embaixo da tela: em repouso só o topo aparece,
# e a que está embaixo do mouse sobe inteira por cima das outras

@export var escala_repouso: float = 0.5
@export var escala_hover: float = 0.9
@export var passo: float = 150.0
@export var graus_por_carta: float = 2.5
# quanto do topo da carta aparece em repouso, e quanto as pontas descem
@export var altura_visivel: float = 110.0
@export var queda_pontas: float = 1.5
# distância da carta levantada até a borda de baixo
@export var folga_baixo: float = 10.0
@export var tempo_subida: float = 0.12
# câmera lenta enquanto uma carta é arrastada (o mesmo valor do menu de ações)
@export var tempo_lento: float = 0.25

var hover: Control
# carta -> [pé (base-centro) e giro dela em repouso]
var repouso: Dictionary = {}
var tweens: Dictionary = {}
var lento: bool = false

func _ready() -> void:
	resized.connect(organizar)
	organizar()

func organizar() -> void:
	var cartas = get_children()
	var n = cartas.size()
	repouso.clear()
	for i in n:
		var carta: Control = cartas[i]
		var d = i - (n - 1) / 2.0
		# com muitas cartas o passo encolhe pra caberem na tela
		var passo_real = passo if n < 2 else minf(passo, (size.x - carta.size.x * escala_repouso - 40.0) / (n - 1))
		var pe = Vector2(size.x / 2.0 + d * passo_real, size.y + carta.size.y * escala_repouso - altura_visivel + queda_pontas * d * d)
		repouso[carta] = [pe, deg_to_rad(graus_por_carta * d)]
		mover(carta, false)

# a carta vai pra pose de repouso, ou de levantada se estiver com o mouse em cima
func mover(carta: Control, animar: bool = true) -> void:
	var pe: Vector2 = repouso[carta][0]
	var escala = escala_repouso
	var giro: float = repouso[carta][1]
	if carta == hover:
		var meia = carta.size.x * escala_hover / 2.0
		pe = Vector2(clampf(pe.x, meia, size.x - meia), size.y - folga_baixo)
		escala = escala_hover
		giro = 0.0
	var posicao = pe - carta.pivot_offset
	if tweens.has(carta):
		tweens[carta].kill()
	if not animar:
		carta.z_index = 5 if carta == hover else 0
		carta.position = posicao
		carta.scale = Vector2.ONE * escala
		carta.rotation = giro
		return
	var tween = create_tween().set_parallel().set_ignore_time_scale().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(carta, "position", posicao, tempo_subida)
	tween.tween_property(carta, "scale", Vector2.ONE * escala, tempo_subida)
	tween.tween_property(carta, "rotation", giro, tempo_subida)
	# volta pra trás das outras só depois de descer
	tween.chain().tween_callback(func(): carta.z_index = 5 if carta == hover else 0)
	tweens[carta] = tween

func escolher(nova: Control) -> void:
	if nova == hover:
		return
	var antes = hover
	hover = nova
	# o clique só acha a levantada: o Godot ordena o mouse pela árvore e ignora o z_index
	for carta in get_children():
		carta.mouse_filter = Control.MOUSE_FILTER_IGNORE if nova and carta != nova else Control.MOUSE_FILTER_STOP
	if antes:
		mover(antes)
	if nova:
		nova.z_index = 5
		mover(nova)

func sob_mouse(carta: Control, pos: Vector2) -> bool:
	var local = carta.get_global_transform().affine_inverse() * pos
	# a levantada vale até o fim da tela, senão a faixa embaixo dela fica piscando
	var extra = 60.0 if carta == hover else 0.0
	return Rect2(Vector2.ZERO, carta.size + Vector2(0, extra)).has_point(local)

func carta_em(pos: Vector2) -> Control:
	if hover and sob_mouse(hover, pos):
		return hover
	var cartas = get_children()
	cartas.reverse()
	for carta in cartas:
		if sob_mouse(carta, pos):
			return carta
	return null

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not get_viewport().gui_is_dragging():
		escolher(carta_em(event.position))

# arrastando, todas voltam pra repouso
func _process(_delta: float) -> void:
	if hover and get_viewport().gui_is_dragging():
		escolher(null)
	atualizar_tempo()

# o tempo desliza pra lento enquanto uma carta daqui está sendo arrastada, e volta ao soltar ou cancelar
func atualizar_tempo() -> void:
	var viewport = get_viewport()
	var carta = viewport.gui_get_drag_data()
	var arrastando = viewport.gui_is_dragging() and is_instance_valid(carta) and carta.get_parent() == self
	if arrastando == lento:
		return
	lento = arrastando
	GameManager.mudar_tempo(tempo_lento if arrastando else 1.0, 0.15 if arrastando else 0.1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		escolher(null)
	# soltar ou cancelar (Esc, botão direito) volta o tempo na hora, mesmo se o jogo estiver pausado
	elif what == NOTIFICATION_DRAG_END:
		atualizar_tempo()

# saiu da casa com uma carta na mão: o tempo volta ao normal
func _exit_tree() -> void:
	if lento:
		GameManager.tempo_normal()
