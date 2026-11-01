extends CPUParticles2D

# cacos + poeira de um objeto quebrando: dispara uma vez e some sozinho
func _ready() -> void:
	emitting = true
	$poeira.emitting = true
	finished.connect(queue_free)
