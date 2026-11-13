extends Node3D

class_name Fase

# Uma fase: as regras da partida, os objetivos e o fim. Cada fase tem duas cenas: o level
# (<nome>_level.tscn, só o mapa: paredes, chão, cômodos, pontos, luzes, convidados, ambiente)
# e a cena da fase (<nome>.tscn), que junta o level com câmera, HUD, pausa, tutorial e o resto.
# Tudo em metros, com o chão em y = 0.

const PAREDES = 1
const CHAO_CASA = 2

@onready var camera = $camera
@onready var ui = $UI_main
# pós-processamento: pos.chutar(forca) dá um tranco de aberração cromática
@onready var pos = $pos/tela
@onready var tutorial = $tutorial
@onready var lore = $lore
# onde entra o que aparece durante o jogo (fantasmas, comida, pentagramas, polícia)
@onready var mundo: Node3D = $mundo

# nós do level (export porque os filhos usam antes do _ready da fase)
@export var ambiente: WorldEnvironment
@export var ponto_fuga: Marker3D
@export var malha_casa: NavigationRegion3D
@export var no_comodos: Node3D

# a luz ambiente escurece e avermelha conforme a festa esvazia
@export var cor_festa: Color = Color(0.42, 0.38, 0.6)
@export var cor_vazia: Color = Color(0.3, 0.16, 0.22)

# quantos infartos até chamarem a polícia
@export var limite_mortes: int = 3
@export var cena_policial: PackedScene
# segundos de partida até amanhecer
@export var tempo_limite: float = 1080.0
# se só sobrou o policial (que não foge), amanhece logo
@export var tempo_so_policial: float = 90.0
# dois corpos colados por esse tempo: um deles muda de rumo
@export var tempo_sobreposicao: float = 20.0
@export var distancia_sobreposicao: float = 0.45
@export var quantos_marcados: int = 2
# "todos os cômodos juntos" = todos com susto dentro dessa janela
@export var janela_comodos: float = 6.0

var comodos: Array[Area3D] = []
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
# cômodo -> tempo_partida do último susto nele
var ultimo_susto_comodo: Dictionary = {}
var ultima_morte: Vector3

func _enter_tree() -> void:
	GameManager.fase = self

func _ready() -> void:
	GameManager.comecar_partida()
	GameManager.som.tocar_musica("jogo")
	for comodo in no_comodos.get_children():
		comodos.append(comodo)
	npcs_no_comeco = get_tree().get_nodes_in_group("npc").size()
	ambiente.environment.ambient_light_color = cor_festa
	marcar_alvos()
	mundo.add_child(preload("res://scripts/ui/areas_chao.gd").new())
	tutorial.comecar(self, true)

func _process(delta: float) -> void:
	var restantes = get_tree().get_nodes_in_group("npc").size()
	var foram = 1.0 - restantes / float(maxi(npcs_no_comeco, 1))
	var env = ambiente.environment
	env.ambient_light_color = env.ambient_light_color.lerp(cor_festa.lerp(cor_vazia, clampf(foram, 0.0, 1.0)), minf(delta, 1.0))
	if acabou:
		return
	# o relógio espera o tutorial
	if not tutorial.rodando():
		# tempo real: câmera lenta e hitstop não atrasam o relógio
		tempo_partida += minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
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

# ---------- mundo e tela

func na_tela(p: Vector3) -> Vector2:
	return camera.unproject_position(p)

func atras_da_camera(p: Vector3) -> bool:
	return camera.is_position_behind(p)

# quantos pixels de tela tem um metro perto de p (pra UI presa no mundo crescer com o zoom)
func pixels_por_metro(p: Vector3) -> float:
	return na_tela(p).distance_to(na_tela(p + camera.global_basis.x))

# põe um desenho da UI (Node2D/Control filho de algo 3D) em cima de um ponto do mundo
func posicionar(item: CanvasItem, p: Vector3) -> void:
	item.visible = not atras_da_camera(p)
	item.position = na_tela(p)

func mouse_no_chao() -> Vector3:
	return camera.mouse_no_chao()

