extends Sprite2D

@export var altura_levitacao: float = 12.0
@export var velocidade_levitacao: float = 5.0
@export var intensidade_tremida: float = 2.0
@export var suavidade: float = 10.0
# segundos segurando até a tremida chegar no máximo
@export var tempo_carga: float = 1.5
# subidinha quando o mouse passa por cima, mostrando que dá pra pegar
@export var altura_hover: float = 4.0

var posicao_original: Vector2
var escala_original: Vector2
var tempo: float = 0.0

var segurando : bool = false
# o primeiro susto de cada vez que pega solta um "BUUU!"
var primeiro_susto: bool = false

@export var tipo_susto: String = "objeto"
@export var pontos_susto: int = 20
# a partir desse nível de medo o objeto quase não faz efeito: quem termina o serviço são os fantasmas
@export var nivel_fraco: int = 2
@export var pontos_susto_fraco: int = 3
@export var intervalo_susto: float = 1.0

var tempo_susto: float = 0.0

var tween_escala: Tween
var tween_queda: Tween
var som_levitando: AudioStreamPlayer
# o próprio desenho escuro e achatado, que fica no chão enquanto o objeto sobe
var sombra: Sprite2D

func _ready() -> void:
	add_to_group("levitavel")
	posicao_original = position
	escala_original = scale
	sombra = Sprite2D.new()
	sombra.texture = texture
	sombra.show_behind_parent = true
	# no chão (levantado, o objeto fica uma camada acima)
	sombra.z_index = -1
	add_child(sombra)

func _process(delta: float) -> void:
	# fora do chão fica por cima: o Y-sort usa a posição, e subir faria ele passar pra trás da parede
	z_index = 1 if segurando or posicao_original.y - position.y > 0.5 else 0
	if segurando:
		tempo += delta
		# quanto mais tempo segurando, mais treme e balança
		var carga = minf(tempo / tempo_carga, 1.0)
		var posicao_alvo = posicao_original

		# Levitação
		posicao_alvo.y -= altura_levitacao
		posicao_alvo.y += sin(tempo * velocidade_levitacao) * 3.0

		# Tremida
		var tremida = intensidade_tremida * (0.3 + carga)
		posicao_alvo.x += randf_range(-tremida, tremida)
		posicao_alvo.y += randf_range(-tremida, tremida)

		# Movimento suave
		position = position.lerp(posicao_alvo, min(suavidade * delta, 1.0))
		rotation = sin(tempo * 9.0) * 0.12 * carga

		tempo_susto += delta

		if tempo_susto >= intervalo_susto:
			tempo_susto = 0.0
			aplicar_susto()
			pulsar()
	elif not (tween_queda and tween_queda.is_running()):
		var posicao_alvo = posicao_original
		if mouse_em_cima():
			posicao_alvo.y -= altura_hover
		position = position.lerp(posicao_alvo, min(suavidade * delta, 1.0))

	# a sombra fica no chão: quanto mais alto o objeto, menor e mais escura
	var altura = clampf((posicao_original.y - position.y) / altura_levitacao, 0.0, 1.0)
	sombra.global_position = get_parent().to_global(posicao_original + Vector2(0, get_rect().end.y * escala_original.y))
	sombra.global_rotation = 0.0
	sombra.scale = Vector2(1.0, 0.25) * (1.0 - altura * 0.3)
	sombra.modulate = Color(0, 0, 0, 0.5 * altura)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and mouse_em_cima():
			levantar()
		elif not event.pressed and segurando:
			soltar()

func mouse_em_cima() -> bool:
	return get_rect().has_point(to_local(get_global_mouse_position()))

func levantar() -> void:
	segurando = true
	primeiro_susto = true
	tempo = 0.0
	tempo_susto = 0.0
	if tween_queda:
		tween_queda.kill()
	som_levitando = GameManager.som.tocar("levitando")
	# estica pra cima no puxão
	esticar(Vector2(0.8, 1.25))

