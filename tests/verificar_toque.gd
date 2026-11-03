extends SceneTree

# controles de celular, simulando o que o Godot manda (o toque do dedo 0 vira mouse antes do próprio toque):
# pinça dá zoom, um dedo arrasta o mapa, tocar sem arrastar abre a lore, o ímã escolhe o lugar no soltar,
# tocar numa carta levanta ela e o botão II pausa.
# godot --headless --path . --fixed-fps 60 --script res://tests/verificar_toque.gd

var falhas: int = 0
var house

func _initialize() -> void:
	call_deferred("verificar")

func exigir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error(mensagem)
		falhas += 1

# os toques entram pelo Input, em pixels da janela, como no aparelho: o próprio Godot transforma o
# primeiro dedo em mouse (emulate_mouse_from_touch) e a janela converte pra coordenadas da vista
func janela(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos

func mandar(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func toque(indice: int, pos: Vector2, apertado: bool) -> void:
	var ev = InputEventScreenTouch.new()
	ev.index = indice
	ev.position = janela(pos)
	ev.pressed = apertado
	mandar(ev)

func arrastar(indice: int, de: Vector2, para: Vector2) -> void:
	var ev = InputEventScreenDrag.new()
	ev.index = indice
	ev.position = janela(para)
	ev.relative = janela(para) - janela(de)
	mandar(ev)

func tocar(pos: Vector2) -> void:
	toque(0, pos, true)
	toque(0, pos, false)

func verificar() -> void:
	await process_frame
	var gm = root.get_node("GameManager")
	gm.toque = true
	house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame
	house.tutorial.terminar()
	await process_frame
	var cam = house.camera
	var area = house.ui.get_node("area_jogo")
	var lore = house.get_node("lore")

	# pinça: os dedos se afastam, o zoom aumenta
	var zoom_antes = cam.zoom_alvo
	toque(0, Vector2(700, 900), true)
	toque(1, Vector2(1000, 900), true)
	for i in 6:
		arrastar(1, Vector2(1000 + i * 40, 900), Vector2(1040 + i * 40, 900))
	toque(1, Vector2(1240, 900), false)
	toque(0, Vector2(700, 900), false)
	await process_frame
	exigir(cam.zoom_alvo > zoom_antes + 0.1, "Pinça não deu zoom (%s -> %s)" % [zoom_antes, cam.zoom_alvo])
	exigir(cam.dedos.is_empty(), "Dedos ficaram presos na câmera")
	exigir(not lore.aberto, "Pinça abriu a lore")

	# um dedo arrastando no vazio move a câmera e não abre nada
	var arrastado_antes = cam.arrastado
	toque(0, Vector2(900, 1300), true)
	for i in 5:
		arrastar(0, Vector2(900 + i * 30, 1300), Vector2(930 + i * 30, 1300))
	toque(0, Vector2(1050, 1300), false)
	await process_frame
	exigir(cam.arrastado - arrastado_antes > 100.0, "Arrastar com um dedo não moveu o mapa")
	exigir(not lore.aberto, "Arrastar o mapa abriu a lore")

	# tocar (sem arrastar) num npc abre a lore dele
	var npc = get_nodes_in_group("npc")[0]
	var ponto = Vector2(600, 700)
	var mundo = house.get_canvas_transform().affine_inverse() * ponto
	npc.global_position += mundo - (npc.sprite.global_position + npc.sprite.offset * npc.sprite.global_scale)
	# (vaso embaixo do dedo é levantado em vez de abrir a lore: aqui eles saem do caminho)
	for vaso in get_nodes_in_group("levitavel"):
		vaso.set_process_input(false)
	tocar(ponto)
	await process_frame
	exigir(lore.aberto and lore.npc == npc, "Tocar no npc não abriu a lore")
	lore.fechar()
	for vaso in get_nodes_in_group("levitavel"):
		vaso.set_process_input(true)
	await create_timer(0.5).timeout

	# ímã: o toque que escolhe o convidado não solta ele no lugar; o lugar vale no soltar
	var poder = house.ui.poder
	poder.comecar()
	await process_frame
	npc = get_nodes_in_group("npc")[1]
	mundo = house.get_canvas_transform().affine_inverse() * ponto
	npc.global_position += mundo - (npc.sprite.global_position + npc.sprite.offset * npc.sprite.global_scale)
	tocar(ponto)
	await process_frame
	exigir(poder.ativo() and poder.escolhido == npc, "Ímã não escolheu o convidado tocado")
	var lugar = house.get_canvas_transform() * npc.global_position
	toque(0, lugar, true)
	area._process(0.0)
	exigir(poder.ativo(), "Ímã soltou o convidado no apertar")
	toque(0, lugar, false)
	await process_frame
	exigir(not poder.ativo() and poder.restante > 0.0, "Ímã não usou o poder no soltar (no_mapa_ok=%s)" % poder.no_mapa_ok)

	# tocar numa carta levanta ela; tocar fora abaixa
	var lista = house.ui.get_node("painel_fantasmas/lista")
	var carta = lista.get_child(lista.get_child_count() / 2)
	var na_carta = carta.get_global_transform() * Vector2(carta.size.x / 2.0, 30.0)
	tocar(na_carta)
	exigir(lista.hover == carta, "Tocar na carta não levantou ela")
	tocar(Vector2(900, 500))
	exigir(lista.hover == null, "Tocar fora não abaixou a carta")

	# o botão II pausa
	var pausar: Button = null
	for filho in house.ui.get_children():
		if filho is Button and filho.text == "II":
			pausar = filho
	exigir(pausar != null, "Sem botão de pausa no celular")
	if pausar:
		pausar.pressed.emit()
		exigir(paused, "Botão II não pausou")
		house.get_node("pausa").despausar()

	# a partida usa a interface 1,5x maior; o menu volta ao desenho original, com faixas
	gm.ajustar_tela(house)
	exigir(root.content_scale_factor == gm.ESCALA_CELULAR and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Partida sem a escala do celular")
	var menu = load("res://scene/menu.tscn").instantiate()
	root.add_child(menu)
	gm.ajustar_tela(menu)
	exigir(root.content_scale_factor == 1.0 and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Menu com a escala da partida")

	if falhas == 0:
		print("verificar_toque: ok")
	quit(falhas)
