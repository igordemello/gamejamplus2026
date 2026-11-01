extends ColorRect

# pós-processamento da casa (assets/pos.gdshader). chutar() dá um tranco de aberração cromática
@export var aberracao_base: float = 1.0
var chute: float = 0.0

func chutar(forca: float) -> void:
	chute = maxf(chute, forca)

func _process(delta: float) -> void:
	# em tempo real, senão o tranco fica parado no hitstop
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	chute = move_toward(chute, 0.0, 14.0 * real)
	material.set_shader_parameter("aberracao", aberracao_base + chute)
