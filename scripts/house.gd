extends Node2D

class_name House

var regionsHouse: Array[NavigationRegion2D] = []

@onready var house_regions: Node2D = $houseRegions
# camera.gd, quem quiser chacoalhar a tela chama camera.tremer(forca)
@onready var camera = $Camera2D
# ui_main.gd (contador de sustos)
@onready var ui = $UI_main
# pos.gd, o pós-processamento: pos.chutar(forca) dá um tranco de aberração cromática
@onready var pos = $pos/tela
@onready var noite: CanvasModulate = $noite
@onready var tutorial = $tutorial
# pentagrama da invocação e outros efeitos no chão (por baixo de todo mundo)
@onready var efeitos_chao: Node2D = $efeitos_chao
# a malha de dentro da casa (a da grama é outra região, no mesmo mapa)
@onready var malha_casa: NavigationRegion2D = $NavigationRegion2D

@export var ponto_fuga: Marker2D
@export var chao: Sprite2D
# fantasmas e comida criados durante o jogo entram aqui pra ordenar com NPCs e paredes
@export var y_sort: Node2D

# cor da noite com a festa cheia e com todo mundo já ido embora: a casa escurece e avermelha
@export var cor_festa: Color = Color(0.42, 0.38, 0.6)
@export var cor_vazia: Color = Color(0.3, 0.16, 0.22)

# quantos infartos até chamarem a polícia
@export var limite_mortes: int = 3
@export var cena_policial: PackedScene
# em segundos de partida: quando acaba amanhece, e quem ainda está na festa vai embora
@export var tempo_limite: float = 720.0
# só sobrou o policial, que não foge: amanhece logo, senão a partida fica parada esperando o relógio
@export var tempo_so_policial: float = 90.0
# dois (npc ou fantasma) em cima um do outro por esse tempo: um deles muda de rumo
@export var tempo_sobreposicao: float = 20.0
@export var distancia_sobreposicao: float = 40.0
# objetivos: além de esvaziar a casa, precisa cumprir um deles
@export var quantos_marcados: int = 2
# "todos os cômodos ao mesmo tempo" = todos com susto dentro dessa janela, em segundos
@export var janela_comodos: float = 6.0

var npcs_no_comeco: int = 0
var acabou: bool = false
var tempo_partida: float = 0.0
var marcados: Array = []
var marcados_mortos: int = 0
var marcado_escapou: bool = false
var objetivo_marcados: bool = false
var objetivo_comodos: bool = false
var objetivo_policial: bool = false
var policia_chamada: bool = false
var amanheceu: bool = false
# [a, b] -> segundos juntos
var sobrepostos: Dictionary = {}
var proxima_vigia: float = 0.0
# uma ação com mira está esperando o clique no mapa
var mirando: bool = false
# nome do cômodo -> tempo_partida do último susto nele
var ultimo_susto_comodo: Dictionary = {}
var ultima_morte: Vector2

func _ready() -> void:
	GameManager.house = self
	GameManager.comecar_partida()
	GameManager.som.tocar_musica("jogo")
	for region in house_regions.get_children():
		if region is NavigationRegion2D:
			# Cômodos só delimitam área; se ficarem ativos viram ilhas sobrepostas
			# à malha principal e os NPCs ficam presos dentro deles.
			region.enabled = false
			regionsHouse.append(region)
	npcs_no_comeco = get_tree().get_nodes_in_group("npc").size()
	noite.color = cor_festa
	marcar_alvos()
	var areas = preload("res://scripts/areas_chao.gd").new()
	efeitos_chao.add_child(areas)
	efeitos_chao.move_child(areas, 0)
	tutorial.comecar(self, true)

func _process(delta: float) -> void:
	var restantes = get_tree().get_nodes_in_group("npc").size()
	var foram = 1.0 - restantes / float(maxi(npcs_no_comeco, 1))
	noite.color = noite.color.lerp(cor_festa.lerp(cor_vazia, clampf(foram, 0.0, 1.0)), minf(delta, 1.0))
	if not acabou:
		# o relógio espera o tutorial acabar: ler não pode custar tempo
		if not tutorial.rodando():
			tempo_partida += delta
		if restantes == 1 and policia_chamada and not amanheceu and get_tree().get_nodes_in_group("policial").size() == 1:
			tempo_limite = minf(tempo_limite, tempo_partida + tempo_so_policial)
		if tempo_partida >= tempo_limite and not amanheceu:
			amanhecer()
		proxima_vigia -= delta
		if proxima_vigia <= 0.0:
			proxima_vigia = 0.5
			vigiar_sobreposicao(0.5)
		if npcs_no_comeco > 0 and restantes == 0:
			acabou = true
			terminar()

