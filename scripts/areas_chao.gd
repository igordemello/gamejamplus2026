extends Node2D

# desenhado no chão, por baixo de todo mundo: o alcance das ações do fantasma (de leve) e,
# arrastando uma carta, os lugares onde ela pode cair. a casa cria isso em efeitos_chao

const SEM_LUZ = preload("res://assets/sem_luz.tres")
# tamanho de cada quadradinho do lugar onde a carta pode cair
const CELULA = 24.0

var area_jogo: Control
var menu_acoes: Control
var tempo: float = 0.0
var mostrando: bool = false
# [área, força]
var areas: Array = []
# os quadradinhos só são desenhados uma vez por carta; depois só o alfa pulsa
var carta_atual: Variant = null
var celulas: PackedVector2Array = PackedVector2Array()
var no_celulas: Node2D

func _ready() -> void:
	material = SEM_LUZ
	var ui = GameManager.house.ui
	area_jogo = ui.get_node("area_jogo")
	menu_acoes = ui.get_node("menu_acoes")
	no_celulas = Node2D.new()
	no_celulas.material = SEM_LUZ
	no_celulas.use_parent_material = false
	no_celulas.draw.connect(desenhar_celulas)
	no_celulas.hide()
	add_child(no_celulas)

func _process(delta: float) -> void:
	tempo += minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	atualizar_carta()
	areas = areas_de_agora()
	if not areas.is_empty() or mostrando:
		queue_redraw()
	mostrando = not areas.is_empty()

func atualizar_carta() -> void:
	var viewport = get_viewport()
	var carta = viewport.gui_get_drag_data() if viewport.gui_is_dragging() else null
	if not (is_instance_valid(carta) and carta.get("cena") != null):
		carta = null
	# escolhendo pra onde mover: os mesmos quadradinhos, pela regra do próprio fantasma
	var movendo = area_jogo.mira_fantasma
	if is_instance_valid(movendo) and area_jogo.mira_acao == movendo.acao_mover:
		carta = movendo
	if carta != carta_atual:
		carta_atual = carta
		no_celulas.visible = carta != null
		if carta:
			calcular_celulas(carta)
			no_celulas.queue_redraw()
			# carta que só cabe lá fora: mostra o lado de fora pra dar onde soltar
			if carta.fora_de_casa and not carta is Fantasma:
				GameManager.house.camera.mostrar_exterior()
	if carta:
		no_celulas.modulate.a = 0.75 + 0.25 * sin(tempo * 5.0)

# o mapa inteiro em quadradinhos, pela mesma regra de quem deixa soltar a carta
func calcular_celulas(carta: Variant) -> void:
	celulas = PackedVector2Array()
	var chao: Sprite2D = GameManager.house.chao
	var limite = chao.get_global_transform() * chao.get_rect()
	var y = limite.position.y - 200.0
	while y < limite.end.y + 200.0:
		var x = limite.position.x - 200.0
		while x < limite.end.x + 200.0:
			if area_jogo.pode_soltar_em(carta, Vector2(x, y) + Vector2.ONE * CELULA / 2.0):
				celulas.append(Vector2(x, y))
			x += CELULA
		y += CELULA

func desenhar_celulas() -> void:
	for canto in celulas:
		no_celulas.draw_rect(Rect2(canto + Vector2.ONE, Vector2.ONE * (CELULA - 2.0)), Color(1, 1, 1, 0.13))

# mirando: o alcance da mira. no menu: a ação escolhida, ou de leve todas. com o mouse em cima: de leve todas
func areas_de_agora() -> Array:
	if is_instance_valid(area_jogo.mira_fantasma):
		if area_jogo.mira_acao == area_jogo.mira_fantasma.acao_mover:
			return []
		return [[area_jogo.mira_fantasma.area_de(area_jogo.mira_acao), 1.0]]
	var fantasma = menu_acoes.fantasma
	if is_instance_valid(fantasma):
		var escolhida = menu_acoes.acao_na_bolinha()
		if escolhida == fantasma.acao_mover and escolhida != null:
			return []
		if escolhida:
			return [[fantasma.area_de(escolhida), 1.0]]
		return todas_de(fantasma, 0.5)
	if get_viewport().gui_is_dragging():
		return []
	for outro in get_tree().get_nodes_in_group("fantasma"):
		if outro.no_hover:
			return todas_de(outro, 0.5)
	return []

func todas_de(fantasma: Node, forca: float) -> Array:
	var lista = []
	for acao in fantasma.acoes:
		if acao != fantasma.acao_mover:
			lista.append([fantasma.area_de(acao), forca])
	return lista

func _draw() -> void:
	var pulso = 0.85 + 0.15 * sin(tempo * 3.0)
	for item in areas:
		var area: Dictionary = item[0]
		var forca: float = item[1] * pulso
		if area.has("raio"):
			draw_circle(area.centro, area.raio, Color(1, 1, 1, 0.05 * forca))
			draw_arc(area.centro, area.raio, 0.0, TAU, 96, Color(1, 1, 1, 0.3 * forca), 2.0)
		elif area.has("comodo"):
			desenhar_comodo(area.comodo, forca)

func desenhar_comodo(nome: String, forca: float) -> void:
	for regiao in GameManager.house.regionsHouse:
		if regiao.name == nome:
			var pontos = PackedVector2Array()
			for ponto in regiao.navigation_polygon.get_outline(0):
				pontos.append(regiao.to_global(ponto))
			draw_colored_polygon(pontos, Color(1, 1, 1, 0.05 * forca))
			pontos.append(pontos[0])
			draw_polyline(pontos, Color(1, 1, 1, 0.3 * forca), 2.0)
