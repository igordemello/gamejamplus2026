extends SceneTree

# executa cada ação de cada fantasma e confere que assustou alguém (ou fez o efeito esperado)
#   godot --headless --path . --fixed-fps 60 --script res://tests/verificar_fantasmas.gd

var falhas: int = 0

func _initialize() -> void:
	call_deferred("verificar")

func medo_total(n) -> float:
	return n.nivel_medo * 100.0 + n.barra_susto

func verificar() -> void:
	await process_frame
	var fase = load("res://scene/fases/casa/casa.tscn").instantiate()
	root.add_child(fase)
	await process_frame
	await create_timer(1.0).timeout
	fase.tutorial.terminar()
	var npcs = get_nodes_in_group("npc")
	var alvo = npcs[0]
	# os outros ficam longe, num cômodo diferente (a casa não pode esvaziar)
	for n in npcs:
		n.atordoar(9999.0)
	var base = alvo.global_position
	var fantasmas = ["morcego", "crianca", "cavaleiro", "cao", "diabrete", "caveira", "palhaco", "geleia", "zumbi"]
	for nome in fantasmas:
		var f = load("res://scene/fantasmas/%s.tscn" % nome).instantiate()
		f.passeia = false
		fase.mundo.add_child(f)
		f.global_position = base
		alvo.global_position = fase.ponto_na_casa(base + Vector3(0, 0, 0.8))
		if nome == "zumbi":
			f.global_position = fase.ponto_fuga.global_position + Vector3(0, 0, 2)
			alvo.global_position = f.global_position + Vector3(1.5, 0, 0)
			alvo.global_position = fase.ponto_na_casa(alvo.global_position)
		if nome == "diabrete":
			# o susto sai onde o objeto cair: põe o convidado perto do objeto mais perto
			var objeto = f.objeto_mais_perto()
			alvo.global_position = fase.ponto_na_casa(objeto.global_position + Vector3(0.6, 0, 0))
		await process_frame
		print(nome, " distancia ao alvo ", f.global_position.distance_to(alvo.global_position))
		for acao in f.acoes:
			if acao.metodo == &"mover_para":
				continue
			alvo.zerar_medo()
			alvo.atordoar(9999.0)
			f.recarga_restante.clear()
			var antes = medo_total(alvo)
			var ok = false
			if acao.mira:
				ok = f.call(acao.metodo, f.global_position + Vector3(1.2, 0, 0))
			else:
				ok = f.call(acao.metodo)
			var tocando = f.is_in_group("musica")
			# espera a ação terminar (até 12 s de jogo)
			var t = 0.0
			while t < 12.0:
				await process_frame
				t += 1.0 / 60.0
				if medo_total(alvo) > antes + 0.01:
					await create_timer(0.5).timeout
					break
			var depois = medo_total(alvo)
			var ocupado = f.ocupado_agora()
			print("%s.%s: retorno=%s medo %.1f -> %.1f em %.1fs ocupado=%s" % [nome, acao.metodo, ok, antes, depois, t, ocupado])
			if not ok:
				push_error("%s.%s devolveu false" % [nome, acao.metodo])
				falhas += 1
			elif acao.metodo == &"musica_de_circo":
				if not tocando:
					push_error("palhaco.musica_de_circo não entrou no grupo musica")
					falhas += 1
			elif acao.metodo == &"comer_e_regorfar":
				if get_nodes_in_group("comida").is_empty() and fase.mundo.find_children("*", "Sprite3D", true, false).is_empty():
					push_error("geleia não soltou comida")
					falhas += 1
			elif depois <= antes:
				push_error("%s.%s não assustou ninguém" % [nome, acao.metodo])
				falhas += 1
			# espera voltar ao repouso
			var espera = 0.0
			while f.ocupado_agora() and espera < 15.0:
				await process_frame
				espera += 1.0 / 60.0
			if f.ocupado_agora():
				push_error("%s.%s não terminou (ficou ocupado)" % [nome, acao.metodo])
				falhas += 1
		f.queue_free()
		await process_frame
	print("falhas: ", falhas)
	quit(1 if falhas > 0 else 0)
