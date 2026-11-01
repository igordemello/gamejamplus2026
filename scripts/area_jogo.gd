extends Control

const INVOCACAO = preload("res://scene/invocacao.tscn")

@onready var menu_acoes = $"../menu_acoes"

# clicar e segurar num fantasma abre o menu de ações, soltar executa a que estiver no mouse
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		for fantasma in get_tree().get_nodes_in_group("fantasma"):
			if fantasma.mouse_em_cima():
				menu_acoes.abrir(fantasma, event.global_position)
				return
	else:
		menu_acoes.soltar()

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
