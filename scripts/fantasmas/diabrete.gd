# Diabrete: voa até um objeto quebrável, ergue, solta e quebra assustando quem está perto.
extends Fantasma

const ESTILHACOS = preload("res://scene/efeitos/estilhacos.tscn")

@export var velocidade: float = 2.5
# até onde ele vai buscar um objeto quebrável
@export var alcance: float = 10.2
@export var altura_levantar: float = 0.45

@export var medo_quebra: int = 30
@export var raio_quebra: float = 2.5
@export var max_assustados: int = 4
@export var tempo_reaparecer: float = 30.0

@onready var sprite: SpritePersonagem = $sprite
# onde ele segura o objeto (filho do sprite, sobe junto)
@onready var peito: Marker3D = $sprite/peito
@onready var brasas: GPUParticles3D = $sprite/brasas
@onready var altura_voo: float = sprite.position.y

var alvo: Node3D
var segurando: bool = false
# quanto subiu de verdade com o objeto (menos que altura_levantar se tiver parede em cima)
var altura_subida: float = 0.0

func _physics_process(delta: float) -> void:
	if segurando or not is_instance_valid(alvo):
		return
	if global_position.distance_to(alvo.global_position) <= 0.05:
		pegar()
	else:
		andar_pelo_caminho(alvo.global_position, velocidade * delta)

# voa até o objeto quebrável mais perto
func quebrar_objetos() -> bool:
	if segurando or is_instance_valid(alvo):
		return false
	alvo = objeto_mais_perto()
	if alvo == null:
		return false
	# já é dele: outro diabrete não vem atrás do mesmo objeto (quebrado, ele fica invisível até reaparecer)
	alvo.remove_from_group("quebravel")
	return true

# o susto sai onde o objeto cair: mostra em volta do objeto que ele pegaria
func area_de(_acao: Acao) -> Dictionary:
	var objeto = alvo if is_instance_valid(alvo) else objeto_mais_perto()
	return {"centro": objeto.global_position, "raio": raio_quebra} if objeto else {}

func ocupado() -> bool:
	return segurando or is_instance_valid(alvo)

func objeto_mais_perto() -> Node3D:
	var mais_perto: Node3D = null
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
	# guarda o estado no chão, antes de carregar, girar e deformar o objeto
	var pai_original = objeto.get_parent()
	var transform_original = objeto.transform
	var restaurar = func():
		objeto.reparent(pai_original)
		objeto.transform = transform_original
		objeto.add_to_group("quebravel")
		if objeto.has_method("reaparecer"):
			objeto.reaparecer()
	var chao = objeto.global_position
	objeto.reparent(peito)
	objeto.position = Vector3(0, -0.2, 0)
	sprite.play("carregar")
	brasas.emitting = true

	# também não atravessa parede subindo
	altura_subida = altura_levantar
	while altura_subida > 0.0 and GameManager.fase.eh_parede(global_position + Vector3.UP * (altura_voo + altura_subida)):
		altura_subida -= 0.09
	altura_subida = maxf(altura_subida, 0.0)
	# sobe só o desenho: a raiz fica no chão
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", altura_voo + altura_subida, 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_callback(soltar.bind(objeto, chao, restaurar))

func soltar(objeto: Node3D, chao: Vector3, restaurar: Callable) -> void:
	objeto.reparent(GameManager.fase.mundo)
	sprite.play("voar")
	brasas.emitting = false

	var queda = create_tween()
	queda.tween_property(objeto, "global_position", chao, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	queda.parallel().tween_property(objeto, "rotation", Vector3(0, 0, randf_range(-1.5, 1.5)), 0.3)
	queda.tween_callback(quebrar.bind(objeto, restaurar))

	# volta pra altura de antes
	var descida = create_tween()
	descida.tween_property(sprite, "position:y", altura_voo, 0.4)

func quebrar(objeto: Node3D, restaurar: Callable) -> void:
	var assustados = get_tree().get_nodes_in_group("npc").filter(
		func(npc): return objeto.global_position.distance_to(npc.global_position) <= raio_quebra
	)
	assustados.sort_custom(func(a, b): return objeto.global_position.distance_to(a.global_position) < objeto.global_position.distance_to(b.global_position))
	Onomatopeia.soltar("CRASH!", objeto.global_position + Vector3(0, 0.45, 0), Color(1, 0.6, 0.25), 4.0)
	GameManager.som.tocar("diabrete_quebra")
	var atingidos = assustados.slice(0, max_assustados)
	var medo = medo_em_grupo(medo_quebra, atingidos.size())
	sentir_grupo(atingidos, objeto.global_position)
	for npc in atingidos:
		npc.tomar_susto("quebra", medo, self)

	var cacos = ESTILHACOS.instantiate()
	GameManager.fase.mundo.add_child(cacos)
	cacos.global_position = objeto.global_position
	GameManager.fase.camera.tremer(6.0)

	# estoura e some
	var tween = objeto.create_tween().set_parallel()
	tween.tween_property(objeto, "scale", Vector3.ZERO, 0.15)
	# conserva o nó invisível para restaurar o mesmo objeto, sem duplicar scripts ou sombras
	tween.chain().tween_interval(tempo_reaparecer)
	tween.chain().tween_callback(restaurar)
	segurando = false
