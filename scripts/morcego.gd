extends Fantasma

@export var velocidade: float = 120.0
@export var raio_colisao: float = 20.0

@export var medo_bater_asas: int = 10
@export var forca_empurrao: float = 250.0
# retangulo na frente do morcego, o x positivo aponta pra onde ele ta voando
@export var area_bater_asas: Rect2 = Rect2(0, -48, 160, 96)

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

	var bateu_x = house.eh_parede(global_position + Vector2(passo.x + frente.x, 0))
	var bateu_y = house.eh_parede(global_position + Vector2(0, passo.y + frente.y))
	# quina de parede pega na diagonal
	if not bateu_x and not bateu_y and house.eh_parede(global_position + passo + frente):
		bateu_x = true
		bateu_y = true

	if bateu_x:
		direcao.x = -direcao.x
	if bateu_y:
		direcao.y = -direcao.y

	global_position += direcao * velocidade * delta

func bater_asas() -> bool:
	# duas piscadas brancas, cada uma do tamanho de um quadro do voo
	piscar(2, 1.0 / sprite.sprite_frames.get_animation_speed(sprite.animation))

	for npc in get_tree().get_nodes_in_group("npc"):
		var pos_local = (npc.global_position - global_position).rotated(-direcao.angle())
		if area_bater_asas.has_point(pos_local):
			npc.velocity += direcao * forca_empurrao
			npc.tomar_susto("morcego", medo_bater_asas, self)

	return true
