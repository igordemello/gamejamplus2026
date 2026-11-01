extends Fantasma

@export var velocidade: float = 220.0
@export var velocidade_giro: float = 12.0
@export var alcance_mordida: float = 30.0

@export var medo_mastigar: int = 70
@export var duracao_mastigar: float = 2.5

@export var medo_latido: int = 35

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var alvo: Npc
# o desenho é visto de cima com a cabeça pra cima, então ele gira pra encarar onde vai
var giro_alvo: float = 0.0
# segundos tentando chegar no alvo sem conseguir andar
var tempo_travado: float = 0.0

func _ready() -> void:
	sprite.animation_finished.connect(_on_animacao_acabou)

func _physics_process(delta: float) -> void:
	sprite.rotation = lerp_angle(sprite.rotation, giro_alvo, velocidade_giro * delta)
	sprite.speed_scale = 1.0
	if sprite.animation == &"parado" and is_instance_valid(alvo):
		ir_ate_alvo(delta)

func ocupado() -> bool:
	return sprite.animation != &"parado" or is_instance_valid(alvo)

# escolhe a pessoa mais perto do cômodo e vai morder a perna dela
func mastigar() -> bool:
	if ocupado():
		return false
	alvo = npc_mais_perto()
	return alvo != null

# latido invertido que assusta todo mundo do cômodo
func latido_feral() -> bool:
	if ocupado():
		return false
	sprite.play("latir")
	onomatopeia("AU AU!", Color(1, 0.65, 0.3))
	GameManager.som.tocar("cao_latido")
	var meu_comodo = GameManager.house.comodo_em(global_position)
	for npc in get_tree().get_nodes_in_group("npc"):
		if GameManager.house.comodo_em(npc.global_position) == meu_comodo:
			npc.tomar_susto("latido", medo_latido, self)
	return true

func ir_ate_alvo(delta: float) -> void:
	var house = GameManager.house
	# não segue pra outro cômodo
	if not alvo.is_in_group("npc") or house.comodo_em(alvo.global_position) != house.comodo_em(global_position):
		desistir()
		return

	if global_position.distance_to(alvo.global_position) <= alcance_mordida:
		giro_alvo = global_position.direction_to(alvo.global_position).angle() + PI / 2
		# segura a pessoa desde a agarrada até o fim da mastigada
		var frames = sprite.sprite_frames
		alvo.atordoar(frames.get_frame_count("agarrar") / frames.get_animation_speed("agarrar") + duracao_mastigar)
		sprite.play("agarrar")
		return

	# pelo caminho da casa, contornando parede; cômodo proibido e caminho travado fazem ele desistir
	var antes = global_position
	andar_pelo_caminho(alvo.global_position, velocidade * delta)
	if house.comodo_proibido(global_position, comodos_proibidos):
		global_position = antes
		desistir()
		return
	if global_position == antes:
		tempo_travado += delta
		if tempo_travado > 1.5:
			desistir()
		return
	tempo_travado = 0.0
	virar_para(antes.direction_to(global_position))
	# anda mexendo os braços mais rápido
	sprite.speed_scale = 1.8

# não mordeu ninguém: a recarga não conta
func desistir() -> void:
	alvo = null
	tempo_travado = 0.0
	liberar_recarga(&"mastigar")

func virar_para(direcao: Vector2) -> void:
	giro_alvo = direcao.angle() + PI / 2

func _on_animacao_acabou() -> void:
	if sprite.animation == &"agarrar" and is_instance_valid(alvo):
		onomatopeia("NHAC NHAC", Color(1, 0.4, 0.4))
		GameManager.som.tocar("cao_nhac", duracao_mastigar, 0.3)
		alvo.tomar_susto("mastigar", medo_mastigar, self)
		alvo = null
		sprite.play("mastigar")
		get_tree().create_timer(duracao_mastigar).timeout.connect(sprite.play.bind("parado"))
		return
	alvo = null
	sprite.play("parado")
