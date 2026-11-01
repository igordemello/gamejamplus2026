extends Marker2D

# lugar fixo onde certos fantasmas podem ser colocados (ex.: grupo "armadura" pro cavaleiro)

@export var raio: float = 70.0

var ocupante: Node2D
var tempo: float = 0.0

func livre() -> bool:
	return not is_instance_valid(ocupante)

func _process(delta: float) -> void:
	tempo += delta
	queue_redraw()

# brilha enquanto o jogador arrasta um card de fantasma que só pode ficar nesses pontos
func deve_brilhar() -> bool:
	var viewport = get_viewport()
	if not viewport.gui_is_dragging() or not livre():
		return false
	var card = viewport.gui_get_drag_data()
	return card is Object and "pontos_spawn" in card and card.pontos_spawn != &"" and is_in_group(card.pontos_spawn)

func _draw() -> void:
	if not deve_brilhar():
		return
	var brilho = 0.6 + 0.3 * sin(tempo * 6.0)
	draw_circle(Vector2.ZERO, 30, Color(1, 1, 1, brilho * 0.3), true, -1.0, true)
	draw_arc(Vector2.ZERO, 30, 0, TAU, 48, Color(1, 1, 1, brilho), 3.0, true)
