extends CPUParticles2D

# partícula de uma vez só (estilhaços, fumaça): dispara junto com as filhas e some sozinha
func _ready() -> void:
	emitting = true
	for filha in get_children():
		if filha is CPUParticles2D:
			filha.emitting = true
	finished.connect(queue_free)
