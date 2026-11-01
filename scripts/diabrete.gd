extends Fantasma

const ESTILHACOS = preload("res://scene/estilhacos.tscn")

@export var velocidade: float = 220.0
# até onde ele vai buscar um objeto quebrável
@export var alcance: float = 900.0
# ponto (local) do peito onde ele segura o objeto
@export var peito: Vector2 = Vector2(0, 3)
@export var altura_levantar: float = 40.0

@export var medo_quebra: int = 25
@export var raio_quebra: float = 180.0
@export var max_assustados: int = 3

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var brasas: CPUParticles2D = $brasas

var alvo: Node2D
var segurando: bool = false
# quanto subiu de verdade com o objeto (menos que altura_levantar se tiver parede em cima)
var altura_subida: float = 0.0

func _physics_process(delta: float) -> void:
	if segurando or not is_instance_valid(alvo):
		return
	var destino = alvo.global_position - peito
	if global_position.distance_to(destino) <= 4.0:
		pegar()
	else:
		andar_pelo_caminho(destino, velocidade * delta)

# voa até o objeto quebrável mais perto
func quebrar_objetos() -> bool:
	if segurando or is_instance_valid(alvo):
		return false
	alvo = objeto_mais_perto()
	return alvo != null

func objeto_mais_perto() -> Node2D:
	var mais_perto: Node2D = null
	for objeto in get_tree().get_nodes_in_group("quebravel"):
		var distancia = global_position.distance_to(objeto.global_position)
		if distancia <= alcance and (mais_perto == null or distancia < global_position.distance_to(mais_perto.global_position)):
			mais_perto = objeto
	return mais_perto

# segura o objeto no peito, sobe e solta
func pegar() -> void:
	segurando = true
	var objeto = alvo
	alvo = null
	objeto.remove_from_group("quebravel")
	# prop que também levita: sai do mouse e volta pro chão antes de ser levado
	if objeto.has_method("ser_pego"):
		objeto.ser_pego()
	var chao = objeto.global_position
	objeto.reparent(self)
	objeto.position = peito
	sprite.play("carregar")
	brasas.emitting = true

	# também não atravessa parede subindo
	altura_subida = altura_levantar
	while altura_subida > 0.0 and GameManager.house.eh_parede(global_position + Vector2(0, -altura_subida)):
		altura_subida -= 8.0
	altura_subida = maxf(altura_subida, 0.0)
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - altura_subida, 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_callback(soltar.bind(objeto, chao))

func soltar(objeto: Node2D, chao: Vector2) -> void:
	objeto.reparent(GameManager.house.y_sort)
	sprite.play("voar")
	brasas.emitting = false

	var queda = create_tween()
	queda.tween_property(objeto, "global_position", chao, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	queda.parallel().tween_property(objeto, "rotation", randf_range(-1.5, 1.5), 0.3)
	queda.tween_callback(quebrar.bind(objeto))

	# volta pra altura de antes
	create_tween().tween_property(self, "global_position:y", global_position.y + altura_subida, 0.4)

func quebrar(objeto: Node2D) -> void:
	var assustados = get_tree().get_nodes_in_group("npc").filter(
		func(npc): return objeto.global_position.distance_to(npc.global_position) <= raio_quebra
	)
	assustados.sort_custom(func(a, b): return objeto.global_position.distance_to(a.global_position) < objeto.global_position.distance_to(b.global_position))
	Onomatopeia.soltar("CRASH!", objeto.global_position + Vector2(0, -40), Color(1, 0.6, 0.25), 4.0)
	GameManager.som.tocar("diabrete_quebra")
	for npc in assustados.slice(0, max_assustados):
		npc.tomar_susto("quebra", medo_quebra, self)

	# posição antes do add_child: os cacos já saem no _ready, e sairiam no canto da casa
	var cacos = ESTILHACOS.instantiate()
	cacos.position = objeto.position
	GameManager.house.y_sort.add_child(cacos)
	GameManager.house.camera.tremer(6.0)

	# estoura e some
	var tween = objeto.create_tween().set_parallel()
	tween.tween_property(objeto, "scale", objeto.scale * 1.6, 0.15)
	tween.tween_property(objeto, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(objeto.queue_free)
	segurando = false
