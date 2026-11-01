extends SceneTree

func _initialize() -> void:
	call_deferred("verificar")

func verificar() -> void:
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame
	var tutorial = house.get_node("tutorial")
	var vaso = house.get_node("Y-sort/Sprite2D30")
	var certo = tutorial.passos[1].alvo.call() == vaso and vaso.texture.resource_path == "res://assets/PROPS/flor.png"
	vaso.ser_pego()
	certo = certo and tutorial.passos[1].alvo.call() == null
	vaso.reaparecer()
	certo = certo and tutorial.passos[1].alvo.call() == vaso
	if certo:
		print("OK: tutorial aponta para o vaso levitável e oculta a seta enquanto ele está indisponível.")
	else:
		push_error("Alvo incorreto no tutorial")
	house.queue_free()
	await process_frame
	quit(0 if certo else 1)
