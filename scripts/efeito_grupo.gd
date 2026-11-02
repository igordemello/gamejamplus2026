extends Node2D

# susto em área que pegou várias pessoas: raios saindo do centro até cada uma, tremendo a cada quadro,
# anéis abrindo e faíscas em quem foi atingido. Fantasma.sentir_grupo cria isso

const DURACAO = 0.5

var centro: Vector2
var alvos: Array = []
# última posição de cada alvo: ele pode sumir (infarto, saída) enquanto o raio ainda está na tela
var pontos: Array[Vector2] = []
var cor: Color = Color.WHITE
var forca: float = 1.0
var tempo: float = 0.0

func _ready() -> void:
	material = preload("res://assets/sem_luz.tres")
	z_index = 2
	global_position = Vector2.ZERO
	for alvo in alvos:
		pontos.append(no_peito(alvo))

func no_peito(alvo: Node2D) -> Vector2:
	return alvo.global_position + Vector2(0, -60)

func _process(delta: float) -> void:
	# em tempo real: o efeito acontece justamente durante o congelamento do impacto
	tempo += minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	if tempo >= DURACAO:
		queue_free()
		return
	for i in alvos.size():
		if is_instance_valid(alvos[i]):
			pontos[i] = no_peito(alvos[i])
	queue_redraw()

func _draw() -> void:
	var t = tempo / DURACAO
	var alfa = 1.0 - t
	# anéis abrindo do centro
	for i in 2:
		var anel = clampf(t * 1.6 - i * 0.25, 0.0, 1.0)
		if anel > 0.0:
			draw_arc(centro, anel * (200.0 + 80.0 * forca), 0.0, TAU, 64, Color(cor, (1.0 - anel) * 0.8), (12.0 + 4.0 * forca) * (1.0 - anel) + 1.0)
	# raios até cada pessoa: só no começo, que é quando o golpe "liga" todo mundo
	if t < 0.6:
		for ponto in pontos:
			desenhar_raio(centro, ponto, 1.0 - t / 0.6)
	# faísca em quem foi atingido
	for ponto in pontos:
		for i in 6:
			var angulo = TAU * i / 6.0 + float(i) * 1.7
			var de = ponto + Vector2.from_angle(angulo) * (10.0 + 50.0 * t)
			var ate = ponto + Vector2.from_angle(angulo) * (18.0 + 75.0 * t)
			draw_line(de, ate, Color(cor, alfa), 3.0)
		draw_circle(ponto, 26.0 * alfa, Color(Color.WHITE, alfa * 0.6))

func desenhar_raio(de: Vector2, ate: Vector2, luz: float) -> void:
	var linha = PackedVector2Array([de])
	var lado = (ate - de).orthogonal().normalized()
	var partes = maxi(int(de.distance_to(ate) / 28.0), 3)
	for i in range(1, partes):
		linha.append(de.lerp(ate, float(i) / partes) + lado * randf_range(-16.0, 16.0))
	linha.append(ate)
	draw_polyline(linha, Color(cor, luz * 0.55), 8.0)
	draw_polyline(linha, Color(Color.WHITE, luz), 3.0)
