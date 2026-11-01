extends Sprite2D

@export var raio: float = 30.0
@export var tempo_vomitando: float = 1.5
@export var textura_vomito: Texture2D

var medo: int = 15
# a geleia que soltou a comida (conta como susto dela)
var fantasma: Fantasma

func _physics_process(_delta: float) -> void:
	for npc in get_tree().get_nodes_in_group("npc"):
		if global_position.distance_to(npc.global_position) <= raio:
			Onomatopeia.soltar("BLERGH!", global_position + Vector2(0, -60), Color(0.6, 1, 0.4))
			GameManager.som.tocar("geleia_regurgitar")
			npc.tomar_susto("comida", medo, fantasma)
			npc.atordoar(tempo_vomitando)
			# vira a poça de vômito e some quando ele termina de vomitar
			texture = textura_vomito
			set_physics_process(false)
			get_tree().create_timer(tempo_vomitando).timeout.connect(queue_free)
			return
