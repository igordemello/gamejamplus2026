extends SceneTree

# Gera assets/navegacao_casa.tres: a malha de navegação de dentro da casa, a partir das próprias paredes
# (House.eh_parede: o chão e as peças do grupo "parede", inclusive o layoutcasa.png).
# Quem anda nela tem a origem no pé: npcs e fantasmas. Não dá pra fazer pelo botão Bake do editor
# (o cenário são sprites, não tem colisão). Rode de novo se mudar o formato da casa:
#   godot --headless --path . --script res://scripts/gerar_navegacao_casa.gd

const PASSO = 4
const AREA = Rect2i(200, -40, 1560, 1320)
# a saída pela porta da frente até o PontoFuga: fica além do chão, mas é por onde quem foge vai embora
const CORREDOR = Rect2(866, 1000, 145, 260)
# folga entre o pé de quem anda e a parede
const RAIO = 12.0

func _initialize() -> void:
	_gerar()

func _gerar() -> void:
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame

	var tamanho = AREA.size / PASSO
	var parede = {}
	for y in tamanho.y:
		for x in tamanho.x:
			var pos = Vector2(AREA.position + Vector2i(x, y) * PASSO) + Vector2.ONE * PASSO / 2.0
			if house.eh_parede(pos) and not CORREDOR.has_point(pos):
				parede[Vector2i(x, y)] = true

	# de fora = parede ligada à borda da área. o resto (chão e paredes soltas no meio) é a casa
	var fora = {}
	var pilha: Array[Vector2i] = []
	for x in tamanho.x:
		pilha.append(Vector2i(x, 0))
		pilha.append(Vector2i(x, tamanho.y - 1))
	for y in tamanho.y:
		pilha.append(Vector2i(0, y))
		pilha.append(Vector2i(tamanho.x - 1, y))
	while not pilha.is_empty():
		var c = pilha.pop_back()
		if fora.has(c) or not parede.has(c):
			continue
		fora[c] = true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pilha.append(c + d)

	var casa = BitMap.new()
	casa.create(tamanho)
	var soltas = BitMap.new()
	soltas.create(tamanho)
	for y in tamanho.y:
		for x in tamanho.x:
			var c = Vector2i(x, y)
			casa.set_bit(x, y, not fora.has(c))
			soltas.set_bit(x, y, parede.has(c) and not fora.has(c))

	var dados = NavigationMeshSourceGeometryData2D.new()
	for contorno in casa.opaque_to_polygons(Rect2i(Vector2i.ZERO, tamanho), 1.0):
		dados.add_traversable_outline(para_mundo(contorno))
	for contorno in soltas.opaque_to_polygons(Rect2i(Vector2i.ZERO, tamanho), 1.0):
		dados.add_obstruction_outline(para_mundo(contorno))

	var malha = NavigationPolygon.new()
	malha.agent_radius = RAIO
	NavigationServer2D.bake_from_source_geometry_data(malha, dados)
	ResourceSaver.save(malha, "res://assets/navegacao_casa.tres")
	print("navegacao_casa.tres: %d polígonos" % malha.get_polygon_count())
	quit()

func para_mundo(contorno: PackedVector2Array) -> PackedVector2Array:
	var mundo = PackedVector2Array()
	for v in contorno:
		mundo.append(Vector2(AREA.position) + v * PASSO)
	return mundo
