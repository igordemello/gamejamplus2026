extends Control

# tela inteira por baixo da UI: clique em fantasma/npc, mira, soltar carta (invocação)

const INVOCACAO = preload("res://scene/efeitos/invocacao.tscn")

@onready var menu_acoes = $"../menu_acoes"

# ação com mira esperando o clique no mapa
var mira_fantasma: Fantasma
var mira_acao: Acao
var mira_ok: bool = false

# o anel no chão aparece no npc que o clique abriria: nenhum com fantasma embaixo, carta sendo arrastada,
# menu de ações aberto ou outro controle (loja, painel de lore) por cima do mouse
func _process(_delta: float) -> void:
	var viewport = get_viewport()
	if mira_fantasma != null:
		processar_mira()
		return
	var poder = GameManager.fase.ui.poder
	if poder.ativo():
		poder.processar(self)
		queue_redraw()
		return
	var sobre = viewport.gui_get_hovered_control()
	var alvo: Npc = null
	if not (viewport.gui_is_dragging() or menu_acoes.visible or (sobre != null and sobre != self) or fantasma_sob_mouse()):
		alvo = npc_sob_mouse()
	# o que já está aberto na lore não precisa
	if alvo == GameManager.fase.lore.npc:
		alvo = null
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.em_destaque = npc == alvo
	var levitavel = get_tree().get_nodes_in_group("levitavel").any(func(o): return o.mouse_em_cima())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if alvo or levitavel else Control.CURSOR_ARROW

# clicar e segurar num fantasma abre o menu de ações, soltar executa a que estiver no mouse;
# clicar num npc (sem fantasma na frente) abre a lore dele
func _gui_input(event: InputEvent) -> void:
	var poder = GameManager.fase.ui.poder
	if poder.ativo():
		if event is InputEventMouseButton and event.pressed:
			poder.clique_no_mapa(event, self)
			accept_event()
		return
	if mira_fantasma != null:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				confirmar_mira()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				terminar_mira()
			accept_event()
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		var fantasma = fantasma_sob_mouse()
		if fantasma:
			GameManager.fase.lore.fechar(false)
			menu_acoes.abrir(fantasma, GameManager.fase.centro_na_tela(fantasma.sprite))
			return
		var npc = npc_sob_mouse()
		if npc:
			GameManager.fase.lore.abrir(npc)
	else:
		menu_acoes.soltar()

func fantasma_sob_mouse() -> Fantasma:
	for fantasma in get_tree().get_nodes_in_group("fantasma"):
		if fantasma.mouse_em_cima():
			return fantasma
	return null

# o npc embaixo do mouse; se tem vários, o que tem o meio do desenho mais perto do mouse:
# assim dá pra pegar qualquer um de um grupo mirando nele, não só o que está na frente
func npc_sob_mouse() -> Npc:
	var fase = GameManager.fase
	var melhor: Npc = null
	var menor = INF
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.current_estado == Npc.Estado.Infarta or not npc.mouse_em_cima():
			continue
		var distancia = fase.centro_na_tela(npc.sprite).distance_to(get_viewport().get_mouse_position())
		if distancia < menor:
			menor = distancia
			melhor = npc
	return melhor

# ---------- mira
func comecar_mira(fantasma: Fantasma, acao: Acao) -> void:
	mira_fantasma = fantasma
	mira_acao = acao
	GameManager.fase.mirando = true
	GameManager.mudar_tempo(menu_acoes.tempo_lento, 0.15)
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.em_destaque = false

func terminar_mira() -> void:
	mira_fantasma = null
	mira_acao = null
	GameManager.fase.mirando = false
	GameManager.mudar_tempo(1.0, 0.1)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func processar_mira() -> void:
	if not is_instance_valid(mira_fantasma) or get_viewport().gui_is_dragging():
		terminar_mira()
		return
	mira_ok = mira_fantasma.mira_valida(mira_acao, GameManager.fase.mouse_no_chao())
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	queue_redraw()

func confirmar_mira() -> void:
	var onde = GameManager.fase.mouse_no_chao()
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
	elif GameManager.fase.ui.poder.ativo() and event.is_action_pressed("ui_cancel"):
		GameManager.fase.ui.poder.cancelar()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var poder = GameManager.fase.ui.poder
	if poder.ativo():
		desenhar_mira(poder.dica(), poder.no_mapa_ok)
		return
	if mira_fantasma == null:
		return
	desenhar_mira("Clique pra escolher o lugar" if mira_ok else "Aqui não dá", mira_ok)

func desenhar_mira(texto: String, valido: bool) -> void:
	var mouse = get_local_mouse_position()
	var cor = Color(1, 1, 1, 0.9) if valido else Color(1, 0.35, 0.35, 0.8)
	draw_arc(mouse, 26.0, 0.0, TAU, 40, cor, 3.0, true)
	draw_circle(mouse, 4.0, cor)
	draw_string(get_theme_default_font(), mouse + Vector2(36, 8), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cor)

func _can_drop_data(_at_position: Vector2, card: Variant) -> bool:
	var pode = pode_soltar(card)
	if is_instance_valid(card.preview):
		card.preview.modulate = Color(1, 1, 1, 0.9) if pode else Color(1, 0.35, 0.35, 0.6)
	return pode

func pode_soltar(card: Variant) -> bool:
	return pode_soltar_em(card, GameManager.fase.mouse_no_chao())

func pode_soltar_em(card: Variant, pos: Vector3) -> bool:
	if card.pontos_spawn != &"":
		return ponto_livre_perto(card.pontos_spawn, pos) != null
	var fase = GameManager.fase
	if card.fora_de_casa:
		return fase.fora_de_casa(pos)
	if fase.eh_parede(pos) or fase.comodo_proibido(pos, card.comodos_proibidos):
		return false
	# o cômodo vale como prefixo: "quarto" pega quarto, quarto2...
	return card.comodo_spawn == "" or fase.comodo_em(pos).begins_with(card.comodo_spawn)

# o fantasma não aparece na hora: sai de um pentagrama que se desenha no chão (invocacao.gd)
func _drop_data(_at_position: Vector2, card: Variant) -> void:
	card.comprou()
	var fantasma: Fantasma = card.cena.instantiate()
	var ponto = ponto_livre_perto(card.pontos_spawn) if card.pontos_spawn != &"" else null
	var invocacao = INVOCACAO.instantiate()
	invocacao.fantasma = fantasma
	GameManager.fase.mundo.add_child(invocacao)
	if ponto:
		# o ponto já fica ocupado durante a invocação
		ponto.ocupante = fantasma
		invocacao.global_position = ponto.global_position
	else:
		invocacao.global_position = GameManager.fase.mouse_no_chao()

# ponto livre do grupo mais perto do mouse, se tiver algum perto o bastante
func ponto_livre_perto(grupo: StringName, mouse: Vector3 = GameManager.fase.mouse_no_chao()) -> Node3D:
	var mais_perto: Node3D = null
	for ponto in get_tree().get_nodes_in_group(grupo):
		var distancia = ponto.global_position.distance_to(mouse)
		if ponto.livre() and distancia <= ponto.raio and (mais_perto == null or distancia < mais_perto.global_position.distance_to(mouse)):
			mais_perto = ponto
	return mais_perto