func objetivo_cumprido() -> bool:
	return objetivo_marcados or objetivo_comodos or objetivo_policial

# o ponto da malha da casa mais perto. não usa o mapa inteiro: a grama está no mesmo mapa,
# e de cima de uma parede o mais perto podia ser do lado de fora
func ponto_na_casa(pos: Vector2) -> Vector2:
	return NavigationServer2D.region_get_closest_point(malha_casa.get_rid(), pos)

# npc com npc, npc com fantasma ou fantasma com fantasma colados há tempo demais: um deles muda de rumo
func vigiar_sobreposicao(passo: float) -> void:
	var todos = get_tree().get_nodes_in_group("npc") + get_tree().get_nodes_in_group("fantasma")
	var agora = {}
	for i in todos.size():
		for j in range(i + 1, todos.size()):
			if todos[i].global_position.distance_to(todos[j].global_position) >= distancia_sobreposicao:
				continue
			var par = [todos[i], todos[j]]
			var tempo = sobrepostos.get(par, 0.0) + passo
			if tempo >= tempo_sobreposicao and (todos[i].redirecionar() or todos[j].redirecionar()):
				continue
			agora[par] = tempo
	sobrepostos = agora

# acabou o tempo: todo mundo vai embora correndo (dá pra pegar quem ainda está passando)
func amanhecer() -> void:
	amanheceu = true
	ui.letreiro("AMANHECEU!", get_viewport().get_visible_rect().size * Vector2(0.42, 0.3))
	GameManager.som.tocar("objetivo")
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.fugir()

# casa vazia: vitória se cumpriu algum objetivo, senão fim de festa
func terminar() -> void:
	# espera quem ainda está saindo pela porta ou caindo duro (e o policial, se chegou agora)
	while y_sort.get_children().any(func(c): return c is Npc):
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	$vitoria.mostrar(npcs_no_comeco - GameManager.mortes, GameManager.mortes, tempo_partida, objetivo_cumprido(), int(objetivo_marcados) + int(objetivo_comodos) + int(objetivo_policial))

# sorteia quem tem que morrer
func marcar_alvos() -> void:
	var novos = candidatos_a_marcado().slice(0, quantos_marcados)
	for npc in novos:
		npc.marcar()
		marcados.append(npc)
	ui.mostrar_marcados(novos)

# só quem um fantasma já liberado na loja consegue matar do coração (e ainda não está fugindo).
# o policial fica de fora: ele já tem objetivo próprio
func candidatos_a_marcado() -> Array:
	var matadores = {}
	for card in ui.get_node("painel_fantasmas/lista").get_children():
		if not card.travada():
			matadores["%s %d" % [Fantasma.Tipo.find_key(card.tipo), card.tier]] = true
	var candidatos = get_tree().get_nodes_in_group("npc").filter(func(n):
		return not n.marcado and not n.policial and n.current_estado != Npc.Estado.Foge and matadores.has("%s %d" % [n.infarto_tipo, n.infarto_tier]))
	candidatos.shuffle()
	return candidatos

# todo susto que pegou em alguém passa aqui (objetivo dos cômodos)
func registrar_susto(pos_susto: Vector2) -> void:
	var comodo = comodo_em(pos_susto)
	if comodo == "":
		return
	ultimo_susto_comodo[comodo] = tempo_partida
	if comodos_assustados() == regionsHouse.size():
		objetivo_comodos = true

func comodos_assustados() -> int:
	return ultimo_susto_comodo.values().filter(func(t): return tempo_partida - t <= janela_comodos).size()

func registrar_morte(npc) -> void:
	ultima_morte = npc.global_position
	if npc.marcado:
		marcados_mortos += 1
		ui.marcar_retrato(npc, true)
		if marcados_mortos == quantos_marcados:
			objetivo_marcados = true
	if npc.policial:
		objetivo_policial = true
	if GameManager.mortes == limite_mortes and not policia_chamada and not amanheceu:
		chamar_policia()

