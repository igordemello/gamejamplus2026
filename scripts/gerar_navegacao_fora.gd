extends SceneTree

# Gera assets/navegacao_fora.tres: a malha de navegação do lado de fora da casa (a grama),
# usada pelo zumbi pra contornar a casa e entrar pela porta da frente.
# Não dá pra fazer pelo botão Bake do editor (o cenário são sprites, não tem colisão).
# Rode de novo se mudar o formato da casa:
#   godot --headless --path . --script res://scripts/gerar_navegacao_fora.gd

const PASSO = 4
# um pouco além do que a câmera mostra, pra caber o caminho até a porta
const AREA = Rect2i(-320, -220, 2560, 1560)
# pedaço do corredor de fuga que fica na grama (já é da malha da casa, não pode sobrepor);
# os links porta_esquerda/porta_direita da casa ligam as duas malhas pelos lados dele
const CORREDOR = Rect2(866, 1030, 145, 230)

func _initialize() -> void:
	_gerar()

func _gerar() -> void:
	await process_frame
	var house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame

	# casa = tudo que não é lado de fora; vira obstáculo
	var tamanho = AREA.size / PASSO
	var casa = BitMap.new()
	casa.create(tamanho)
	for y in tamanho.y:
		for x in tamanho.x:
			var pos = Vector2(AREA.position + Vector2i(x, y) * PASSO) + Vector2.ONE * PASSO / 2.0
			casa.set_bit(x, y, not house.fora_de_casa(pos) or CORREDOR.has_point(pos))

	var dados = NavigationMeshSourceGeometryData2D.new()
	var r = Rect2(AREA)
	dados.add_traversable_outline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	for contorno in casa.opaque_to_polygons(Rect2i(Vector2i.ZERO, tamanho), 1.0):
		var mundo = PackedVector2Array()
		for v in contorno:
			mundo.append(Vector2(AREA.position) + v * PASSO)
		dados.add_obstruction_outline(mundo)

	var malha = NavigationPolygon.new()
	malha.agent_radius = 12.0
	NavigationServer2D.bake_from_source_geometry_data(malha, dados)
	ResourceSaver.save(malha, "res://assets/navegacao_fora.tres")
	print("navegacao_fora.tres: %d polígonos" % malha.get_polygon_count())
	quit()
