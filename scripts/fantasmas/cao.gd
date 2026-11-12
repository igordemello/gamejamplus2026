extends Fantasma

@export var velocidade: float = 2.5
@export var velocidade_giro: float = 12.0
@export var alcance_mordida: float = 0.34

@export var medo_mastigar: int = 42
@export var duracao_mastigar: float = 2.5

@export var medo_latido: int = 22
# só o desenho da onda; o susto vale o cômodo inteiro
@export var raio_onda: float = 5.2

@onready var sprite: SpritePersonagem = $sprite

var alvo: Npc
# o desenho é visto de cima, então gira (sprite.giro, em volta do meio dele) pra encarar onde vai
var giro_alvo: float = 0.0
# segundos tentando chegar no alvo sem conseguir andar
var tempo_travado: float = 0.0

func _ready() -> void:
	sprite.animation_finished.connect(_on_animacao_acabou)

func _physics_process(delta: float) -> void:
	sprite.giro = lerp_angle(sprite.giro, giro_alvo, velocidade_giro * delta)
	sprite.speed_scale = 1.0
	if sprite.animation == &"parado" and is_instance_valid(alvo):
		ir_ate_alvo(delta)

func ocupado() -> bool:
	return sprite.animation != &"parado" or is_instance_valid(alvo)

# vai morder a pessoa mais perto do cômodo
func mastigar() -> bool:
	if ocupado():
		return false
	alvo = npc_mais_perto()
	return alvo != null

# assusta todo mundo do cômodo
func latido_feral() -> bool:
	if ocupado():
		return false
	sprite.play("latir")
	Onomatopeia.soltar("AU AU!", GameManager.fase.topo(sprite) + Vector3.UP * 0.2, Color(1, 0.65, 0.3), 7.0)
	soltar_onda()
	GameManager.fase.camera.tremer(8.0)
	GameManager.fase.pos.chutar(4.0)
	GameManager.som.tocar("cao_latido")
	var meu_comodo = GameManager.fase.comodo_em(global_position)
	var perto = get_tree().get_nodes_in_group("npc").filter(func(npc): return GameManager.fase.comodo_em(npc.global_position) == meu_comodo)
	var medo = medo_em_grupo(medo_latido, perto.size())
	sentir_grupo(perto)
	for npc in perto:
		npc.tomar_susto("latido", medo, self)
	return true

# anéis grossos saindo dele, um atrás do outro (malha deitada no chão)
func soltar_onda() -> void:
	var malha = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	malha.mesh = mesh
	malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	malha.material_override = material
	GameManager.fase.mundo.add_child(malha)
	malha.global_position = global_position + Vector3.UP * 0.03
	var tween = malha.create_tween()
	tween.tween_method(func(progresso: float):
		mesh.clear_surfaces()
		if progresso == 0.0:
			return
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 3:
			var t = clampf(progresso * 1.5 - i * 0.25, 0.0, 1.0)
			if t > 0.0:
				var meio = t * raio_onda
				var meia_largura = (14.0 * (1.0 - t) + 2.0) / 88.0 / 2.0
				anel(mesh, meio - meia_largura, meio + meia_largura, Color(1, 0.65, 0.3, (1.0 - t) * 0.8))
		mesh.surface_end(), 0.0, 1.0, 0.7)
	tween.tween_callback(malha.queue_free)

# anel no plano do chão, de raio interno a externo
func anel(malha: ImmediateMesh, interno: float, externo: float, cor: Color) -> void:
	const PONTOS = 48
	malha.surface_set_color(cor)
	for i in PONTOS:
		var a = Vector3(cos(TAU * i / PONTOS), 0.0, sin(TAU * i / PONTOS))
		var b = Vector3(cos(TAU * (i + 1) / PONTOS), 0.0, sin(TAU * (i + 1) / PONTOS))
		for ponto in [a * interno, a * externo, b * externo, a * interno, b * externo, b * interno]:
			malha.surface_add_vertex(ponto)

func area_de(_acao: Acao) -> Dictionary:
	return area_comodo()

func ir_ate_alvo(delta: float) -> void:
	var fase = GameManager.fase
	# não segue pra outro cômodo
	if not alvo.is_in_group("npc") or fase.comodo_em(alvo.global_position) != fase.comodo_em(global_position):
		desistir()
		return

	if global_position.distance_to(alvo.global_position) <= alcance_mordida:
		virar_para(global_position.direction_to(alvo.global_position))
		# segura a pessoa desde a agarrada até o fim da mastigada
		var frames = sprite.sprite_frames
		alvo.atordoar(frames.get_frame_count("agarrar") / frames.get_animation_speed("agarrar") + duracao_mastigar)
		sprite.play("agarrar")
		return

	# pelo caminho da casa, contornando parede; cômodo proibido e caminho travado fazem ele desistir
	var antes = global_position
	andar_pelo_caminho(alvo.global_position, velocidade * delta)
	# (se já estava num cômodo proibido, pode sair)
	if fase.comodo_proibido(global_position, comodos_proibidos) and not fase.comodo_proibido(antes, comodos_proibidos):
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
	# anima mais rápido andando
	sprite.speed_scale = 1.8

# não mordeu ninguém: a recarga não conta
func desistir() -> void:
	alvo = null
	tempo_travado = 0.0
	liberar_recarga(&"mastigar")

# o quad gira ao contrário do 2D (anti-horário), por isso o sinal
func virar_para(direcao: Vector3) -> void:
	giro_alvo = -(Vector2(direcao.x, direcao.z).angle() + PI / 2)

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
