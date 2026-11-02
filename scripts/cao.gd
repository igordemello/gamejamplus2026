extends Fantasma

@export var velocidade: float = 220.0
@export var velocidade_giro: float = 12.0
@export var alcance_mordida: float = 30.0

@export var medo_mastigar: int = 42
@export var duracao_mastigar: float = 2.5

@export var medo_latido: int = 22
# até onde a onda do latido vai, só no desenho (o susto vale o cômodo inteiro)
@export var raio_onda: float = 460.0

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
	Onomatopeia.soltar("AU AU!", global_position + luz.position * scale - Vector2(0, 70), Color(1, 0.65, 0.3), 7.0)
	soltar_onda()
	GameManager.house.camera.tremer(8.0)
	GameManager.house.pos.chutar(4.0)
	GameManager.som.tocar("cao_latido")
	var meu_comodo = GameManager.house.comodo_em(global_position)
	var perto = get_tree().get_nodes_in_group("npc").filter(func(npc): return GameManager.house.comodo_em(npc.global_position) == meu_comodo)
	var medo = medo_em_grupo(medo_latido, perto.size())
	sentir_grupo(perto)
	for npc in perto:
		npc.tomar_susto("latido", medo, self)
	return true

# anéis grossos saindo dele, um atrás do outro
func soltar_onda() -> void:
	var onda = Node2D.new()
	onda.material = preload("res://assets/sem_luz.tres")
	onda.z_index = 2
	onda.global_position = global_position
	GameManager.house.y_sort.add_child(onda)
	var progresso = [0.0]
	onda.draw.connect(func():
		for i in 3:
			var t = clampf(progresso[0] * 1.5 - i * 0.25, 0.0, 1.0)
			if t > 0.0:
				var cor = Color(1, 0.65, 0.3, (1.0 - t) * 0.8)
				onda.draw_arc(Vector2.ZERO, t * raio_onda, 0.0, TAU, 72, cor, 14.0 * (1.0 - t) + 2.0))
	var tween = onda.create_tween()
	tween.tween_method(func(t):
		progresso[0] = t
		onda.queue_redraw(), 0.0, 1.0, 0.7)
	tween.tween_callback(onda.queue_free)

func area_de(_acao: Acao) -> Dictionary:
	return area_comodo()

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
	# (quem já está lá dentro pode sair)
	if house.comodo_proibido(global_position, comodos_proibidos) and not house.comodo_proibido(antes, comodos_proibidos):
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
