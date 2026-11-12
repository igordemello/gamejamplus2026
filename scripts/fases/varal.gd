extends Node3D

# varal de luzinhas: cada filho MeshInstance3D é uma lâmpada, e elas acendem de três em três
# correndo pelo fio

@export var velocidade: float = 3.0

var tempo: float = 0.0

func _process(delta: float) -> void:
	tempo += delta
	var passo = int(tempo * velocidade)
	var i = 0
	for lampada in get_children():
		if lampada is MeshInstance3D:
			var aceso = 1.0 if (i + passo) % 3 == 0 else 0.35
			lampada.material_override.emission_energy_multiplier = 0.8 + 3.0 * aceso
			i += 1
