extends Node2D

# reflexos do globo de espelhos girando pelo chão da pista
@export var raio: Vector2 = Vector2(230, 130)
@export var quantidade: int = 28
@export var voltas_por_segundo: float = 0.08

# (ângulo, distância do meio de 0 a 1) de cada reflexo
var reflexos: Array[Vector2] = []
var tempo: float = 0.0

func _ready() -> void:
	for i in quantidade:
		reflexos.append(Vector2(randf() * TAU, sqrt(randf())))

func _process(delta: float) -> void:
	tempo += delta
	queue_redraw()

func _draw() -> void:
	for r in reflexos:
		var a = r.x + tempo * voltas_por_segundo * TAU
		var p = (Vector2(cos(a) * raio.x, sin(a) * raio.y) * r.y).round()
		var brilho = 0.5 + 0.5 * sin(tempo * 4.0 + r.x * 9.0)
		draw_rect(Rect2(p, Vector2(3, 3)), Color(1, 1, 1, 0.25 + 0.5 * brilho))
