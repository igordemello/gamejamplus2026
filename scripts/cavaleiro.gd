extends Fantasma

@export var raio_espada: float = 150.0
@export var medo_espada: int = 30
@export var tempo_fuga: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.animation_finished.connect(sprite.play.bind("parada"))

func area_de(_acao: Acao) -> Dictionary:
	return area_raio(raio_espada)

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
	onomatopeia("SHING!", Color(0.8, 0.9, 1))
	GameManager.som.tocar("cavaleiro")
	alvo.tomar_susto("espada", medo_espada, self)
	# quem levou a espadada sai de perto
	alvo.correr_para_outro_comodo(tempo_fuga)
	return true
