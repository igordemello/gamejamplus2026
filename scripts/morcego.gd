extends Fantasma

@export var velocidade: float = 120.0
@export var raio_colisao: float = 20.0

@export var medo_bater_asas: int = 40
@export var forca_empurrao: float = 250.0
# todo mundo nesse raio em volta dele se assusta e é empurrado pra longe
@export var raio_bater_asas: float = 100.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var direcao: Vector2 = Vector2.from_angle(randf() * TAU)

func _physics_process(delta: float) -> void:
	var house = GameManager.house
	var passo = direcao * velocidade * delta

	# se por algum motivo entrou numa parede, segue reto até sair; quicar ali dentro prende ele
	if house.eh_parede(global_position):
		global_position += passo
		return

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

	global_position += direcao * velocidade * delta

# olha o caminho todo até lá, não só a ponta: parede fina (menor que o raio de colisão) não deixa ele passar
func parede_adiante(desvio: Vector2) -> bool:
	for i in range(1, 5):
		if GameManager.house.eh_parede(global_position + desvio * (i / 4.0)):
			return true
	return false

func bater_asas() -> bool:
	onomatopeia("FLAP FLAP", Color(0.75, 0.6, 1))
	GameManager.som.tocar("morcego")
	# duas piscadas brancas, cada uma do tamanho de um quadro do voo
	piscar(2, 1.0 / sprite.sprite_frames.get_animation_speed(sprite.animation))

	for npc in get_tree().get_nodes_in_group("npc"):
		if global_position.distance_to(npc.global_position) <= raio_bater_asas:
			npc.velocity += global_position.direction_to(npc.global_position) * forca_empurrao
			npc.tomar_susto("morcego", medo_bater_asas, self)

	return true
