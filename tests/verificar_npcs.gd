extends SceneTree

var falhas: int = 0

func _initialize() -> void:
	call_deferred("verificar")

func exigir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error(mensagem)
		falhas += 1

func verificar_infarto(npc) -> void:
	var esperados = {
		"Policial": "cavaleiro", "Advogado": "caveira", "Gótica": "geleia",
		"Psicopata": "crianca", "Adulto religioso": "diabrete", "Atleta": "palhaco",
		"Hippie": "cao", "Idoso": "zumbi", "Cientista": "geleia", "Criança": "morcego",
	}
	var dados = npc.dados_lore()
	exigir(dados.lore.size() == 3, "Lore incompleta: " + dados.nome)
	for frase in dados.lore:
		exigir(not frase.is_empty(), "Frase vazia: " + dados.nome)
	for nome in ["cavaleiro", "caveira", "geleia", "crianca", "diabrete", "palhaco", "cao", "zumbi", "morcego"]:
		var fantasma = load("res://scene/%s.tscn" % nome).instantiate()
		exigir(npc.mata_do_coracao(fantasma) == (nome == esperados[dados.nome]), "Relação de infarto incorreta: %s / %s" % [dados.nome, nome])
		fantasma.free()

func verificar() -> void:
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame
	var npcs = get_nodes_in_group("npc")
	exigir(npcs.size() == 9, "A casa precisa começar com 9 NPCs")
	exigir(get_nodes_in_group("policial").is_empty(), "Policial presente no início")
	var nomes = {}
	var modelo = load("res://scene/npc.tscn").instantiate()
	var escala_padrao = modelo.get_node("AnimatedSprite2D").scale
	modelo.free()
	for npc in npcs:
		exigir(npc.escala_sprite.is_equal_approx(escala_padrao), "Escala diferente do padrão: " + npc.dados_lore().nome)
		verificar_infarto(npc)
		var nome = npc.visual.get_meta("nome_tipo")
		exigir(not nomes.has(nome), "NPC repetido: " + nome)
		nomes[nome] = true
		exigir(npc.visual.get_frame_count("andar") == 6, "Animação incompleta: " + nome)
		for i in 6:
			var quadro = npc.visual.get_frame_texture("andar", i)
			exigir(quadro.region == Rect2(i * 32, 0, 32, 64), "Recorte incorreto: " + nome)
			exigir(quadro.atlas.resource_path.begins_with("res://assets/REFACTOR NPCs/"), "Sprite antigo: " + nome)
	for nome in ["Advogado", "Atleta", "Cientista", "Criança", "Gótica", "Hippie", "Idoso", "Psicopata", "Adulto religioso"]:
		exigir(nomes.has(nome), "NPC ausente: " + nome)
	var gm = root.get_node("GameManager")
	gm.mortes = house.limite_mortes - 1
	house.registrar_morte(npcs[0])
	exigir(get_nodes_in_group("policial").is_empty(), "Polícia chegou antes do limite")
	gm.mortes = house.limite_mortes
	house.registrar_morte(npcs[0])
	await process_frame
	var policiais = get_nodes_in_group("policial")
	exigir(policiais.size() == 1, "Polícia não chegou no limite de mortes")
	verificar_infarto(policiais[0])
	exigir(policiais[0].visual.resource_path == "res://assets/npc/policial.tres", "Visual errado do policial")
	exigir(policiais[0].visual.get_frame_count("andar") == 6, "Animação incompleta do policial")
	house.registrar_morte(npcs[0])
	exigir(get_nodes_in_group("policial").size() == 1, "Polícia duplicada")
	if falhas == 0:
		print("OK: 9 NPCs únicos, sprites novos, 30 frases, 90 relações de infarto e policial separado no limite de mortes.")
	house.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
