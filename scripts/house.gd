extends Node2D

class_name House

var regionsHouse: Array[NavigationRegion2D] = []

@onready var house_regions: Node2D = $houseRegions
# camera.gd, quem quiser chacoalhar a tela chama camera.tremer(forca)
@onready var camera = $Camera2D

@export var ponto_fuga: Marker2D
@export var chao: Sprite2D
# fantasmas e comida criados durante o jogo entram aqui pra ordenar com NPCs e paredes
@export var y_sort: Node2D

func _ready() -> void:
	GameManager.house = self
	for region in house_regions.get_children():
		if region is NavigationRegion2D:
			# Cômodos só delimitam área; se ficarem ativos viram ilhas sobrepostas
			# à malha principal e os NPCs ficam presos dentro deles.
			region.enabled = false
			regionsHouse.append(region)

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

# parede = pixel opaco em qualquer sprite do grupo "parede", ou fora do chão
func eh_parede(pos: Vector2) -> bool:
	if not chao.is_pixel_opaque(chao.to_local(pos)):
		return true
	for sprite in get_tree().get_nodes_in_group("parede"):
		if sprite.is_pixel_opaque(sprite.to_local(pos)):
			return true
	return false
