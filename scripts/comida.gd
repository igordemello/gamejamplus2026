extends Sprite2D

@export var raio: float = 40.0
# quem estiver a essa distância sente o cheiro e vem comer (senão ficava lá até alguém passar por acaso)
@export var raio_cheiro: float = 200.0
@export var tempo_vomitando: float = 1.5
@export var textura_vomito: Texture2D

var medo: int = 15
# a geleia que soltou a comida (conta como susto dela)
var fantasma: Fantasma
# quem já está vindo
var quem_vem: Node2D
var proximo_cheiro: float = 0.0

func _physics_process(delta: float) -> void:
	proximo_cheiro -= delta
	if proximo_cheiro <= 0.0:
		proximo_cheiro = 0.5
		chamar_alguem()
	for npc in get_tree().get_nodes_in_group("npc"):
		if global_position.distance_to(npc.global_position) <= raio:
			Onomatopeia.soltar("BLERGH!", global_position + Vector2(0, -60), Color(0.6, 1, 0.4))
			GameManager.som.tocar("geleia_regurgitar")
			npc.indo_comer = null
			npc.tomar_susto("comida", medo, fantasma)
			npc.atordoar(tempo_vomitando)
			# vira a poça de vômito e some quando ele termina de vomitar
			texture = textura_vomito
			set_physics_process(false)
			get_tree().create_timer(tempo_vomitando).timeout.connect(queue_free)
			return

# o mais perto que pode vir (ninguém fugindo, parado ou correndo) anda até aqui
func chamar_alguem() -> void:
	if is_instance_valid(quem_vem) and quem_vem.is_in_group("npc") and quem_vem.indo_comer == self:
		return
	quem_vem = null
	var menor = raio_cheiro
	for npc in get_tree().get_nodes_in_group("npc"):
		var distancia = global_position.distance_to(npc.global_position)
		if distancia < menor and npc.pode_ir_comer():
			menor = distancia
			quem_vem = npc
	if quem_vem:
		quem_vem.ir_comer(self)