# cantos na tela do quadro de um sprite em pé virado pra câmera (folga aumenta em volta do meio)
func cantos_na_tela(sprite: SpriteBase3D, folga: float = 1.0) -> PackedVector2Array:
	var caixa = sprite.get_aabb()
	var escala = sprite.global_basis.get_scale()
	var direita = Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	var meio = caixa.get_center()
	var cantos = PackedVector2Array()
	for c in [Vector2(caixa.position.x, caixa.position.y), Vector2(caixa.end.x, caixa.position.y), Vector2(caixa.end.x, caixa.end.y), Vector2(caixa.position.x, caixa.end.y)]:
		var local = Vector2(meio.x, meio.y) + (c - Vector2(meio.x, meio.y)) * folga
		cantos.append(na_tela(sprite.global_position + direita * local.x * escala.x + Vector3.UP * local.y * escala.y))
	return cantos

func mouse_em_sprite(sprite: SpriteBase3D, folga: float = 1.0) -> bool:
	return sprite.is_visible_in_tree() and Geometry2D.is_point_in_polygon(get_viewport().get_mouse_position(), cantos_na_tela(sprite, folga))

# mouse em cima de uma malha 3D (props): pelo contorno da caixa dela na tela
func mouse_em_malha(malha: MeshInstance3D) -> bool:
	if not malha.is_visible_in_tree():
		return false
	var caixa = malha.get_aabb()
	var pontos = PackedVector2Array()
	for i in 8:
		pontos.append(na_tela(malha.global_transform * caixa.get_endpoint(i)))
	return Geometry2D.is_point_in_polygon(get_viewport().get_mouse_position(), Geometry2D.convex_hull(pontos))

func centro_na_tela(sprite: SpriteBase3D) -> Vector2:
	var cantos = cantos_na_tela(sprite)
	return (cantos[0] + cantos[2]) / 2.0

# ponto do mundo no topo do desenho (pra pôr medidor, "!" e onomatopeia em cima da cabeça)
func topo(sprite: SpriteBase3D) -> Vector3:
	return sprite.global_position + Vector3.UP * sprite.get_aabb().end.y * sprite.global_basis.get_scale().y

# ---------- mapa

# ponto da malha da casa mais perto (não usa a da grama, que está no mesmo mapa)
func ponto_na_casa(p: Vector3) -> Vector3:
	var q = NavigationServer3D.region_get_closest_point(malha_casa.get_rid(), p)
	q.y = 0.0
	return q

# nome do cômodo em p, ou "" fora de todos. cômodo = Area3D com caixas (CollisionShape3D) no level
func comodo_em(p: Vector3) -> String:
	for comodo in comodos:
		for forma in comodo.get_children():
			var caixa: BoxShape3D = forma.shape
			var local = forma.global_transform.affine_inverse() * p
			if absf(local.x) <= caixa.size.x / 2.0 and absf(local.z) <= caixa.size.z / 2.0:
				return comodo.name
	return ""

func comodo_proibido(p: Vector3, proibidos: Array[String]) -> bool:
	var comodo = comodo_em(p)
	return proibidos.any(func(nome): return nome != "" and comodo.begins_with(nome))

# ponto qualquer de um cômodo, já em cima da malha da casa
func ponto_no_comodo(comodo: Area3D) -> Vector3:
	var forma: CollisionShape3D = comodo.get_children().pick_random()
	var meia = forma.shape.size / 2.0
	return ponto_na_casa(forma.global_transform * Vector3(randf_range(-meia.x, meia.x), 0.0, randf_range(-meia.z, meia.z)))

# raio de cima pra baixo em p, só contra as camadas da máscara
func bate_em(p: Vector3, mascara: int) -> bool:
	var consulta = PhysicsRayQueryParameters3D.create(Vector3(p.x, 5.0, p.z), Vector3(p.x, -0.5, p.z), mascara)
	return not get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()

func eh_parede(p: Vector3) -> bool:
	return bate_em(p, PAREDES)

# lado de fora: sem chão da casa e sem parede embaixo
func fora_de_casa(p: Vector3) -> bool:
	return not bate_em(p, PAREDES | CHAO_CASA)