# cai quicando e amassa quando bate no chão
func soltar() -> void:
	segurando = false
	GameManager.som.parar(som_levitando)
	tween_queda = create_tween()
	tween_queda.tween_property(self, "position", posicao_original, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_queda.parallel().tween_property(self, "rotation", 0.0, 0.2)
	# a primeira batida do TRANS_BOUNCE é em ~36% do tempo
	tween_queda.parallel().tween_callback(esticar.bind(Vector2(1.3, 0.75))).set_delay(0.16)

# o diabrete pegou (o prop também está no grupo "quebravel"): larga o mouse, volta pro chão e
# para de levitar e de receber clique. quem pegou cuida do resto
func ser_pego() -> void:
	segurando = false
	GameManager.som.parar(som_levitando)
	remove_from_group("levitavel")
	for tween in [tween_queda, tween_escala]:
		if tween:
			tween.kill()
	position = posicao_original
	scale = escala_original
	rotation = 0.0
	sombra.hide()
	z_index = 0
	set_process(false)
	set_process_input(false)

func reaparecer() -> void:
	add_to_group("levitavel")
	sombra.show()
	set_process(true)
	set_process_input(true)

# a cada susto: incha, pisca claro e a tela dá uma tremidinha
func pulsar() -> void:
	esticar(Vector2(1.3, 1.3))
	self_modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(self, "self_modulate", Color.WHITE, 0.25)
	GameManager.house.camera.tremer(2.0)
	if primeiro_susto:
		primeiro_susto = false
		Onomatopeia.soltar("BUUU!", global_position + Vector2(0, -40), Color(0.8, 1, 1))
		GameManager.som.tocar("buu_levitavel")

# deforma rapidinho e volta pro tamanho normal com um pulinho
func esticar(forma: Vector2) -> void:
	if tween_escala:
		tween_escala.kill()
	tween_escala = create_tween()
	tween_escala.tween_property(self, "scale", escala_original * forma, 0.06)
	tween_escala.tween_property(self, "scale", escala_original, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func get_region_at_position(pos: Vector2) -> NavigationRegion2D:
	var closest_region: NavigationRegion2D = null
	var closest_distance: float = INF

	for region in GameManager.house.regionsHouse:
		var polygon = region.navigation_polygon

		if polygon == null:
			continue

		var local_pos = region.to_local(pos)
		var vertices = polygon.get_vertices()

		for i in range(polygon.get_polygon_count()):
			var indices = polygon.get_polygon(i)
			var points = PackedVector2Array()

			for index in indices:
				points.append(vertices[index])

			if points.size() < 3:
				continue

			# Primeiro verifica se está dentro da região
			if Geometry2D.is_point_in_polygon(local_pos, points):
				return region

			# Caso contrário, calcula a distância até o polígono
			for j in range(points.size()):
				var a = points[j]
				var b = points[(j + 1) % points.size()]

				var closest_point = Geometry2D.get_closest_point_to_segment(
					local_pos, a, b
				)

				var world_point = region.to_global(closest_point)
				var distance = pos.distance_squared_to(world_point)

				if distance < closest_distance:
					closest_distance = distance
					closest_region = region

	return closest_region

#func aplicar_susto() -> void:
	#print("1 - aplicar_susto foi chamado")
	#var regiao_objeto = get_region_at_position(global_position)
	#print("2 - Região do objeto: ", regiao_objeto)
#
	#if regiao_objeto == null:
		#return
#
	#var npcs = get_tree().get_nodes_in_group("npc")
	#print("3 - NPCs encontrados: ", npcs.size())
#
	#for npc in npcs:
		#print("4 - NPC encontrado: ", npc.name)
		#if npc is Npc:
			#var regiao_npc = get_region_at_position(npc.global_position)
			#print("5 - Região do NPC: ", regiao_npc)
#
			#if regiao_npc == regiao_objeto:
				#print("6 - Aplicando susto!")
				#npc.tomar_susto(tipo_susto, pontos_susto)

func aplicar_susto() -> void:
	var regiao_objeto = get_region_at_position(global_position)

	if regiao_objeto == null:
		return

	for npc in get_tree().get_nodes_in_group("npc"):
		if npc is Npc:
			# só quem está de fato dentro do cômodo do objeto (no corredor, fora de cômodo, não conta)
			if GameManager.house.comodo_em(npc.global_position) == regiao_objeto.name:
				npc.tomar_susto(tipo_susto, pontos_susto if npc.nivel_medo < nivel_fraco else pontos_susto_fraco)

#func aplicar_susto() -> void:
	#print("Posição do objeto: ", global_position)
	#print("Quantidade de regiões: ", GameManager.house.regionsHouse.size())
#
	#for region in GameManager.house.regionsHouse:
		#print("Região: ", region.name)
		#print("Posição local do objeto: ", region.to_local(global_position))
		#print("Quantidade de polígonos: ", region.navigation_polygon.get_polygon_count())
#
	#var regiao_objeto = get_region_at_position(global_position)
	#print("Região encontrada: ", regiao_objeto)
