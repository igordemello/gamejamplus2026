extends Fantasma

@export var raio_espada: float = 110.0
@export var medo_espada: int = 5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.animation_finished.connect(sprite.play.bind("parada"))

# a estátua ataca quem estiver passando mais perto dela
func susto_de_espada() -> bool:
	var alvo: Npc = null
	for npc in get_tree().get_nodes_in_group("npc"):
		var distancia = global_position.distance_to(npc.global_position)
		if distancia <= raio_espada and (alvo == null or distancia < global_position.distance_to(alvo.global_position)):
			alvo = npc
	if alvo == null:
		return false

	sprite.play("atacar")
	alvo.tomar_susto("espada", medo_espada, self)
	return true
