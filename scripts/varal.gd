extends Node2D

# varal de luzinhas de festa: o fio cai entre a posição do nó e "fim" (local),
# e as lâmpadas acendem de três em três, correndo pelo fio
@export var fim: Vector2 = Vector2(400, 0)
@export var caida: float = 30.0
@export var lampadas: int = 12
@export var cores: Array[Color] = [Color(1.0, 0.5, 0.1), Color(0.7, 0.3, 1.0), Color(0.45, 1.0, 0.3)]
# passos por segundo da sequência
@export var velocidade: float = 3.0

var tempo: float = 0.0

func _process(delta: float) -> void:
	tempo += delta
	queue_redraw()

# parábola: cai mais no meio
func ponto(t: float) -> Vector2:
	return fim * t + Vector2(0, caida * 4.0 * t * (1.0 - t))

func _draw() -> void:
	var fio = PackedVector2Array()
	for i in 25:
		fio.append(ponto(i / 24.0).round())
	draw_polyline(fio, Color(0.06, 0.05, 0.07), 2.0)
	var passo = int(tempo * velocidade)
	for i in lampadas:
		var p = ponto((i + 0.5) / lampadas).round()
		var cor: Color = cores[i % cores.size()]
		var aceso = 1.0 if (i + passo) % 3 == 0 else 0.4
		draw_circle(p + Vector2(0, 4), 9.0, Color(cor, 0.16 * aceso))
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 2)), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(p + Vector2(-2, 2), Vector2(4, 5)), Color(cor * (0.35 + 0.75 * aceso), 1.0))
