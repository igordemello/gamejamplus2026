extends SceneTree

# Joga uma partida inteira sem mouse: compra todas as cartas, usa todas as ações algumas vezes,
# levita um objeto, abre a lore de um convidado, amanhece e espera a tela de fim.
# Serve pra pegar erro de script depois de mexer no código (procure "SCRIPT ERROR" na saída).
#   godot --headless --path . --fixed-fps 60 --script res://tests/verificar_partida.gd

const FASE = "res://scene/fases/casa/casa.tscn"

var falhas: int = 0

func _initialize() -> void:
	call_deferred("rodar")

func exigir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error(mensagem)
		falhas += 1

# primeiro ponto do mapa onde essa carta pode cair
func achar_lugar(area, card) -> Variant:
	if card.pontos_spawn != &"":
		for ponto in get_nodes_in_group(card.pontos_spawn):
			if ponto.livre():
				return ponto.global_position
		return null
	for z in range(-12, 50):
		for x in range(-16, 60):
			var p = Vector3(x * 0.5, 0.0, z * 0.5)
			if area.pode_soltar_em(card, p):
				return p
	return null

# deixa o ponto p embaixo do mouse (que no headless fica parado no canto da tela)
func mouse_em(fase, p: Vector3) -> void:
	var cam = fase.camera
	cam.alvo += p - cam.mouse_no_chao()
	cam.atualizar()

func rodar() -> void:
	await process_frame
	var fase = load(FASE).instantiate()
	root.add_child(fase)
	await process_frame
	fase.tutorial.terminar()
	fase.camera.limite = Rect2(-200, -200, 400, 400)
	var gm = root.get_node("GameManager")
	gm.sustos = 500
	gm.mortes = 2
	await process_frame

	var area = fase.ui.get_node("area_jogo")
	var cartas = fase.ui.get_node("painel_fantasmas/lista").get_children()
	for card in cartas:
		var p = achar_lugar(area, card)
		exigir(p != null, "sem lugar pra soltar %s" % card.name)
		if p == null:
			continue
		mouse_em(fase, p)
		await process_frame
		mouse_em(fase, p)
		area._drop_data(Vector2.ZERO, card)
	await create_timer(2.0).timeout
	var fantasmas = get_nodes_in_group("fantasma")
	exigir(fantasmas.size() == cartas.size(), "invocou %d de %d fantasmas" % [fantasmas.size(), cartas.size()])

	for rodada in 3:
		for f in fantasmas:
			for acao in f.acoes:
				if acao.mira:
					f.executar_mira(acao, f.global_position + Vector3(0.5, 0.0, 0.0))
				else:
					f.executar(acao)
		await create_timer(8.0).timeout

	var levitavel = get_first_node_in_group("levitavel")
	exigir(levitavel != null, "nenhum objeto levitável na fase")
	if levitavel:
		levitavel.levantar()
		await create_timer(3.0).timeout
		levitavel.soltar()

	var npcs = get_nodes_in_group("npc")
	if not npcs.is_empty():
		fase.lore.abrir(npcs[0])
		await create_timer(1.0).timeout
		fase.lore.fechar()

	fase.amanhecer()
	var espera = 0.0
	while not fase.acabou and espera < 180.0:
		await create_timer(1.0).timeout
		espera += 1.0
	exigir(fase.acabou, "a partida não acabou depois de amanhecer")
	await create_timer(3.0).timeout

	if falhas == 0:
		print("OK: partida inteira rodou (%d fantasmas, %d mortes)." % [fantasmas.size(), gm.mortes])
	fase.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
