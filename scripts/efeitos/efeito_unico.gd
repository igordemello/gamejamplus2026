extends GPUParticles3D

# partícula de uma vez só (estilhaços, fumaça): dispara junto com as filhas e some sozinha.
# uso: instancie, add_child em fase.mundo e ponha global_position (antes ou depois do add_child);
# ela só começa a emitir no quadro seguinte, então a posição já está certa
func _ready() -> void:
	finished.connect(queue_free)
	await get_tree().process_frame
	restart()
	for filha in get_children():
		if filha is GPUParticles3D:
			filha.restart()
