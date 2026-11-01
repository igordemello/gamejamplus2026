extends Marker2D

# lugar fixo onde certos fantasmas podem ser colocados (ex.: grupo "armadura" pro cavaleiro)

@export var raio: float = 70.0

var ocupante: Node2D
var tempo: float = 0.0

func livre() -> bool:
	return not is_instance_valid(ocupante)

# enquanto arrasta um card que só cabe nesses pontos, mostra o desenho do fantasma
# em branco e meio transparente onde ele vai ficar
var silhueta: Sprite2D

func _process(delta: float) -> void:
	tempo += delta
	var card = card_que_serve()
	if card == null:
		if silhueta:
			silhueta.hide()
		return
	if silhueta == null:
		silhueta = Sprite2D.new()
		silhueta.material = ShaderMaterial.new()
		silhueta.material.shader = preload("res://assets/alma.gdshader")
		silhueta.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		silhueta.z_index = 1
		add_child(silhueta)
	silhueta.texture = card.silhueta
	silhueta.scale = card.silhueta_escala
	silhueta.position = card.silhueta_posicao
	silhueta.offset = card.silhueta_offset
	silhueta.modulate.a = 0.3 + 0.15 * sin(tempo * 5.0)
	silhueta.show()

func card_que_serve():
	var viewport = get_viewport()
	if not viewport.gui_is_dragging() or not livre():
		return null
	var card = viewport.gui_get_drag_data()
	if card is Object and "pontos_spawn" in card and card.pontos_spawn != &"" and is_in_group(card.pontos_spawn):
		return card
	return null
