extends Fantasma

@export var velocidade: float = 2.27

@export var medo_comida: int = 50
@export var cena_comida: PackedScene
# até onde ela consegue jogar a comida
@export var alcance_comida: float = 4.5

@export var medo_lambida: int = 42
@export var alcance_lambida: float = 0.45
# quadro da lambida em que a língua encosta
@export var quadro_lambida: int = 3

@export var amplitude_balanco: float = 1.0
@export var velocidade_balanco: float = 14.0

@onready var sprite: SpritePersonagem = $sprite

var alvo: Npc
var tempo_balanco: float = 0.0
# onde a comida vai cair
var destino_comida: Vector3

func _ready() -> void:
	sprite.animation_finished.connect(_on_animacao_acabou)
	sprite.frame_changed.connect(_on_quadro_mudou)

func _physics_process(delta: float) -> void:
	# balança de um ladinho pro outro, em pixels inteiros da arte
	tempo_balanco += delta
	sprite.position.x = roundf(sin(tempo_balanco * velocidade_balanco) * amplitude_balanco) * sprite.pixel_size

	if sprite.animation == &"parada" and is_instance_valid(alvo):
		ir_ate_alvo(delta)

func ocupada() -> bool:
	return sprite.animation != &"parada" or is_instance_valid(alvo)

func area_de(acao: Acao) -> Dictionary:
	return area_raio(alcance_comida) if acao.mira else area_comodo()

func mira_valida(_acao: Acao, onde: Vector3) -> bool:
	return global_position.distance_to(onde) <= alcance_comida and not GameManager.fase.eh_parede(onde)

func comer_e_regorfar(onde: Vector3) -> bool:
	if ocupada():
		return false
	destino_comida = onde
	sprite.flip_h = onde.x > global_position.x
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
	var fase = GameManager.fase
	# saiu do cômodo: vai atrás de outro; sem ninguém, não lambeu e a recarga não conta
	if not alvo.is_in_group("npc") or fase.comodo_em(alvo.global_position) != fase.comodo_em(global_position):
		alvo = npc_mais_perto()
		if alvo == null:
			liberar_recarga(&"lambidao")
		return

	# o desenho olha pra esquerda: vira antes de lamber
	sprite.flip_h = alvo.global_position.x > global_position.x
	if global_position.distance_to(alvo.global_position) <= alcance_lambida:
		lamber()
		return

	andar_pelo_caminho(alvo.global_position, velocidade * delta)

func lamber() -> void:
	sprite.play("lambida")
	onomatopeia("SLURP!", Color(1, 0.5, 0.8))
	# segura a pessoa até a língua chegar
	alvo.atordoar(quadro_lambida / sprite.sprite_frames.get_animation_speed("lambida"))

func _on_quadro_mudou() -> void:
	if sprite.animation != &"lambida" or sprite.frame != quadro_lambida or not is_instance_valid(alvo):
		return
	alvo.tomar_susto("lambida", medo_lambida, self)
	alvo.direcao_correr = global_position.direction_to(alvo.global_position)
	alvo = null

# a comida vai em arco até o lugar escolhido e só vale depois de cair
func jogar_comida(comida: Node3D) -> void:
	comida.set_physics_process(false)
	var de = global_position
	var ate = destino_comida
	var tween = comida.create_tween()
	tween.tween_method(func(t: float):
		comida.global_position = de.lerp(ate, t) + Vector3.UP * sin(t * PI) * (0.45 + de.distance_to(ate) * 0.2), 0.0, 1.0, 0.45)
	tween.tween_callback(comida.set_physics_process.bind(true))

func virar_para(direcao: Vector3) -> void:
	sprite.flip_h = direcao.x > 0.0

func _on_animacao_acabou() -> void:
	if sprite.animation == &"mordida":
		GameManager.som.tocar("geleia_regurgitar")
		var comida = cena_comida.instantiate()
		comida.medo = medo_comida
		comida.fantasma = self
		GameManager.fase.mundo.add_child(comida)
		comida.global_position = global_position
		jogar_comida(comida)
	alvo = null
	sprite.play("parada")
