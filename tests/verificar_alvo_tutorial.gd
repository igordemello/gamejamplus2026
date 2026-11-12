extends SceneTree

func _initialize() -> void:
	call_deferred("verificar")

func verificar() -> void:
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame
	var tutorial = house.get_node("tutorial")
	var vaso = house.get_node("Y-sort/prop_levitavel1")
	var certo = tutorial.objeto_levitavel == vaso and tutorial.passos[1].alvo.call() != null
	# o alvo é o levitável do cômodo com gente: o do tutorial tem que estar num cômodo que começa com gente
	certo = certo and house.comodo_em(vaso.global_position) == "NavigationRegion2D2"
	var alvo = tutorial.passos[1].alvo.call()
	alvo.ser_pego()
	certo = certo and tutorial.passos[1].alvo.call() != alvo
	alvo.reaparecer()
	certo = certo and tutorial.passos[1].alvo.call() != null
	if certo:
		print("OK: tutorial aponta para um levitável e troca/oculta a seta enquanto ele está indisponível.")
	else:
		push_error("Alvo incorreto no tutorial")
	house.queue_free()
	await process_frame
	quit(0 if certo else 1)
