extends SceneTree

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
	var objetos = [house.get_node("Y-sort/objeto_quebravel1"), house.get_node("objeto_levitavel")]
	var estados = []
	var diabretes = []
	for objeto in objetos:
		objeto.add_to_group("quebravel")
		estados.append({"pai": objeto.get_parent(), "transform": objeto.transform, "cor": objeto.modulate})
		var diabrete = load("res://scene/diabrete.tscn").instantiate()
		house.y_sort.add_child(diabrete)
		diabrete.altura_levantar = 0.0
		exigir(diabrete.tempo_reaparecer == 30.0, "Tempo padrão diferente de 30 segundos")
		diabretes.append(diabrete)
	# duas quebras seguidas de cada objeto: comum e levitável, inclusive sendo segurado
	for ciclo in 2:
		objetos[1].levantar()
		await process_frame
		for i in objetos.size():
			diabretes[i].alvo = objetos[i]
			diabretes[i].pegar()
		await create_timer(1.0).timeout
		for objeto in objetos:
			exigir(is_instance_valid(objeto), "Objeto foi destruído em vez de aguardar o retorno")
			exigir(objeto.modulate.a == 0.0, "Objeto quebrado ainda visível")
			exigir(not objeto.is_in_group("quebravel"), "Objeto quebrado continua disponível ao Diabrete")
		exigir(not objetos[1].is_processing_input(), "Levitável quebrado ainda recebe cliques")
		exigir(not objetos[1].is_in_group("levitavel"), "Tutorial ainda encontra levitável quebrado")
		await create_timer(28.0).timeout
		for objeto in objetos:
			exigir(not objeto.is_in_group("quebravel"), "Objeto retornou antes dos 30 segundos")
		await create_timer(2.0).timeout
		for i in objetos.size():
			var objeto = objetos[i]
			exigir(objeto.is_in_group("quebravel"), "Objeto não voltou a ser quebrável")
			exigir(objeto.get_parent() == estados[i].pai, "Objeto retornou ao pai errado")
			exigir(objeto.position.distance_to(estados[i].transform.origin) < 0.1, "Objeto retornou à posição errada")
			exigir(objeto.scale.is_equal_approx(estados[i].transform.get_scale()), "Escala não restaurada")
			exigir(is_equal_approx(objeto.rotation, estados[i].transform.get_rotation()), "Rotação não restaurada")
			exigir(objeto.modulate == estados[i].cor, "Cor e opacidade não restauradas")
		exigir(objetos[1].is_processing_input() and objetos[1].is_processing(), "Levitação não reativada")
		exigir(objetos[1].is_in_group("levitavel") and objetos[1].sombra.visible, "Sombra ou grupo não restaurados")
		exigir(not objetos[1].segurando, "Objeto voltou preso ao mouse")
	if falhas == 0:
		print("OK: objetos comuns e levitáveis voltam após 30 segundos, em dois ciclos de quebra.")
	house.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
