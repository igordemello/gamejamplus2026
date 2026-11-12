extends Fantasma

# voa quicando nas paredes; só o desenho fica no alto, a raiz anda no chão

@export var velocidade: float = 1.36
@export var raio_colisao: float = 0.23

@export var medo_bater_asas: int = 24
@export var forca_empurrao: float = 2.84
@export var raio_bater_asas: float = 1.7

@onready var sprite: SpritePersonagem = $sprite

var direcao: Vector3 = angulo_para_direcao(randf() * TAU)
# onde ele estava há pouco: sem sair de perto daqui, procura um caminho aberto
var ancora: Vector3 = Vector3.INF
var tempo_ancora: float = 0.0
# último lugar sem parede, pra voltar se entrar numa
var ultimo_bom: Vector3 = Vector3.INF

static func angulo_para_direcao(angulo: float) -> Vector3:
	return Vector3(cos(angulo), 0.0, sin(angulo))

func _physics_process(delta: float) -> void:
	var fase = GameManager.fase
	var passo = direcao * velocidade * delta

	# entrou numa parede: volta pro último lugar bom
	if fase.eh_parede(global_position):
		global_position = ultimo_bom if ultimo_bom != Vector3.INF else fase.ponto_na_casa(global_position)
		direcao = direcao_livre()
		return
	ultimo_bom = global_position

	var frente = direcao.sign() * raio_colisao

	var bateu_x = parede_adiante(Vector3(passo.x + frente.x, 0, 0))
	var bateu_z = parede_adiante(Vector3(0, 0, passo.z + frente.z))
	# quina de parede pega na diagonal
	if not bateu_x and not bateu_z and parede_adiante(passo + frente):
		bateu_x = true
		bateu_z = true

	if bateu_x:
		direcao.x = -direcao.x
	if bateu_z:
		direcao.z = -direcao.z
	# quica um pouco torto: reto, ele ficava indo e voltando entre duas paredes pra sempre
	if bateu_x or bateu_z:
		direcao = direcao.rotated(Vector3.UP, randf_range(-0.5, 0.5))

	global_position += direcao * velocidade * delta

	tempo_ancora += delta
	if ancora == Vector3.INF:
		ancora = global_position
	if tempo_ancora >= 3.0:
		if global_position.distance_to(ancora) < 1.7:
			direcao = direcao_livre()
		ancora = global_position
		tempo_ancora = 0.0

func redirecionar() -> bool:
	direcao = direcao_livre()
	return true

# uma das 3 direções com mais espaço livre
func direcao_livre() -> Vector3:
	var opcoes = []
	for i in 16:
		var dir = angulo_para_direcao(TAU * i / 16.0)
		var livre = 0.0
		while livre < 8.0 and not GameManager.fase.eh_parede(global_position + dir * (livre + 0.27)):
			livre += 0.27
		opcoes.append([livre, dir])
	opcoes.sort_custom(func(a, b): return a[0] > b[0])
	return opcoes.slice(0, 3).pick_random()[1]

# olha o trecho todo, não só a ponta, senão parede fina passa batido
func parede_adiante(desvio: Vector3) -> bool:
	for i in range(1, 5):
		if GameManager.fase.eh_parede(global_position + desvio * (i / 4.0)):
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