# a música do palhaço deixa os sustos do cômodo dela mais fortes
func intensidade_susto(p: Vector3) -> float:
	var comodo = comodo_em(p)
	var intensidade = 1.0
	for palhaco in get_tree().get_nodes_in_group("musica"):
		if comodo != "" and palhaco.comodo_musica == comodo:
			intensidade = maxf(intensidade, palhaco.intensidade_musica)
	return intensidade

# susto por perto: piscam as luzes do cômodo ou a até 3,5 m
func piscar_luzes(p: Vector3, duracao: float) -> void:
	var comodo = comodo_em(p)
	for luz in get_tree().get_nodes_in_group("luz"):
		if luz.global_position.distance_to(p) < 3.5 or (comodo != "" and comodo_em(luz.global_position) == comodo):
			luz.piscar(duracao)

# ---------- regras

func objetivo_cumprido() -> bool:
	return objetivo_marcados or objetivo_comodos or objetivo_policial

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

# acabou o tempo: todo mundo vai embora correndo
func amanhecer() -> void:
	amanheceu = true
	ui.letreiro("AMANHECEU!", get_viewport().get_visible_rect().size * Vector2(0.42, 0.3))
	GameManager.som.tocar("objetivo")
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.fugir()

func terminar() -> void:
	# espera quem ainda está saindo pela porta ou caindo duro
	while not get_tree().get_nodes_in_group("convidado").is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var feitos = int(objetivo_marcados) + int(objetivo_comodos) + int(objetivo_policial)
	$vitoria.mostrar(npcs_no_comeco - GameManager.mortes, GameManager.mortes, tempo_partida, objetivo_cumprido(), feitos)

func marcar_alvos() -> void:
	var novos = candidatos_a_marcado().slice(0, quantos_marcados)
	for npc in novos:
		npc.marcar()
		marcados.append(npc)
	ui.mostrar_marcados(novos)

# só quem uma carta já liberada mata do coração. o policial fica de fora (tem objetivo próprio)
func candidatos_a_marcado() -> Array:
	var matadores = {}
	for card in ui.get_node("painel_fantasmas/lista").get_children():
		if not card.travada():
			matadores["%s %d" % [Fantasma.Tipo.find_key(card.tipo), card.tier]] = true
	var candidatos = get_tree().get_nodes_in_group("npc").filter(func(n):
		return not n.marcado and not n.policial and n.current_estado != Npc.Estado.Foge and matadores.has("%s %d" % [n.infarto_tipo, n.infarto_tier]))
	candidatos.shuffle()
	return candidatos

# todo susto que pega em alguém passa aqui (objetivo dos cômodos)
func registrar_susto(p: Vector3) -> void:
	var comodo = comodo_em(p)
	if comodo == "":
		return
	ultimo_susto_comodo[comodo] = tempo_partida
	if comodos_assustados() == comodos.size():
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

# marcado fugiu vivo: outro é marcado no lugar. só falha se não sobrar gente pra completar
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
	mundo.add_child(policial)
	policial.global_position = ponto_fuga.global_position
	npcs_no_comeco += 1
	ui.letreiro("POLÍCIA!", get_viewport().get_visible_rect().size * Vector2(0.42, 0.3))
	Onomatopeia.soltar("UIU UIU", ponto_fuga.global_position + Vector3.UP * 1.6, Color(0.5, 0.7, 1.0))
	camera.tremer(4.0)
	# o som some junto com a luz (10 piscadas de 0,6 s)
	GameManager.som.tocar("sirene", 6.0, 2.5)
	var sirene = OmniLight3D.new()
	sirene.light_energy = 3.0
	sirene.omni_range = 7.0
	mundo.add_child(sirene)
	sirene.global_position = ponto_fuga.global_position + Vector3.UP * 1.2
	var pisca = sirene.create_tween().set_loops(10)
	pisca.tween_callback(func(): sirene.light_color = Color(1, 0.15, 0.15))
	pisca.tween_interval(0.3)
	pisca.tween_callback(func(): sirene.light_color = Color(0.2, 0.4, 1))
	pisca.tween_interval(0.3)
	pisca.finished.connect(sirene.queue_free)
	while is_instance_valid(policial) and not policial.navigation_ready:
		await get_tree().physics_frame
	if is_instance_valid(policial):
		policial.agent.target_position = ultima_morte
		policial.tempo_atividade = 6.0
