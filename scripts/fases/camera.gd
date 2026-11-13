extends Camera3D

# Câmera da fase: olha pra um ponto do chão (alvo) de cima, inclinada e em perspectiva, estilo Octopath.
# Scroll dá zoom (chega mais perto), botão direito arrasta o mapa e, se pode_girar, o botão do meio
# gira em volta do alvo. Também faz a tremida, o tranco de zoom, o foco da lore e os passeios
# automáticos (zumbi lá fora, lista de fantasmas).

# graus pra baixo
@export var inclinacao: float = 40.0
@export var pode_girar: bool = true
@export var graus_por_pixel: float = 0.3
# zoom 1 = vista a distancia_base metros do alvo; maior = mais perto
@export var distancia_base: float = 23.0
@export var zoom_min: float = 0.62
@export var zoom_max: float = 1.6
@export var zoom_inicial: float = 0.8
@export var passo_zoom: float = 0.1
# quanto maior, mais rápido o zoom chega onde o scroll mandou
@export var suavidade_zoom: float = 8.0
@export var posicao_inicial: Vector3 = Vector3(11.25, 0, 9.2)
# até onde o alvo pode ir (x e z, em metros)
@export var limite: Rect2 = Rect2(-2, -3, 26, 26)
# zoom acima disso é o jogador olhando algo de perto: o lembrete do zumbi não atrapalha
@export var zoom_de_perto: float = 1.15
# clicar num fantasma da lista aproxima até aqui
@export var zoom_aproximar: float = 1.1
@export var passo_lembrete: float = 0.1
@export var suavidade_conducao: float = 3.0
# segundos sem mexer na câmera até um lembrete poder afastar ela
@export var calma_lembrete: float = 6.0
@export var queda_tremida: float = 40.0
# foco num alvo (lore): zoom e a velocidade com que a câmera desliza até ele
@export var zoom_foco: float = 2.4
@export var suavidade_foco: float = 8.0
# desfoque em cima e embaixo da tela (0 desliga)
@export var desfoque: float = 0.05

var alvo: Vector3
var giro: float = 0.0
var zoom_alvo: float
var zoom_atual: float
var tremida: float = 0.0
var tranco: float = 0.0
var fov_base: float
# quanto o jogador já arrastou com o botão direito (o tutorial usa)
var arrastado: float = 0.0
var foco: Node3D
var focando: bool = false
var foco_lado: float = 1.0
# onde estava antes do foco; volta = ainda deslizando de volta
var alvo_antes: Vector3
var volta: bool = false
# o jogo está levando a câmera até um lugar (scroll ou arrasto cancelam)
var conduzindo: bool = false
var alvo_conduzido: Vector3
var mexeu_em: int = 0

func _ready() -> void:
	fov_base = fov
	zoom_alvo = zoom_inicial
	zoom_atual = zoom_inicial
	alvo = limitar(posicao_inicial)
	attributes = CameraAttributesPractical.new()
	atualizar()

func _process(delta: float) -> void:
	# em tempo real: continua no hitstop e na câmera lenta (com teto pro quadro em que o time_scale muda)
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	tremida = move_toward(tremida, 0.0, queda_tremida * real)
	tranco = lerpf(tranco, 0.0, minf(10.0 * real, 1.0)) if tranco > 0.0005 else 0.0
	if focando and not is_instance_valid(foco):
		soltar_foco()

	var zoom_destino = zoom_foco if focando else zoom_alvo
	if not is_equal_approx(zoom_atual, zoom_destino):
		var novo = lerpf(zoom_atual, zoom_destino, minf(suavidade_zoom * real, 1.0))
		if absf(novo - zoom_destino) < 0.001:
			novo = zoom_destino
		# aproxima na direção do mouse: o ponto embaixo dele não sai do lugar
		var antes = mouse_no_chao()
		zoom_atual = novo
		atualizar()
		if not focando and not volta and not conduzindo:
			alvo = limitar(alvo + antes - mouse_no_chao())

	if focando or volta:
		var destino = alvo_do_foco() if focando else alvo_antes
		alvo = alvo.lerp(destino, minf(suavidade_foco * real, 1.0))
		if not focando and alvo.distance_to(destino) < 0.02 and is_equal_approx(zoom_atual, zoom_alvo):
			volta = false
	elif conduzindo:
		var destino = limitar(alvo_conduzido)
		alvo = alvo.lerp(destino, minf(suavidade_conducao * real, 1.0))
		if alvo.distance_to(destino) < 0.02 and is_equal_approx(zoom_atual, zoom_alvo):
			conduzindo = false
	atualizar()

func _unhandled_input(event: InputEvent) -> void:
	# com foco a câmera é da lore
	if focando:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_alvo = clampf(zoom_alvo + passo_zoom, zoom_min, zoom_max)
			jogador_mexeu()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_alvo = clampf(zoom_alvo - passo_zoom, zoom_min, zoom_max)
			jogador_mexeu()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		# o chão acompanha o mouse
		var antes = chao_em(event.position - event.relative)
		alvo = limitar(alvo + antes - chao_em(event.position))
		volta = false
		jogador_mexeu()
		arrastado += event.relative.length()
		atualizar()
	elif pode_girar and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		giro = wrapf(giro - deg_to_rad(event.relative.x * graus_por_pixel), -PI, PI)
		jogador_mexeu()
		atualizar()

