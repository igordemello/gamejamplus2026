extends SceneTree

# Props de debug na vista 2.5D: a malha 3D existe, cobre o retângulo do Sprite2D, sobe quando ele levita,
# some quando o diabrete quebra e volta depois de 30 s.
#   godot --headless --path . --fixed-fps 60 --script res://tests/verificar_props_25d.gd

const V = preload("res://scripts/vista3d.gd")

var falhas: int = 0

func _initialize() -> void:
	call_deferred("verificar")

func exigir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		push_error(mensagem)
		falhas += 1

# retângulo de tela dos oito cantos da caixa unitária da malha
func retangulo_da_malha(malha: MeshInstance3D) -> Rect2:
	var caixa = Rect2()
	var primeiro = true
	for i in 8:
		var canto = Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1) - Vector3.ONE * 0.5
		var p = V.para_2d(malha.transform * canto)
		caixa = Rect2(p, Vector2.ZERO) if primeiro else caixa.expand(p)
		primeiro = false
	return caixa

func retangulo_do_sprite(prop: Sprite2D) -> Rect2:
	var r = prop.get_rect()
	return Rect2(prop.global_position + r.position * prop.global_scale, r.size * prop.global_scale)

func verificar() -> void:
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame
	await process_frame
	var lev = house.get_node("Y-sort/prop_levitavel1")
	var queb = house.get_node("Y-sort/prop_quebravel1")
	var espelhos = house.get_node("mundo3d/espelhos")
	for prop in [lev, queb]:
		var malha: MeshInstance3D = prop.get_node("prop3d").malha
		exigir(malha != null and malha.get_parent() == espelhos, "%s: malha 3D não existe em mundo3d/espelhos" % prop.name)
		if malha == null:
			continue
		var tela = retangulo_da_malha(malha)
		var sprite = retangulo_do_sprite(prop)
		exigir(tela.position.distance_to(sprite.position) < 0.5 and tela.size.distance_to(sprite.size) < 0.5,
			"%s: retângulo 3D %s diferente do Sprite2D %s" % [prop.name, tela, sprite])
		exigir(prop.visibility_layer == V.CAMADA_OCULTA, "%s: Sprite2D não foi escondido" % prop.name)

	# levitação: a malha sobe
	var malha_lev: MeshInstance3D = lev.get_node("prop3d").malha
	var y_repouso = malha_lev.position.y
	lev.levantar()
	await create_timer(1.0).timeout
	exigir(malha_lev.position.y > y_repouso + 3.0, "Malha não subiu ao levitar (%s -> %s)" % [y_repouso, malha_lev.position.y])
	lev.soltar()
	await create_timer(1.5).timeout
	exigir(absf(malha_lev.position.y - y_repouso) < 0.5, "Malha não voltou ao chão depois de soltar")

	# destruição: some ao quebrar e volta depois de 30 s (reparent do diabrete não libera a malha)
	var malha_queb: MeshInstance3D = queb.get_node("prop3d").malha
	var diabrete = load("res://scene/diabrete.tscn").instantiate()
	house.y_sort.add_child(diabrete)
	diabrete.altura_levantar = 0.0
	diabrete.alvo = queb
	diabrete.pegar()
	await create_timer(1.0).timeout
	exigir(is_instance_valid(malha_queb) and not malha_queb.visible, "Malha continua visível com o objeto quebrado")
	await create_timer(28.0).timeout
	exigir(not malha_queb.visible, "Malha voltou antes dos 30 s")
	await create_timer(2.0).timeout
	exigir(is_instance_valid(malha_queb) and malha_queb.visible, "Malha não voltou depois de 30 s")
	var tela = retangulo_da_malha(malha_queb)
	var sprite = retangulo_do_sprite(queb)
	exigir(tela.position.distance_to(sprite.position) < 0.5, "Malha voltou fora do lugar")

	if falhas == 0:
		print("OK: props 2.5D têm malha, cobrem o Sprite2D, sobem, somem e voltam.")
	house.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
