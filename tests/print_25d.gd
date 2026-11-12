extends SceneTree

# Print da casa na vista 2.5D (ou 2D, pra comparar). Precisa de janela:
#   godot --path . --windowed --resolution 1920x1080 --script res://tests/print_25d.gd -- saida=C:/tmp/a.png
# Argumentos (todos opcionais): saida=<png>  espera=<segundos de jogo>  x=<px> y=<px> zoom=<z>
#   vista=3d|2d  perspectiva=1  giro=<graus>  inclinacao=<graus>  fantasmas=1 (põe um de cada perto do meio)  levitar=1 (segura o vaso)

var args: Dictionary = {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var partes = a.split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else "1"
	call_deferred("rodar")

func rodar() -> void:
	# nunca fica pendurado (janela minimizada não desenha, e o frame_post_draw não chega)
	create_timer(float(args.get("espera", "2")) + 60.0, true, false, true).timeout.connect(func():
		push_error("print_25d: tempo esgotado, nenhum quadro desenhado")
		quit(1))
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame
	house.tutorial.terminar()
	var mundo = house.get_node("mundo3d")
	if args.get("vista", "3d") == "2d":
		mundo.vista_3d = false
		mundo.aplicar_vista()
	if args.has("perspectiva"):
		mundo.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if args.has("giro"):
		mundo.giro = deg_to_rad(float(args.giro))
	if args.has("inclinacao"):
		mundo.inclinacao = float(args.inclinacao)
	var cam = house.camera
	if args.has("zoom"):
		cam.zoom_alvo = float(args.zoom)
		cam.zoom_atual = cam.zoom_alvo
		cam.zoom = Vector2.ONE * cam.zoom_alvo
	if args.has("x") or args.has("y"):
		cam.position = cam.limitar(Vector2(float(args.get("x", cam.position.x)), float(args.get("y", cam.position.y))), cam.zoom_alvo)
	if args.has("fantasmas"):
		var cenas = ["morcego", "geleia", "crianca", "cavaleiro", "cao", "diabrete", "caveira", "palhaco", "zumbi"]
		var pontos = [Vector2(700, 420), Vector2(900, 650), Vector2(600, 650), Vector2(1250, 420), Vector2(1100, 650), Vector2(800, 500), Vector2(300, 450), Vector2(500, 950), Vector2(1700, 1000)]
		for i in cenas.size():
			var f = load("res://scene/%s.tscn" % cenas[i]).instantiate()
			f.position = pontos[i]
			house.y_sort.add_child(f)
	var espera = float(args.get("espera", "2"))
	var t = 0.0
	while t < espera:
		await process_frame
		t += 1.0 / 60.0
		if args.has("levitar"):
			var vasos = get_nodes_in_group("levitavel")
			if not vasos.is_empty() and not vasos[0].segurando:
				vasos[0].levantar()
	await RenderingServer.frame_post_draw
	var saida = args.get("saida", OS.get_user_data_dir() + "/print_25d.png")
	root.get_texture().get_image().save_png(saida)
	print("print salvo em ", saida)
	quit()
