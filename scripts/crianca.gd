extends Fantasma

@export var raio_choro: float = 150.0
@export var medo_choro: int = 60
@export var duracao_choro: float = 1.5

@onready var lagrimas: AnimatedSprite2D = $lagrimas

# fica parada no canto e só chora se tiver exatamente uma pessoa perto
func chorar() -> bool:
	var perto = get_tree().get_nodes_in_group("npc").filter(
		func(npc): return global_position.distance_to(npc.global_position) <= raio_choro
	)
	if perto.size() != 1:
		return false

	# some por tempo, assim funciona com a animação em loop ou não
	lagrimas.show()
	lagrimas.play("chorar")
	onomatopeia("BUAAA!", Color(0.6, 0.85, 1))
	GameManager.som.tocar("crianca", duracao_choro, 0.3)
	get_tree().create_timer(duracao_choro).timeout.connect(lagrimas.hide)
	perto[0].tomar_susto("choro", medo_choro, self)
	return true
