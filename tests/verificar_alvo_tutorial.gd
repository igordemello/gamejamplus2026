extends SceneTree

func _initialize() -> void:
	call_deferred("verificar")

func verificar() -> void:
	await process_frame
	var fase = load("res://scene/fases/casa/casa.tscn").instantiate()
	root.add_child(fase)
	await process_frame
	var tutorial = fase.tutorial
	var vaso = fase.get_node("level/props/prop_levitavel1")
	var certo = tutorial.objeto_levitavel == vaso and tutorial.passos[1].alvo.call() != null
	# o alvo é o levitável do cômodo com gente: o do tutorial tem que estar num cômodo que começa com gente
	certo = certo and fase.comodo_em(vaso.global_position) == "sala"
	var alvo = tutorial.passos[1].alvo.call()
	alvo.ser_pego()
	certo = certo and tutorial.passos[1].alvo.call() != alvo
	alvo.reaparecer()
	certo = certo and tutorial.passos[1].alvo.call() != null
	if certo:
		print("OK: tutorial aponta para um levitável e troca/oculta a seta enquanto ele está indisponível.")
	else:
		push_error("Alvo incorreto no tutorial")
	fase.queue_free()
	await process_frame
	quit(0 if certo else 1)
