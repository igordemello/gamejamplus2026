extends Node2D

# teia de aranha num canto. "direcao" é pra onde ela abre, em graus (0 = direita, 90 = baixo)
@export var raio: float = 50.0
@export var direcao: float = 45.0
@export var fios: int = 6
@export var voltas: int = 4
@export var cor: Color = Color(0.85, 0.85, 0.92, 0.45)

func _draw() -> void:
	var angulos = []
	for i in fios:
		angulos.append(deg_to_rad(direcao - 45.0 + 90.0 * i / (fios - 1)))
	for a in angulos:
		draw_line(Vector2.ZERO, (Vector2.from_angle(a) * raio).round(), cor, 1.5)
	for v in range(1, voltas + 1):
		var r = raio * v / (voltas + 0.5)
		var pontos = PackedVector2Array()
		for i in fios:
			pontos.append((Vector2.from_angle(angulos[i]) * r).round())
			# entre dois fios a volta cede um pouco pro canto
			if i < fios - 1:
				pontos.append((Vector2.from_angle((angulos[i] + angulos[i + 1]) / 2.0) * r * 0.84).round())
		draw_polyline(pontos, cor, 1.5)
