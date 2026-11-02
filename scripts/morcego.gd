extends Fantasma

@export var velocidade: float = 120.0
@export var raio_colisao: float = 20.0

@export var medo_bater_asas: int = 24
@export var forca_empurrao: float = 250.0
# todo mundo nesse raio em volta dele se assusta e é empurrado pra longe
@export var raio_bater_asas: float = 150.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var direcao: Vector2 = Vector2.from_angle(randf() * TAU)
# onde ele estava há pouco: sem sair de perto daqui, procura um caminho aberto
var ancora: Vector2 = Vector2.INF
var tempo_ancora: float = 0.0
# o último lugar sem parede: encostou em parede, volta pra cá. a casa é toda cercada, então não tem como sair
var ultimo_bom: Vector2 = Vector2.INF

func _physics_process(delta: float) -> void:
	var house = GameManager.house
	var passo = direcao * velocidade * delta

	# se por algum motivo entrou numa parede, segue reto até sair; quicar ali dentro prende ele
	if house.eh_parede(global_position):
		global_position = ultimo_bom if ultimo_bom != Vector2.INF else house.ponto_na_casa(global_position)
		direcao = direcao_livre()
		return
	ultimo_bom = global_position

	var frente = direcao.sign() * raio_colisao

	var bateu_x = parede_adiante(Vector2(passo.x + frente.x, 0))
	var bateu_y = parede_adiante(Vector2(0, passo.y + frente.y))
	# quina de parede pega na diagonal
	if not bateu_x and not bateu_y and parede_adiante(passo + frente):
		bateu_x = true
		bateu_y = true

	if bateu_x:
		direcao.x = -direcao.x
	if bateu_y:
		direcao.y = -direcao.y
	# quica um pouco torto: reto, ele ficava indo e voltando entre duas paredes pra sempre
	if bateu_x or bateu_y:
		direcao = direcao.rotated(randf_range(-0.5, 0.5))

	global_position += direcao * velocidade * delta

	tempo_ancora += delta
	if ancora == Vector2.INF:
		ancora = global_position
	if tempo_ancora >= 3.0:
		if global_position.distance_to(ancora) < 150.0:
			direcao = direcao_livre()
		ancora = global_position
		tempo_ancora = 0.0

func redirecionar() -> bool:
	direcao = direcao_livre()
	return true

# a direção com mais espaço aberto pela frente (entre as melhores, uma sorteada)
func direcao_livre() -> Vector2:
	var opcoes = []
	for i in 16:
		var dir = Vector2.from_angle(TAU * i / 16.0)
		var livre = 0.0
		while livre < 700.0 and not GameManager.house.eh_parede(global_position + dir * (livre + 24.0)):
			livre += 24.0
		opcoes.append([livre, dir])
	opcoes.sort_custom(func(a, b): return a[0] > b[0])
	return opcoes.slice(0, 3).pick_random()[1]

# olha o caminho todo até lá, não só a ponta: parede fina (menor que o raio de colisão) não deixa ele passar
func parede_adiante(desvio: Vector2) -> bool:
	for i in range(1, 5):
		if GameManager.house.eh_parede(global_position + desvio * (i / 4.0)):
			return true
	return false

func area_de(_acao: Acao) -> Dictionary:
	return area_raio(raio_bater_asas)

func bater_asas() -> bool:
	onomatopeia("FLAP FLAP", Color(0.75, 0.6, 1))
	GameManager.som.tocar("morcego")
	# duas piscadas brancas, cada uma do tamanho de um quadro do voo
	piscar(2, 1.0 / sprite.sprite_frames.get_animation_speed(sprite.animation))

	var perto = get_tree().get_nodes_in_group("npc").filter(func(npc): return global_position.distance_to(npc.global_position) <= raio_bater_asas)
	var medo = medo_em_grupo(medo_bater_asas, perto.size())
	sentir_grupo(perto)
	for npc in perto:
		npc.velocity += global_position.direction_to(npc.global_position) * forca_empurrao
		npc.tomar_susto("morcego", medo, self)

	return true
