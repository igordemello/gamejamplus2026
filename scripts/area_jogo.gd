extends Control

const INVOCACAO = preload("res://scene/invocacao.tscn")

@onready var menu_acoes = $"../menu_acoes"
@onready var lore = $"../../lore"

# o anel no chão aparece no npc que o clique abriria: nenhum com fantasma embaixo, carta sendo arrastada,
# menu de ações aberto ou outro controle (loja, painel de lore) por cima do mouse
func _process(_delta: float) -> void:
	var viewport = get_viewport()
	var sobre = viewport.gui_get_hovered_control()
	var alvo: Npc = null
	if not (viewport.gui_is_dragging() or menu_acoes.visible or (sobre != null and sobre != self) or fantasma_sob_mouse()):
		alvo = npc_sob_mouse()
	# o que já está aberto na lore não precisa
	if alvo == lore.npc:
		alvo = null
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.em_destaque = npc == alvo
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if alvo else Control.CURSOR_ARROW

# clicar e segurar num fantasma abre o menu de ações, soltar executa a que estiver no mouse;
# clicar num npc (sem fantasma na frente) abre a lore dele
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		var fantasma = fantasma_sob_mouse()
		if fantasma:
			lore.fechar(false)
			menu_acoes.abrir(fantasma, event.global_position)
			return
		var npc = npc_sob_mouse()
		if npc:
			lore.abrir(npc)
	else:
		menu_acoes.soltar()

func fantasma_sob_mouse() -> Fantasma:
	for fantasma in get_tree().get_nodes_in_group("fantasma"):
		if fantasma.mouse_em_cima():
			return fantasma
	return null

# o npc embaixo do mouse; se tem vários, o da frente (o mais embaixo na tela)
func npc_sob_mouse() -> Npc:
	var da_frente: Npc = null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.current_estado != Npc.Estado.Infarta and npc.mouse_em_cima() and (da_frente == null or npc.global_position.y > da_frente.global_position.y):
			da_frente = npc
	return da_frente

func _can_drop_data(_at_position: Vector2, card: Variant) -> bool:
	var pode = pode_soltar(card)
	if is_instance_valid(card.preview):
		card.preview.modulate = Color(1, 1, 1, 0.9) if pode else Color(1, 0.35, 0.35, 0.6)
	return pode

func pode_soltar(card: Variant) -> bool:
	if card.pontos_spawn != &"":
		return ponto_livre_perto(card.pontos_spawn) != null
	var house = GameManager.house
	var pos = house.get_global_mouse_position()
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
func ponto_livre_perto(grupo: StringName) -> Node2D:
	var mouse = GameManager.house.get_global_mouse_position()
	var mais_perto: Node2D = null
	for ponto in get_tree().get_nodes_in_group(grupo):
		var distancia = ponto.global_position.distance_to(mouse)
		if ponto.livre() and distancia <= ponto.raio and (mais_perto == null or distancia < mais_perto.global_position.distance_to(mouse)):
			mais_perto = ponto
	return mais_perto
