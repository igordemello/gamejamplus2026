extends Fantasma

@export var alcance_bafo: float = 350.0
# metade da abertura do cone, em graus
@export var abertura_bafo: float = 35.0
@export var medo_bafo: int = 10
@export var paralisia_bafo: float = 2.0
@export var nuvens_bafo: int = 6

# dentro da casa ele vai bem devagar; lá fora, só se reposicionando, anda mais rápido
@export var velocidade: float = 75.0
@export var velocidade_fora: float = 150.0
# distância andando (contornando a casa e entrando pela porta), não em linha reta
@export var alcance_arranhao: float = 2500.0
@export var tempo_max_perseguindo: float = 30.0
@export var distancia_arranhao: float = 30.0
@export var medo_arranhao: int = 20
# quadro da animação em que a garra desce
@export var quadro_arranhao: int = 4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
# camadas 1 (casa) e 2 (navegacao_fora + link da porta): os NPCs só usam a 1
@onready var agente: NavigationAgent2D = $NavigationAgent2D

var alvo: Npc
var perseguindo: bool = false
var tempo_perseguindo: float = 0.0
var tempo_andando: float = 0.0
var voltando: bool = false
# onde estava quando saiu pra arranhar; volta pra cá depois
var casa: Vector2

func _ready() -> void:
	sprite.frame_changed.connect(_on_quadro_mudou)
	sprite.animation_finished.connect(_on_animacao_acabou)

func _process(delta: float) -> void:
	super(delta)
	# andando ele cambaleia de um lado pro outro
	tempo_andando += delta
	var andando = andando_atras() or voltando
	sprite.rotation = sin(tempo_andando * 5.0) * 0.12 if andando else 0.0
	sprite.speed_scale = 2.0 if andando else 1.0

func _physics_process(delta: float) -> void:
	if andando_atras():
		perseguir(delta)
	elif voltando and sprite.animation == &"parado":
		andar_ate(casa, velocidade_fora * delta)
		if global_position.distance_to(casa) <= 2.0:
			global_position = casa
			voltando = false

func perseguir(delta: float) -> void:
	tempo_perseguindo += delta
	if not is_instance_valid(alvo) or tempo_perseguindo > tempo_max_perseguindo:
		perseguindo = false
		voltando = true
		return
	if global_position.distance_to(alvo.global_position) <= distancia_arranhao:
		# segura a pessoa até a garra descer
		sprite.flip_h = alvo.global_position.x > global_position.x
		var frames = sprite.sprite_frames
		alvo.atordoar(frames.get_frame_count("arranhao") / frames.get_animation_speed("arranhao"))
		sprite.play("arranhao")
	else:
		var lento = not GameManager.house.fora_de_casa(global_position)
		andar_ate(alvo.global_position, (velocidade if lento else velocidade_fora) * delta)

# segue o caminho da navegação: lá fora contorna a casa e entra pela porta da frente
func andar_ate(destino: Vector2, passo: float) -> void:
	if agente.target_position.distance_to(destino) > 8.0:
		agente.target_position = destino
	var proximo = agente.get_next_path_position()
	if agente.is_navigation_finished():
		proximo = destino
	if absf(proximo.x - global_position.x) > 1.0:
		sprite.flip_h = proximo.x > global_position.x
	global_position = global_position.move_toward(proximo, passo)

# quanto ele anda até lá pelo caminho (INF se não tiver caminho)
func distancia_andando(ate: Vector2) -> float:
	var caminho = NavigationServer2D.map_get_path(agente.get_navigation_map(), global_position, ate, true, agente.navigation_layers)
	if caminho.is_empty() or caminho[-1].distance_to(ate) > distancia_arranhao:
		return INF
	var total = 0.0
	for i in range(1, caminho.size()):
		total += caminho[i - 1].distance_to(caminho[i])
	return total

func andando_atras() -> bool:
	return perseguindo and sprite.animation == &"parado"

func ocupado() -> bool:
	return sprite.animation != &"parado" or perseguindo

func npcs_perto(raio: float) -> Array:
	var perto = get_tree().get_nodes_in_group("npc").filter(
		func(npc): return global_position.distance_to(npc.global_position) <= raio
	)
	perto.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return perto

# bafo num cone virado pra pessoa mais perto: todo mundo dentro se assusta e fica paralisado
func bafo_do_medo() -> bool:
	if ocupado():
		return false
	var perto = npcs_perto(alcance_bafo)
	if perto.is_empty():
		return false
	var direcao = global_position.direction_to(perto[0].global_position)
	sprite.flip_h = direcao.x > 0.0
	for npc in perto:
		if absf(rad_to_deg(direcao.angle_to(global_position.direction_to(npc.global_position)))) <= abertura_bafo:
			npc.tomar_susto("bafo", medo_bafo)
			npc.atordoar(paralisia_bafo)
	soltar_nuvens(direcao)
	return true

# nuvens do bafo uma atrás da outra pelo cone, maiores e mais abertas quanto mais longe
func soltar_nuvens(direcao: Vector2) -> void:
	var y_sort = GameManager.house.y_sort
	var boca = global_position + Vector2(0, -40)
	for i in nuvens_bafo:
		var distancia = alcance_bafo * (0.2 + 0.8 * i / float(nuvens_bafo - 1))
		var lado = direcao.orthogonal() * randf_range(-1.0, 1.0) * distancia * tan(deg_to_rad(abertura_bafo)) * 0.6
		var nuvem = AnimatedSprite2D.new()
		nuvem.sprite_frames = sprite.sprite_frames
		nuvem.animation = &"bafo"
		nuvem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		nuvem.z_index = 1
		nuvem.visible = false
		nuvem.position = y_sort.to_local(boca + direcao * distancia + lado)
		nuvem.scale = Vector2.ONE * (1.0 + distancia / alcance_bafo * 2.2)
		nuvem.rotation = randf() * TAU
		y_sort.add_child(nuvem)
		nuvem.animation_finished.connect(nuvem.queue_free)
		var tween = nuvem.create_tween()
		tween.tween_interval(i * 0.06)
		tween.tween_callback(nuvem.show)
		tween.tween_callback(nuvem.play.bind("bafo"))

# vai arrastando os pés até a pessoa mais perto (pelo caminho, sem atravessar parede) e arranha
func arranhao() -> bool:
	if ocupado():
		return false
	var mais_perto: Npc = null
	var menor = alcance_arranhao
	for npc in get_tree().get_nodes_in_group("npc"):
		var distancia = distancia_andando(npc.global_position)
		if distancia <= menor:
			menor = distancia
			mais_perto = npc
	if mais_perto == null:
		return false
	alvo = mais_perto
	perseguindo = true
	tempo_perseguindo = 0.0
	# se já estava voltando, a casa continua sendo a de antes
	if not voltando:
		casa = global_position
	voltando = false
	return true

func _on_quadro_mudou() -> void:
	if sprite.animation == &"arranhao" and sprite.frame == quadro_arranhao and is_instance_valid(alvo):
		alvo.tomar_susto("arranhao", medo_arranhao)
		GameManager.house.camera.tremer(4.0)

func _on_animacao_acabou() -> void:
	if sprite.animation == &"arranhao":
		perseguindo = false
		voltando = true
	sprite.play("parado")
