extends Control

const INVOCACAO = preload("res://scene/invocacao.tscn")

@onready var menu_acoes = $"../menu_acoes"
@onready var lore = $"../../lore"

# ação com mira esperando o clique no mapa
var mira_fantasma: Fantasma
var mira_acao: Acao
var mira_ok: bool = false
# o clique da mira começou nela (o soltar do menu de ações que abriu a mira não conta)
var mira_apertou: bool = false

# apertou no mapa: arrastar mais que ARRASTO_MINIMO move a câmera, menos que isso é clique (abre a lore)
const ARRASTO_MINIMO = 14.0
var arrastando_mapa: bool = false
var arrastou: float = 0.0
var npc_tocado: Npc

# o anel no chão aparece no npc que o clique abriria: nenhum com fantasma embaixo, carta sendo arrastada,
# menu de ações aberto ou outro controle (loja, painel de lore) por cima do mouse
func _process(_delta: float) -> void:
	var viewport = get_viewport()
	if mira_fantasma != null:
		processar_mira()
		return
	var poder = GameManager.house.ui.poder
	if poder.ativo():
		poder.processar(self)
		queue_redraw()
		return
	var sobre = viewport.gui_get_hovered_control()
	var alvo: Npc = null
	if GameManager.hover_valido() and not (viewport.gui_is_dragging() or menu_acoes.visible or (sobre != null and sobre != self) or fantasma_sob_mouse()):
		alvo = npc_sob_mouse()
	# o que já está aberto na lore não precisa
	if alvo == lore.npc:
		alvo = null
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.em_destaque = npc == alvo
	var levitavel = get_tree().get_nodes_in_group("levitavel").any(func(o): return o.mouse_em_cima())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if alvo or levitavel else Control.CURSOR_ARROW

# clicar e segurar num fantasma abre o menu de ações, soltar executa a que estiver no mouse;
# clicar num npc (sem fantasma na frente) abre a lore dele; arrastar no vazio move o mapa (um dedo, no celular)
func _gui_input(event: InputEvent) -> void:
	var poder = GameManager.house.ui.poder
	if poder.ativo():
		if event is InputEventMouseButton:
			poder.clique_no_mapa(event, self)
			accept_event()
		return
	if mira_fantasma != null:
		# a mira segue o dedo enquanto ele está na tela e vale onde ele sai
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					mira_apertou = true
				elif mira_apertou:
					confirmar_mira()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				terminar_mira()
			accept_event()
		return
	if event is InputEventMouseMotion:
		if arrastando_mapa and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# dois dedos é a pinça da câmera: nem arrasta nem conta como toque
			if GameManager.house.camera.dedos.size() > 1:
				arrastou = INF
			elif arrastou < INF:
				arrastou += event.relative.length()
				if arrastou > ARRASTO_MINIMO:
					GameManager.house.camera.arrastar(event.relative)
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		var fantasma = fantasma_sob_mouse()
		if fantasma:
			lore.fechar(false)
			menu_acoes.abrir(fantasma, event.global_position)
			return
		npc_tocado = npc_sob_mouse()
		arrastou = 0.0
		arrastando_mapa = not get_tree().get_nodes_in_group("levitavel").any(func(o): return o.segurando)
	else:
		menu_acoes.soltar()
		# soltou sem arrastar: foi um clique no npc
		if arrastando_mapa and arrastou <= ARRASTO_MINIMO and is_instance_valid(npc_tocado) and npc_tocado.is_in_group("npc"):
			lore.abrir(npc_tocado)
		arrastando_mapa = false
		npc_tocado = null

func fantasma_sob_mouse() -> Fantasma:
	for fantasma in get_tree().get_nodes_in_group("fantasma"):
		if fantasma.mouse_em_cima():
			return fantasma
	return null

# o npc embaixo do mouse; se tem vários, o que tem o meio do desenho mais perto do mouse:
# assim dá pra pegar qualquer um de um grupo mirando nele, não só o que está na frente
func npc_sob_mouse() -> Npc:
	var mouse = GameManager.house.get_global_mouse_position()
	var melhor: Npc = null
	var menor = INF
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.current_estado == Npc.Estado.Infarta or not npc.mouse_em_cima():
			continue
		var distancia = mouse.distance_to(npc.sprite.global_position + npc.sprite.offset * npc.sprite.global_scale)
		if distancia < menor:
			menor = distancia
			melhor = npc
	return melhor

# ---------- mira
func comecar_mira(fantasma: Fantasma, acao: Acao) -> void:
	mira_fantasma = fantasma
	mira_acao = acao
	mira_apertou = false
	GameManager.house.mirando = true
	GameManager.mudar_tempo(menu_acoes.tempo_lento, 0.15)
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.em_destaque = false

