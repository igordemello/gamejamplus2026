extends Fantasma

@export var velocidade: float = 200.0

@export var medo_comida: int = 50
@export var cena_comida: PackedScene

@export var medo_lambida: int = 70
@export var alcance_lambida: float = 40.0
# quadro da lambida em que a língua encosta
@export var quadro_lambida: int = 3

@export var amplitude_balanco: float = 1.0
@export var velocidade_balanco: float = 14.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var alvo: Npc
var tempo_balanco: float = 0.0

func _ready() -> void:
	sprite.animation_finished.connect(_on_animacao_acabou)
	sprite.frame_changed.connect(_on_quadro_mudou)

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
	onomatopeia("NHAC!", Color(0.8, 0.5, 1))
	GameManager.som.tocar("geleia_nhac")
	return true

func lambidao() -> bool:
	if ocupada():
		return false
	alvo = npc_mais_perto()
	return alvo != null

func ir_ate_alvo(delta: float) -> void:
	var house = GameManager.house
	# saiu do cômodo: vai atrás de outro; sem ninguém, não lambeu e a recarga não conta
	if not alvo.is_in_group("npc") or house.comodo_em(alvo.global_position) != house.comodo_em(global_position):
		alvo = npc_mais_perto()
		if alvo == null:
			liberar_recarga(&"lambidao")
		return

	# o desenho olha pra esquerda; vira antes de lamber, senão a língua sai pro outro lado
	sprite.flip_h = alvo.global_position.x > global_position.x
	if global_position.distance_to(alvo.global_position) <= alcance_lambida:
		lamber()
		return

	andar_pelo_caminho(alvo.global_position, velocidade * delta)

func lamber() -> void:
	sprite.play("lambida")
	onomatopeia("SLURP!", Color(1, 0.5, 0.8))
	# segura a pessoa até a língua chegar; sem isso ela saía correndo antes de ser lambida
	alvo.atordoar(quadro_lambida / sprite.sprite_frames.get_animation_speed("lambida"))

func _on_quadro_mudou() -> void:
	if sprite.animation != &"lambida" or sprite.frame != quadro_lambida or not is_instance_valid(alvo):
		return
	alvo.tomar_susto("lambida", medo_lambida, self)
	alvo.direcao_correr = global_position.direction_to(alvo.global_position)
	alvo = null

func virar_para(direcao: Vector2) -> void:
	sprite.flip_h = direcao.x > 0.0

func _on_animacao_acabou() -> void:
	if sprite.animation == &"mordida":
		GameManager.som.tocar("geleia_regurgitar")
		var comida = cena_comida.instantiate()
		comida.medo = medo_comida
		comida.fantasma = self
		GameManager.house.y_sort.add_child(comida)
		comida.global_position = global_position
	alvo = null
	sprite.play("parada")
