extends Node3D

# susto em área que pegou várias pessoas: raios saindo do centro até cada uma, tremendo a cada quadro,
# anéis abrindo no chão e faíscas em quem foi atingido. Fantasma.sentir_grupo cria isso em fase.mundo

const MARCA = preload("res://scripts/efeitos/marca_atracao.gd")
const DURACAO = 0.5

var centro: Vector3
var alvos: Array = []
# última posição de cada alvo: ele pode sumir (infarto, saída) enquanto o raio ainda está na tela
var pontos: Array[Vector3] = []
var cor: Color = Color.WHITE
var forca: float = 1.0
var tempo: float = 0.0
var malha := ImmediateMesh.new()

func _ready() -> void:
	add_child(MARCA.nova_malha(malha, true))
	for alvo in alvos:
		pontos.append(no_peito(alvo))

func no_peito(alvo: Node3D) -> Vector3:
	return alvo.global_position + Vector3.UP * 0.68

func _process(delta: float) -> void:
	# em tempo real: o efeito acontece justamente durante o congelamento do impacto
	tempo += minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	if tempo >= DURACAO:
		queue_free()
		return
	for i in alvos.size():
		if is_instance_valid(alvos[i]):
			pontos[i] = no_peito(alvos[i])
	desenhar()

func desenhar() -> void:
	malha.clear_surfaces()
	malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var t = tempo / DURACAO
	var alfa = 1.0 - t
	var cam = GameManager.fase.camera.global_basis
	# anéis abrindo do centro, no chão
	for i in 2:
		var anel = clampf(t * 1.6 - i * 0.25, 0.0, 1.0)
		if anel > 0.0:
			MARCA.arco(malha, Vector3(centro.x, MARCA.Y_CHAO, centro.z), anel * (2.27 + 0.9 * forca), 0.0, TAU, ((12.0 + 4.0 * forca) * (1.0 - anel) + 1.0) / 88.0, Color(cor, (1.0 - anel) * 0.8))
	# raios até cada pessoa: só no começo, que é quando o golpe "liga" todo mundo
	if t < 0.6:
		for ponto in pontos:
			desenhar_raio(centro, ponto, 1.0 - t / 0.6)
	# faísca em quem foi atingido
	for ponto in pontos:
		for i in 6:
			var angulo = TAU * i / 6.0 + float(i) * 1.7
			var dir = cam.x * cos(angulo) + cam.y * sin(angulo)
			MARCA.linha(malha, ponto + dir * (10.0 + 50.0 * t) / 88.0, ponto + dir * (18.0 + 75.0 * t) / 88.0, 0.034, Color(cor, alfa))
		MARCA.disco(malha, ponto, 0.3 * alfa, Color(Color.WHITE, alfa * 0.6))
	malha.surface_end()

func desenhar_raio(de: Vector3, ate: Vector3, luz: float) -> void:
	var lado = (ate - de).cross(GameManager.fase.camera.global_basis.z).normalized()
	var partes = maxi(int(de.distance_to(ate) / 0.32), 3)
	var pts = [de]
	for i in range(1, partes):
		pts.append(de.lerp(ate, float(i) / partes) + lado * randf_range(-0.18, 0.18))
	pts.append(ate)
	for i in pts.size() - 1:
		MARCA.linha(malha, pts[i], pts[i + 1], 0.09, Color(cor, luz * 0.55))
	for i in pts.size() - 1:
		MARCA.linha(malha, pts[i], pts[i + 1], 0.034, Color(Color.WHITE, luz))
