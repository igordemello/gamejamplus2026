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

@export var ponto_fuga: Marker2D
@export var chao: Sprite2D
# fantasmas e comida criados durante o jogo entram aqui pra ordenar com NPCs e paredes
@export var y_sort: Node2D

# cor da noite com a festa cheia e com todo mundo já ido embora: a casa escurece e avermelha
@export var cor_festa: Color = Color(0.42, 0.38, 0.6)
@export var cor_vazia: Color = Color(0.3, 0.16, 0.22)
var npcs_no_comeco: int = 0
# a partida acaba (vitória) quando não sobra ninguém na casa
var acabou: bool = false
var tempo_partida: float = 0.0

func _ready() -> void:
	GameManager.house = self
	GameManager.comecar_partida()
	for region in house_regions.get_children():
		if region is NavigationRegion2D:
			# Cômodos só delimitam área; se ficarem ativos viram ilhas sobrepostas
			# à malha principal e os NPCs ficam presos dentro deles.
			region.enabled = false
			regionsHouse.append(region)
	npcs_no_comeco = get_tree().get_nodes_in_group("npc").size()
	noite.color = cor_festa
	if not tutorial.ja_viu():
		tutorial.comecar(self)

func _process(delta: float) -> void:
	var restantes = get_tree().get_nodes_in_group("npc").size()
	var foram = 1.0 - restantes / float(maxi(npcs_no_comeco, 1))
	noite.color = noite.color.lerp(cor_festa.lerp(cor_vazia, clampf(foram, 0.0, 1.0)), minf(delta, 1.0))
	if not acabou:
		tempo_partida += delta
		if npcs_no_comeco > 0 and restantes == 0:
			acabou = true
			vencer()

# por enquanto a vitória é tirar todo mundo da casa (fugindo ou de infarto)
func vencer() -> void:
	# espera quem ainda está saindo pela porta ou caindo duro terminar
	while y_sort.get_children().any(func(c): return c is Npc):
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	$vitoria.mostrar(npcs_no_comeco - GameManager.mortes, GameManager.mortes, tempo_partida)

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
