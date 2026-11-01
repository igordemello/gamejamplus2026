extends Fantasma

@export var velocidade: float = 200.0

@export var medo_comida: int = 15
@export var cena_comida: PackedScene

@export var medo_lambida: int = 20
@export var alcance_lambida: float = 40.0

@export var amplitude_balanco: float = 1.0
@export var velocidade_balanco: float = 14.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var alvo: Npc
var tempo_balanco: float = 0.0

func _ready() -> void:
	sprite.animation_finished.connect(_on_animacao_acabou)

func _physics_process(delta: float) -> void:
	# balança de um ladinho pro outro, em pixels inteiros da arte
	tempo_balanco += delta
	sprite.position.x = roundf(sin(tempo_balanco * velocidade_balanco) * amplitude_balanco)

	if sprite.animation == &"parada" and is_instance_valid(alvo):
		ir_ate_alvo(delta)

func ocupada() -> bool:
	return sprite.animation != &"parada" or is_instance_valid(alvo)

func comer_e_regorfar() -> bool:
	if ocupada():
		return false
	sprite.play("mordida")
	return true

func lambidao() -> bool:
	if ocupada():
		return false
	alvo = npc_mais_perto()
	return alvo != null

func ir_ate_alvo(delta: float) -> void:
	var house = GameManager.house
	# saiu do cômodo, desiste
	if house.comodo_em(alvo.global_position) != house.comodo_em(global_position):
		alvo = null
		return

	if global_position.distance_to(alvo.global_position) <= alcance_lambida:
		lamber()
		return

	sprite.flip_h = alvo.global_position.x > global_position.x
	global_position = global_position.move_toward(alvo.global_position, velocidade * delta)

func lamber() -> void:
	sprite.play("lambida")
	alvo.tomar_susto("lambida", medo_lambida)
	alvo.direcao_correr = global_position.direction_to(alvo.global_position)
	alvo = null

func _on_animacao_acabou() -> void:
	if sprite.animation == &"mordida":
		var comida = cena_comida.instantiate()
		comida.medo = medo_comida
		GameManager.house.y_sort.add_child(comida)
		comida.global_position = global_position
	sprite.play("parada")
