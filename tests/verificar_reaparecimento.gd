extends SceneTree

# o diabrete quebra um objeto comum e um levitável (este sendo segurado) duas vezes: eles somem, saem
# dos grupos e voltam iguais depois de 30 s
#   godot --headless --path . --fixed-fps 60 --script res://tests/verificar_reaparecimento.gd

var falhas: int = 0

func _initialize() -> void:
	call_deferred("verificar")

func exigir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error(mensagem)
		falhas += 1

func verificar() -> void:
	await process_frame
	var fase = load("res://scene/fases/casa/casa.tscn").instantiate()
	root.add_child(fase)
	await process_frame
	var objetos = [fase.get_node("level/props/prop_quebravel1"), fase.get_node("level/props/prop_levitavel1")]
	var estados = []
	var diabretes = []
	for objeto in objetos:
		objeto.add_to_group("quebravel")
		estados.append({"pai": objeto.get_parent(), "transform": objeto.transform})
		var diabrete = load("res://scene/fantasmas/diabrete.tscn").instantiate()
		fase.mundo.add_child(diabrete)
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
			exigir(not objeto.is_visible_in_tree() or objeto.scale.length() < 0.01, "Objeto quebrado ainda visível")
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
			exigir(objeto.transform.is_equal_approx(estados[i].transform), "Objeto voltou com outra posição, giro ou escala")
			exigir(objeto.is_visible_in_tree(), "Objeto voltou invisível")
		exigir(objetos[1].is_processing_input() and objetos[1].is_processing(), "Levitação não reativada")
		exigir(objetos[1].is_in_group("levitavel"), "Grupo levitavel não restaurado")
		exigir(not objetos[1].segurando, "Objeto voltou preso ao mouse")
	if falhas == 0:
		print("OK: objetos comuns e levitáveis voltam após 30 segundos, em dois ciclos de quebra.")
	fase.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
