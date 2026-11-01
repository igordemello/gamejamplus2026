extends Node2D

# abóbora de halloween: a do tileset com a cara entalhada desenhada por cima, acesa por dentro.
# a cara acompanha a chama da luz
@onready var luz = $luz
@onready var rosto: Node2D = $sprite/rosto

const FOGO = Color(1.0, 0.68, 0.12)
const MIOLO = Color(1.0, 0.93, 0.55)

func _ready() -> void:
	rosto.draw.connect(_desenhar_rosto)

func _process(_delta: float) -> void:
	rosto.modulate.a = clampf(luz.energy / luz.energia_base, 0.35, 1.0)

# em pixels da textura, a partir do meio da abóbora
func _desenhar_rosto() -> void:
	for x in [-10.0, 10.0]:
		rosto.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 3), Vector2(x + 5, 3), Vector2(x, -4)]), FOGO)
		rosto.draw_colored_polygon(PackedVector2Array([Vector2(x - 2, 2), Vector2(x + 2, 2), Vector2(x, -1)]), MIOLO)
	rosto.draw_colored_polygon(PackedVector2Array([Vector2(-2, 7), Vector2(2, 7), Vector2(0, 4)]), FOGO)
	# boca com dois dentes pendurados
	var boca = PackedVector2Array([Vector2(-12, 9), Vector2(-7, 10), Vector2(-6, 12), Vector2(-3, 12), Vector2(-2, 10),
		Vector2(2, 10), Vector2(3, 12), Vector2(6, 12), Vector2(7, 10), Vector2(12, 9), Vector2(8, 14), Vector2(0, 16), Vector2(-8, 14)])
	rosto.draw_colored_polygon(boca, FOGO)
