extends Fantasma

@export var raio_risada: float = 220.0
@export var medo_risada: int = 24

@export var raio_mordida: float = 160.0
@export var medo_mordida: int = 38
@export var max_mordidos: int = 2
@export var tempo_fugindo: float = 4.0
# onde e de que tamanho os dentes aparecem no npc mordido
@export var posicao_dentes: Vector2 = Vector2(0, -89)
@export var escala_dentes: float = 2.0

@export var velocidade: float = 260.0
@export var alcance_cabecada: float = 30.0
@export var tempo_max_perseguindo: float = 6.0
@export var medo_cabecada: int = 66
@export var duracao_stun_cabecada: float = 10.0
# quanto do medo a pessoa perde por segundo enquanto está tonta da cabeçada
@export var dreno_cabecada: float = 1.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var alvo: Npc
var tempo_perseguindo: float = 0.0
var voltando: bool = false
# a lareira de onde saiu; volta pra cá depois da cabeçada
var casa: Vector2

func _ready() -> void:
	sprite.animation_finished.connect(_on_animacao_acabou)

func _physics_process(delta: float) -> void:
	if voltando:
		andar_pelo_caminho(casa, velocidade * delta)
		if global_position.distance_to(casa) <= 2.0:
			global_position = casa
			voltando = false
		return
	if not is_instance_valid(alvo) or sprite.animation != &"parada":
		return
	if casa == Vector2.ZERO:
		casa = global_position

	tempo_perseguindo += delta
	if tempo_perseguindo > tempo_max_perseguindo or not alvo.is_in_group("npc"):
		alvo = null
		voltar_pra_casa()
		return

	# é uma aparição, mas segue o caminho da casa como todo mundo: não atravessa parede
	if global_position.distance_to(alvo.global_position) <= alcance_cabecada:
		# segura a pessoa parada até a cabeçada acertar
		var frames = sprite.sprite_frames
		alvo.atordoar(frames.get_frame_count("cabecada") / frames.get_animation_speed("cabecada"))
		sprite.play("cabecada")
	else:
		andar_pelo_caminho(alvo.global_position, velocidade * delta)

func ocupada() -> bool:
	return sprite.animation != &"parada" or is_instance_valid(alvo)

func npcs_perto(raio: float) -> Array:
	var perto = get_tree().get_nodes_in_group("npc").filter(
		func(npc): return global_position.distance_to(npc.global_position) <= raio
	)
	perto.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return perto

func area_de(acao: Acao) -> Dictionary:
	match acao.metodo:
		&"risada_maligna":
			return area_raio(raio_risada)
		&"mordida_de_fogo":
			return area_raio(raio_mordida)
	return {}

# todo mundo no círculo em volta se assusta
func risada_maligna() -> bool:
	if ocupada():
		return false
	sprite.play("rir")
	onomatopeia("HAHAHA!", Color(0.85, 0.5, 1))
	GameManager.som.tocar("caveira_risada")
	var perto = npcs_perto(raio_risada)
	var medo = medo_em_grupo(medo_risada, perto.size())
	sentir_grupo(perto)
	for npc in perto:
		npc.tomar_susto("risada", medo, self)
	return true

# morde até duas pessoas perto, que saem correndo pra outro cômodo
func mordida_de_fogo() -> bool:
	if ocupada():
		return false
	var mordidos = npcs_perto(raio_mordida).slice(0, max_mordidos)
	if mordidos.is_empty():
		return false
	onomatopeia("NHAC!", Color(1, 0.55, 0.2))
	GameManager.som.tocar("caveira_mordida")
	var medo = medo_em_grupo(medo_mordida, mordidos.size())
	sentir_grupo(mordidos)
	for npc in mordidos:
		mostrar_dentes(npc)
		npc.tomar_susto("mordida", medo, self)
		npc.correr_para_outro_comodo(tempo_fugindo)
	return true

# persegue a pessoa mais perto e dá uma cabeçada
func cabecada() -> bool:
	if ocupada():
		return false
	var perto = npcs_perto(INF)
	if perto.is_empty():
		return false
	alvo = perto[0]
	tempo_perseguindo = 0.0
	if casa == Vector2.ZERO:
		casa = global_position
	voltando = false
	return true

# os dentes fantasmas (com a aura) fechando em cima de quem foi mordido;
# filho do npc pra ficar na frente dele e ir junto quando ele sai correndo
func mostrar_dentes(npc: Node2D) -> void:
	var dentes = AnimatedSprite2D.new()
	dentes.sprite_frames = sprite.sprite_frames
	dentes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dentes.position = posicao_dentes
	dentes.scale = Vector2(escala_dentes, escala_dentes)
	dentes.z_index = 1
	npc.add_child(dentes)
	dentes.play("mordida")
	dentes.animation_finished.connect(dentes.queue_free)

func voltar_pra_casa() -> void:
	voltando = true

func _on_animacao_acabou() -> void:
	if sprite.animation == &"cabecada" and is_instance_valid(alvo):
		onomatopeia("POW!", Color(1, 0.9, 0.3))
		GameManager.som.tocar("caveira_pow")
		alvo.tomar_susto("cabecada", medo_cabecada, self)
		alvo.atordoar(duracao_stun_cabecada, dreno_cabecada)
		GameManager.house.camera.tremer(6.0)
		alvo = null
		voltar_pra_casa()
	sprite.play("parada")
