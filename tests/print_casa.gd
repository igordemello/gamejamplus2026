extends SceneTree

# Tira um print da fase. Precisa de janela:
#   godot --path . --windowed --resolution 1920x1080 --script res://tests/print_casa.gd -- saida=C:/tmp/a.png
# Opções: saida=<png>  espera=<segundos de jogo>  x=<m> z=<m> (ponto que a câmera olha)  zoom=<z>  giro=<graus>
#   fantasmas=1 (um de cada perto do meio)  levitar=1 (segura o vaso)  assustar=1 (todo mundo leva um susto)
#   fps=1 (mede o FPS por 4 s)

var args: Dictionary = {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var partes = a.split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else "1"
	call_deferred("rodar")

func rodar() -> void:
	# janela minimizada não desenha: desiste em vez de ficar pendurado
	create_timer(float(args.get("espera", "2")) + 60.0, true, false, true).timeout.connect(func():
		push_error("print_casa: nenhum quadro desenhado")
		quit(1))
	await process_frame
	var fase = load("res://scene/fases/casa/casa.tscn").instantiate()
	root.add_child(fase)
	await process_frame
	fase.tutorial.terminar()
	var cam = fase.camera
	if args.has("giro"):
		cam.giro = deg_to_rad(float(args.giro))
	if args.has("zoom"):
		cam.zoom_alvo = float(args.zoom)
		cam.zoom_atual = cam.zoom_alvo
	if args.has("x") or args.has("z"):
		cam.alvo = cam.limitar(Vector3(float(args.get("x", cam.alvo.x)), 0.0, float(args.get("z", cam.alvo.z))))
	if args.has("fantasmas"):
		var cenas = ["morcego", "geleia", "crianca", "cavaleiro", "cao", "diabrete", "caveira", "palhaco", "zumbi"]
		var pontos = [Vector3(8, 0, 6.2), Vector3(10.2, 0, 9.6), Vector3(6.8, 0, 9.6), Vector3(14.2, 0, 6.2), Vector3(12.5, 0, 9.6),
			Vector3(9.1, 0, 7.4), Vector3(3.4, 0, 6.7), Vector3(5.7, 0, 14.1), Vector3(19.3, 0, 14.8)]
		for i in cenas.size():
			var f = load("res://scene/fantasmas/%s.tscn" % cenas[i]).instantiate()
			fase.mundo.add_child(f)
			f.global_position = pontos[i]
	if args.has("assustar"):
		for npc in get_nodes_in_group("npc"):
			npc.tomar_susto("teste", 130, null)
	var espera = float(args.get("espera", "2"))
	var t = 0.0
	while t < espera:
		await process_frame
		t += 1.0 / 60.0
		if args.has("levitar"):
			var vasos = get_nodes_in_group("levitavel")
			if not vasos.is_empty() and not vasos[0].segurando:
				vasos[0].levantar()
	if args.has("fps"):
		var quadros = 0
		var inicio = Time.get_ticks_msec()
		while Time.get_ticks_msec() - inicio < 4000:
			await process_frame
			quadros += 1
		print("FPS médio: ", quadros / 4.0)
	await RenderingServer.frame_post_draw
	var saida = args.get("saida", OS.get_user_data_dir() + "/print_casa.png")
	root.get_texture().get_image().save_png(saida)
	print("print salvo em ", saida)
	quit()
