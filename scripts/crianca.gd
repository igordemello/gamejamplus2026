extends Fantasma

# no corredor, que não é cômodo, vale esse raio
@export var raio_choro: float = 250.0
@export var medo_choro: int = 36
@export var duracao_choro: float = 1.5

@onready var lagrimas: AnimatedSprite2D = $lagrimas

# as lágrimas só aparecem chorando (na cena elas ficam à mostra pra dar pra editar)
func _ready() -> void:
	lagrimas.hide()

func ocupado() -> bool:
	return lagrimas.visible

func area_de(_acao: Acao) -> Dictionary:
	return area_comodo(raio_choro)

# só chora se tiver exatamente uma pessoa no cômodo dela
func chorar() -> bool:
	var house = GameManager.house
	var comodo = house.comodo_em(global_position)
	var perto = get_tree().get_nodes_in_group("npc").filter(func(npc):
		return house.comodo_em(npc.global_position) == comodo if comodo != "" else global_position.distance_to(npc.global_position) <= raio_choro
	)
	if perto.size() != 1:
		# o motivo aparece em cima dela (a fonte das onomatopeias não tem acento)
		onomatopeia("MUITA GENTE!" if perto.size() > 1 else "NINGUEM AQUI!", Color(0.6, 0.85, 1))
		return false

	# some por tempo, assim funciona com a animação em loop ou não
	lagrimas.show()
	lagrimas.play("chorar")
	onomatopeia("BUAAA!", Color(0.6, 0.85, 1))
	GameManager.som.tocar("crianca", duracao_choro, 0.3)
	get_tree().create_timer(duracao_choro).timeout.connect(lagrimas.hide)
	perto[0].tomar_susto("choro", medo_choro, self)
	return true
