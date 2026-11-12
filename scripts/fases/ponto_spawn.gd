extends Marker3D

# lugar fixo onde certos fantasmas podem ser colocados (grupo "armadura" pro cavaleiro, "lareira" pra caveira)

# distância do mouse (metros) que ainda conta como em cima do ponto
@export var raio: float = 0.8

var ocupante: Node3D
var tempo: float = 0.0
var silhueta: Sprite3D

func livre() -> bool:
	return not is_instance_valid(ocupante)

# arrastando uma carta que só cabe aqui, mostra o fantasma em branco e meio transparente no lugar
func _process(delta: float) -> void:
	tempo += delta
	var card = card_que_serve()
	if card == null:
		if silhueta:
			silhueta.hide()
		return
	if silhueta == null:
		silhueta = Sprite3D.new()
		silhueta.material_override = ShaderMaterial.new()
		silhueta.material_override.shader = preload("res://assets/alma.gdshader")
		add_child(silhueta)
	silhueta.texture = card.silhueta
	silhueta.material_override.set_shader_parameter("texture_albedo", card.silhueta)
	silhueta.pixel_size = card.silhueta_pixel
	silhueta.offset = card.silhueta_offset
	silhueta.material_override.set_shader_parameter("opacidade", 0.3 + 0.15 * sin(tempo * 5.0))
	silhueta.show()

func card_que_serve():
	var viewport = get_viewport()
	if not viewport.gui_is_dragging() or not livre():
		return null
	var card = viewport.gui_get_drag_data()
	if card is Object and "pontos_spawn" in card and card.pontos_spawn != &"" and is_in_group(card.pontos_spawn):
		return card
	return null
