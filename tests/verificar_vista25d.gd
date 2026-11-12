extends SceneTree

# A vista 2.5D precisa cair na tela exatamente onde o 2D desenharia (senão mouse, hover e UI do mundo
# saem do lugar). Projeta pela Camera3D e compara com a canvas_transform da Camera2D, em vários zooms,
# posições e com tremida; e confere os quads dos personagens contra o desenho 2D deles.
#   godot --headless --path . --fixed-fps 60 --script res://tests/verificar_vista25d.gd

const V = preload("res://scripts/vista3d.gd")

var falhas: int = 0

func _initialize() -> void:
	call_deferred("verificar")

func exigir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error(mensagem)
		falhas += 1

func verificar() -> void:
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame
	house.tutorial.terminar()
	var mundo = house.get_node("mundo3d")
	var cam2d = house.camera
	var cam3d: Camera3D = mundo.camera
	# no tamanho do 2D os billboards têm que cair em cima do desenho 2D
	var escala = mundo.escala_billboard
	mundo.escala_billboard = 1.0
	exigir(V.para_2d(V.chao(Vector2(123, 456), 37.0)).distance_to(Vector2(123, 419)) < 0.01, "chao/para_2d não são inversos")

	for caso in [[0.8, Vector2(960, 620)], [1.5, Vector2(400, 300)], [0.62, Vector2(960, 540)], [1.2, Vector2(1500, 900)]]:
		cam2d.zoom_alvo = caso[0]
		cam2d.zoom_atual = caso[0]
		cam2d.zoom = Vector2.ONE * caso[0]
		cam2d.position = cam2d.limitar(caso[1], caso[0])
		cam2d.tremer(10.0)
		await process_frame
		await process_frame
		var xf = root.canvas_transform
		var pior = 0.0
		for p in [Vector2(300, 200), Vector2(960, 600), Vector2(1600, 1100), Vector2(cam2d.position.x, cam2d.position.y)]:
			for h in [0.0, 64.0, 120.0]:
				var esperado = xf * (p - Vector2(0, h))
				pior = maxf(pior, cam3d.unproject_position(V.chao(p, h)).distance_to(esperado))
		exigir(pior < 0.5, "câmera 3D desalinhada em zoom %s: %.2f px" % [caso[0], pior])

	# quads dos personagens: os cantos caem nos cantos do desenho 2D (o headless não desenha, então o
	# frame_pre_draw não vem: atualiza na mão, depois dos tweens, como o jogo faz antes de desenhar)
	await process_frame
	mundo.atualizar_sprites()
	var xf = root.canvas_transform
	var conferidos = 0
	for item in mundo.sprites:
		var dados = mundo.sprites[item]
		if not dados.malha.visible:
			continue
		var r: Rect2 = mundo.quadro_de(item).rect
		var g: Transform2D = item.get_global_transform()
		for canto in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var tela_3d = cam3d.unproject_position(dados.malha.global_transform * Vector3(canto.x, canto.y, 0.0))
			var tela_2d = xf * (g * (r.position + canto * r.size))
			exigir(tela_3d.distance_to(tela_2d) < 0.5, "quad de %s fora do desenho 2D: %.2f px" % [item.get_parent().name, tela_3d.distance_to(tela_2d)])
		conferidos += 1
	exigir(conferidos >= 9, "esperava os 9 convidados espelhados, achei %d" % conferidos)
	exigir(mundo.luzes.size() >= 10, "luzes 2D não viraram 3D (%d)" % mundo.luzes.size())
	exigir(house.chao.visibility_layer == V.CAMADA_OCULTA, "chão 2D continua sendo desenhado")
	exigir(root.canvas_cull_mask & V.CAMADA_OCULTA == 0, "viewport ainda desenha a camada oculta")

	mundo.escala_billboard = escala
	# câmera girada e inclinada: o mouse continua sendo o chão embaixo dele, o billboard fica virado pra câmera,
	# o hover acha o npc pelo desenho na tela e o que está em cima da cabeça fica em pé na tela
	for caso in [[0.7, 50.0], [-2.3, 30.0], [PI, 75.0]]:
		var giro = caso[0]
		mundo.giro = giro
		mundo.inclinacao = caso[1]
		await process_frame
		await process_frame
		var pior_chao = 0.0
		for p in [Vector2(300, 200), Vector2(960, 600), Vector2(1600, 1100)]:
			pior_chao = maxf(pior_chao, (root.canvas_transform * p).distance_to(cam3d.unproject_position(V.chao(p))))
		exigir(pior_chao < 0.5, "giro %.1f: chão 2D fora do chão 3D (%.2f px)" % [giro, pior_chao])
		var npc = house.get_tree().get_nodes_in_group("npc")[0]
		var malha: MeshInstance3D = mundo.sprites[npc.sprite].malha
		var normal = malha.transform.basis.z.normalized()
		exigir(normal.dot(cam3d.global_basis.z) > 0.99, "giro %.1f: billboard não está de frente pra câmera" % giro)
		var tela_x = cam3d.unproject_position(malha.transform * Vector3(1, 0, 0)).distance_to(cam3d.unproject_position(malha.transform.origin))
		var tela_y = cam3d.unproject_position(malha.transform * Vector3(0, 1, 0)).distance_to(cam3d.unproject_position(malha.transform.origin))
		# a respiração estica o desenho uns pixels: compara com a escala de agora
		var quadro = mundo.quadro_de(npc.sprite).rect.size * npc.sprite.get_global_transform().get_scale().abs()
		exigir(absf(tela_x / tela_y - quadro.x / quadro.y) < 0.01, "giro %.1f: billboard esticado (%.3f x %.3f)" % [giro, tela_x / tela_y, quadro.x / quadro.y])
		# leva o desenho do npc pra baixo do mouse (o mouse do headless não anda) e confere o hover
		var mouse = root.get_mouse_position()
		cam2d.position += mundo.tela_para_mundo(mundo.centro_na_tela(npc.sprite) - mouse) / cam2d.zoom.x
		await process_frame
		await process_frame
		exigir(npc.mouse_em_cima(), "giro %.1f: hover não acha o npc embaixo do mouse" % giro)
		exigir(house.get_global_mouse_position().distance_to(mundo.chao_sob_mouse()) < 0.5, "giro %.1f: get_global_mouse_position fora do chão sob o mouse" % giro)
		var pe = house.na_tela(npc, Vector2.ZERO)
		var cabeca = house.na_tela(npc, Vector2(0, npc.topo_desenho))
		exigir(absf(pe.x - cabeca.x) < 1.0 and cabeca.y < pe.y - 40.0, "giro %.1f: cabeça não fica em cima do pé na tela" % giro)
	mundo.giro = 0.0
	mundo.inclinacao = V.ANGULO
	await process_frame

	# F3 volta pro 2D e de novo pro 2.5D
	var f3 = InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	root.push_input(f3, true)
	await process_frame
	exigir(not mundo.vista_3d and root.canvas_cull_mask & V.CAMADA_OCULTA != 0 and not mundo.visible, "F3 não mostrou o 2D")
	root.push_input(f3, true)
	await process_frame
	exigir(mundo.vista_3d and mundo.visible, "F3 não voltou pro 2.5D")

	print("verificar_vista25d: ", "OK" if falhas == 0 else "%d falha(s)" % falhas)
	quit(falhas)