# marcado fugiu vivo: outro convidado é marcado no lugar. só falha se não sobrar gente pra completar
func marcado_fugiu(npc) -> void:
	ui.marcar_retrato(npc, false)
	var candidatos = candidatos_a_marcado()
	if not candidatos.is_empty():
		candidatos[0].marcar()
		marcados.append(candidatos[0])
		ui.mostrar_marcados([candidatos[0]])
	var vivos = marcados.filter(func(n): return is_instance_valid(n) and n.is_in_group("npc"))
	marcado_escapou = marcados_mortos + vivos.size() < quantos_marcados

# a polícia chega pela porta da frente com sirene e vai olhar onde foi a última morte
func chamar_policia() -> void:
	policia_chamada = true
	var policial = cena_policial.instantiate()
	policial.house = self
	y_sort.add_child(policial)
	policial.global_position = ponto_fuga.global_position
	npcs_no_comeco += 1
	ui.letreiro("POLÍCIA!", get_viewport().get_visible_rect().size * Vector2(0.42, 0.3))
	Onomatopeia.soltar("UIU UIU", ponto_fuga.global_position + Vector2(0, -110), Color(0.5, 0.7, 1.0))
	camera.tremer(4.0)
	# some junto com a luz da sirene (10 piscadas de 0,6 s)
	GameManager.som.tocar("sirene", 6.0, 2.5)
	var sirene = PointLight2D.new()
	sirene.texture = preload("res://assets/luz.tres")
	sirene.texture_scale = 3.0
	sirene.energy = 1.6
	sirene.position = ponto_fuga.position + Vector2(0, -80)
	add_child(sirene)
	var pisca = sirene.create_tween().set_loops(10)
	pisca.tween_callback(func(): sirene.color = Color(1, 0.15, 0.15))
	pisca.tween_interval(0.3)
	pisca.tween_callback(func(): sirene.color = Color(0.2, 0.4, 1))
	pisca.tween_interval(0.3)
	pisca.finished.connect(sirene.queue_free)
	while is_instance_valid(policial) and not policial.navigation_ready:
		await get_tree().physics_frame
	if is_instance_valid(policial):
		policial.agent.target_position = ultima_morte
		policial.tempo_atividade = 6.0

# susto por perto: as luzes do cômodo (ou a até 300 px) piscam
func piscar_luzes(pos_susto: Vector2, duracao: float) -> void:
	var comodo = comodo_em(pos_susto)
	for luz in get_tree().get_nodes_in_group("luz"):
		if luz.global_position.distance_to(pos_susto) < 300.0 or (comodo != "" and comodo_em(luz.global_position) == comodo):
			luz.piscar(duracao)

# nome do cômodo que contém pos, ou "" se não estiver em nenhum
func comodo_em(pos: Vector2) -> String:
	for region in regionsHouse:
		if Geometry2D.is_point_in_polygon(region.to_local(pos), region.navigation_polygon.get_outline(0)):
			return region.name
	return ""

# cada nome da lista vale como prefixo: "quarto" pega quarto, quarto2...
func comodo_proibido(pos: Vector2, proibidos: Array[String]) -> bool:
	var comodo = comodo_em(pos)
	return proibidos.any(func(p): return p != "" and comodo.begins_with(p))

# multiplicador dos sustos em pos: a música de circo do palhaço deixa o cômodo dela mais forte
func intensidade_susto(pos: Vector2) -> float:
	var comodo = comodo_em(pos)
	var intensidade = 1.0
	for palhaco in get_tree().get_nodes_in_group("musica"):
		if comodo != "" and palhaco.comodo_musica == comodo:
			intensidade = maxf(intensidade, palhaco.intensidade_musica)
	return intensidade

# lado de fora: fora do chão da casa e sem parede em cima (as paredes de fora também contam)
func fora_de_casa(pos: Vector2) -> bool:
	if chao.is_pixel_opaque(chao.to_local(pos)):
		return false
	for sprite in get_tree().get_nodes_in_group("parede"):
		if sprite.is_pixel_opaque(sprite.to_local(pos)):
			return false
	return true

# parede = pixel opaco em qualquer sprite do grupo "parede", ou fora do chão
func eh_parede(pos: Vector2) -> bool:
	if not chao.is_pixel_opaque(chao.to_local(pos)):
		return true
	for sprite in get_tree().get_nodes_in_group("parede"):
		if sprite.is_pixel_opaque(sprite.to_local(pos)):
			return true
	return false