func terminar_mira() -> void:
	mira_fantasma = null
	mira_acao = null
	GameManager.house.mirando = false
	GameManager.mudar_tempo(1.0, 0.1)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func processar_mira() -> void:
	if not is_instance_valid(mira_fantasma) or get_viewport().gui_is_dragging():
		terminar_mira()
		return
	mira_ok = mira_fantasma.mira_valida(mira_acao, GameManager.house.get_global_mouse_position())
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	queue_redraw()

func confirmar_mira() -> void:
	var onde = GameManager.house.get_global_mouse_position()
	if not mira_fantasma.mira_valida(mira_acao, onde):
		mira_fantasma.negar()
		return
	var quem = mira_fantasma
	var acao = mira_acao
	terminar_mira()
	quem.executar_mira(acao, onde)

# Esc cancela a mira sem abrir a pausa
func _input(event: InputEvent) -> void:
	if mira_fantasma != null and event.is_action_pressed("ui_cancel"):
		terminar_mira()
		get_viewport().set_input_as_handled()
	elif GameManager.house.ui.poder.ativo() and event.is_action_pressed("ui_cancel"):
		GameManager.house.ui.poder.cancelar()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var poder = GameManager.house.ui.poder
	if poder.ativo():
		desenhar_mira(poder.dica(), poder.no_mapa_ok)
		return
	if mira_fantasma == null:
		return
	desenhar_mira(("Solte" if GameManager.toque else "Clique") + " pra escolher o lugar" if mira_ok else "Aqui não dá", mira_ok)

func desenhar_mira(texto: String, valido: bool) -> void:
	var mouse = get_local_mouse_position()
	var cor = Color(1, 1, 1, 0.9) if valido else Color(1, 0.35, 0.35, 0.8)
	# o dedo tampa a mira: no celular o anel é maior que ele
	var raio = 60.0 if GameManager.toque else 26.0
	draw_arc(mouse, raio, 0.0, TAU, 40, cor, 3.0, true)
	draw_circle(mouse, 4.0, cor)
	draw_string(get_theme_default_font(), mouse + Vector2(raio + 10, 8), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cor)

func _can_drop_data(_at_position: Vector2, card: Variant) -> bool:
	var pode = pode_soltar(card)
	if is_instance_valid(card.preview):
		card.preview.modulate = Color(1, 1, 1, 0.9) if pode else Color(1, 0.35, 0.35, 0.6)
	return pode

func pode_soltar(card: Variant) -> bool:
	return pode_soltar_em(card, GameManager.house.get_global_mouse_position())

func pode_soltar_em(card: Variant, pos: Vector2) -> bool:
	if card.pontos_spawn != &"":
		return ponto_livre_perto(card.pontos_spawn, pos) != null
	var house = GameManager.house
	if card.fora_de_casa:
		return house.fora_de_casa(pos)
	if house.eh_parede(pos) or house.comodo_proibido(pos, card.comodos_proibidos):
		return false
	# o cômodo vale como prefixo: "quarto" pega quarto, quarto2...
	return card.comodo_spawn == "" or house.comodo_em(pos).begins_with(card.comodo_spawn)

# o fantasma não aparece na hora: sai de um pentagrama que se desenha no chão (invocacao.gd)
func _drop_data(_at_position: Vector2, card: Variant) -> void:
	card.comprou()
	var fantasma: Fantasma = card.cena.instantiate()
	var ponto = ponto_livre_perto(card.pontos_spawn) if card.pontos_spawn != &"" else null
	var invocacao = INVOCACAO.instantiate()
	invocacao.fantasma = fantasma
	if ponto:
		# o ponto já fica ocupado durante a invocação
		ponto.ocupante = fantasma
		invocacao.position = ponto.global_position
	else:
		invocacao.position = GameManager.house.get_global_mouse_position()
	GameManager.house.efeitos_chao.add_child(invocacao)

# ponto livre do grupo mais perto do mouse, se tiver algum perto o bastante
func ponto_livre_perto(grupo: StringName, mouse: Vector2 = GameManager.house.get_global_mouse_position()) -> Node2D:
	var mais_perto: Node2D = null
	for ponto in get_tree().get_nodes_in_group(grupo):
		var distancia = ponto.global_position.distance_to(mouse)
		if ponto.livre() and distancia <= ponto.raio and (mais_perto == null or distancia < mais_perto.global_position.distance_to(mouse)):
			mais_perto = ponto
	return mais_perto