# força da névoa em qualquer zoom: 1 = densidade do level, 0 = sem névoa
@export_range(0.0, 1.0) var fog_forca: float = 0.4
var densidade_base: float = -1.0

func distancia() -> float:
	return distancia_base / zoom_atual

# põe a câmera no lugar a partir do alvo, do giro, da inclinação e do zoom
func atualizar() -> void:
	var base = Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -deg_to_rad(inclinacao))
	global_transform = Transform3D(base, alvo + base.z * distancia())
	fov = fov_base / (1.0 + tranco)
	# tremida em "pixels" de tela: 1 px é mais ou menos distancia/1000 metros
	var escala = distancia() / 1000.0
	h_offset = randf_range(-1.0, 1.0) * tremida * escala
	v_offset = randf_range(-1.0, 1.0) * tremida * escala
	# névoa com a mesma espessura em qualquer zoom (senão perto/longe muda a densidade vista)
	var fase = GameManager.fase
	if fase and fase.ambiente:
		var env = fase.ambiente.environment
		if densidade_base < 0.0:
			densidade_base = env.volumetric_fog_density
		env.volumetric_fog_density = densidade_base * fog_forca * distancia_base / distancia()
		env.volumetric_fog_length = maxf(distancia() * 1.6, 16.0)
	var a: CameraAttributesPractical = attributes
	a.dof_blur_amount = desfoque
	a.dof_blur_far_enabled = desfoque > 0.0
	a.dof_blur_far_distance = distancia() + 4.0
	a.dof_blur_far_transition = distancia() * 0.6
	a.dof_blur_near_enabled = desfoque > 0.0
	a.dof_blur_near_distance = maxf(distancia() - 4.0, 0.5)
	a.dof_blur_near_transition = 3.0

# ponto do chão (y = 0) num ponto da tela
func chao_em(tela: Vector2) -> Vector3:
	var origem = project_ray_origin(tela)
	var direcao = project_ray_normal(tela)
	if absf(direcao.y) < 0.0001:
		return alvo
	return origem + direcao * (-origem.y / direcao.y)

func mouse_no_chao() -> Vector3:
	return chao_em(get_viewport().get_mouse_position())

func jogador_mexeu() -> void:
	conduzindo = false
	mexeu_em = Time.get_ticks_msec()

func limitar(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, limite.position.x, limite.end.x), 0.0, clampf(p.z, limite.position.y, limite.end.y))

# leva a vista até um ponto, aproximando um pouco
func aproximar_de(ponto: Vector3) -> void:
	if focando:
		return
	zoom_alvo = maxf(zoom_alvo, zoom_aproximar)
	alvo_conduzido = ponto
	conduzindo = true
	volta = false
	mexeu_em = Time.get_ticks_msec()

# afasta até mostrar tudo, inclusive o lado de fora da casa (ganhou o zumbi)
func mostrar_exterior() -> void:
	if focando:
		return
	zoom_alvo = zoom_min
	alvo_conduzido = Vector3(limite.get_center().x, 0.0, limite.get_center().y)
	conduzindo = true
	volta = false

# um ponto aparece na tela agora? (as cartas tampam a parte de baixo)
func ponto_na_vista(ponto: Vector3) -> bool:
	if is_position_behind(ponto):
		return false
	var tela = get_viewport().get_visible_rect().size
	return Rect2(60, 40, tela.x - 120, tela.y - 200).has_point(unproject_position(ponto))

# lembra o jogador de algo fora da vista: afasta um passo e puxa a vista na direção dele.
# não faz nada se ele está olhando de perto, mexeu agora há pouco ou o ponto já aparece
func lembrar_de(ponto: Vector3) -> bool:
	if focando or volta or conduzindo or zoom_alvo > zoom_de_perto:
		return false
	if Time.get_ticks_msec() - mexeu_em < calma_lembrete * 1000.0 or ponto_na_vista(ponto):
		return false
	zoom_alvo = maxf(zoom_alvo - passo_lembrete, zoom_min)
	alvo_conduzido = alvo.lerp(ponto, 0.35)
	conduzindo = true
	return true

# o alvo em foco fica no meio de uma metade da tela (lado 1: a esquerda, -1: a direita)
func alvo_do_foco() -> Vector3:
	var largura = 2.0 * distancia() * tan(deg_to_rad(fov_base) / 2.0) * get_viewport().get_visible_rect().size.aspect()
	var direita = Vector3(global_basis.x.x, 0.0, global_basis.x.z).normalized()
	return foco.global_position + direita * foco_lado * largura / 4.0

# desliza e dá zoom no alvo, guardando o enquadramento de antes (trocar de alvo não perde)
func focar(novo: Node3D, lado: float) -> void:
	if not focando and not volta:
		alvo_antes = alvo
	focando = true
	foco = novo
	foco_lado = lado
	volta = false

func soltar_foco() -> void:
	if not focando:
		return
	focando = false
	foco = null
	volta = true

# chacoalha a tela; se já estiver tremendo mais forte, fica a mais forte
func tremer(forca: float) -> void:
	tremida = maxf(tremida, forca)

# aproxima de repente um tiquinho e volta (0.03 = 3%)
func chutar(forca: float) -> void:
	tranco = maxf(tranco, forca)
