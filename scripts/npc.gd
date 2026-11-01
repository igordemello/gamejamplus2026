extends CharacterBody2D
class_name Npc

@export var house: House
# animações desse npc (gotica.tres, cheerleader.tres...), precisa ter "andar" desenhada virada pra direita
@export var visual: SpriteFrames

@export var speed: float = 150.0
@export var acceleration: float = 300.0
@export var deceleration: float = 450.0

@export var min_time: float = 15.0
@export var max_time: float = 25.0

@export var min_wait_time: float = 3.0
@export var max_wait_time: float = 6.0

var current_region: NavigationRegion2D

var remaining_time: float = 0.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var altura_sprite: float = sprite.position.y
@onready var escala_sprite: Vector2 = sprite.scale
var tween_pulo: Tween

# respiração parado: quantos pixels de tela o desenho cresce e a velocidade (assustado fica ofegante)
@export var pixels_respiracao: int = 2
@export var velocidade_respiracao: float = 2.0
@export var velocidade_ofegante: float = 7.0
# cada um começa num ponto da respiração, senão todos respiram juntos
var tempo_respiracao: float = randf() * TAU

var navigation_ready: bool = false

var waiting: bool = false
var wait_time: float = 0.0

var traveling_to_region: bool = false

@export var nivel_medo: int = 0
@export_range(0.0, 100.0) var barra_susto: float = 0.0

enum Estado {
	Normal,
	Assustado,
	Infarta,
	Foge
}

var current_estado = Estado.Normal

@export var reducao_por_nivel: float = 0.1
var last_susto: String = ""

@export var distancia_fuga: float = 15.0

@export var velocidade_correr: float = 300.0
@export var duracao_stun: float = 3.0

# quando diferente de zero o npc corre reto até bater numa parede e fica atordoado
var direcao_correr: Vector2 = Vector2.ZERO
var tempo_stun: float = 0.0
# quanto da barra de susto cai por segundo enquanto está atordoado
var dreno_medo: float = 0.0
# enquanto for > 0 anda com o dobro da velocidade (fugindo pra outro cômodo)
var tempo_correndo: float = 0.0

func _ready() -> void:
	if visual:
		sprite.sprite_frames = visual
	await initialize_navigation()
	choose_random_destination()
	navigation_ready = true

func _process(delta: float) -> void:
	$Label.text = str(nivel_medo) +" - "+ str(roundi(barra_susto)) + "/100"

	# parado fica no primeiro quadro; andando vira pro lado que está indo
	if velocity.length() > 10.0:
		sprite.play("andar")
		sprite.scale = escala_sprite
		if absf(velocity.x) > 5.0:
			sprite.flip_h = velocity.x < 0.0
	else:
		sprite.stop()
		respirar(delta)

func _physics_process(delta: float) -> void:
	if not navigation_ready:
		return

	# STUN / CORRENDO
	if tempo_stun > 0.0:
		tempo_stun -= delta
		barra_susto = maxf(barra_susto - dreno_medo * delta, 0.0)
		return

	tempo_correndo = maxf(tempo_correndo - delta, 0.0)

	if direcao_correr != Vector2.ZERO:
		if house.eh_parede(global_position + direcao_correr * 20.0):
			direcao_correr = Vector2.ZERO
			atordoar(duracao_stun)
			return
		velocity = direcao_correr * velocidade_correr
		move_and_slide()
		return

	# FUGA
	if current_estado == Estado.Foge:
		if global_position.distance_to(house.ponto_fuga.global_position) <= distancia_fuga:
			queue_free()
			return

		if agent.is_navigation_finished():
			velocity = velocity.move_toward(
				Vector2.ZERO,
				deceleration * delta
			)
			move_and_slide()
			return

		mover_npc(delta)
		return

	# PASSEIO NORMAL
	if not traveling_to_region:
		remaining_time -= delta

		if remaining_time <= 0.0:
			choose_random_destination()
			return

	if agent.is_navigation_finished():
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)
		move_and_slide()

		if traveling_to_region:
			traveling_to_region = false
			remaining_time = randf_range(min_time, max_time)
			waiting = false

		if not waiting:
			waiting = true
			wait_time = randf_range(min_wait_time, max_wait_time)

		wait_time -= delta

		if wait_time <= 0.0:
			waiting = false
			choose_wander_destination()

		return

	mover_npc(delta)

func mover_npc(delta: float) -> void:
	var next_point = agent.get_next_path_position()
	var direction = global_position.direction_to(next_point)

	var target_velocity = direction * speed * (2.0 if tempo_correndo > 0.0 else 1.0)

	velocity = velocity.move_toward(
		target_velocity,
		acceleration * delta
	)

	move_and_slide()

func initialize_navigation() -> void:
	var navigation_map = agent.get_navigation_map()

	while NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
		await get_tree().physics_frame
	

func choose_random_destination() -> void:
	if house.regionsHouse.is_empty():
		return

	var available_regions = house.regionsHouse.filter(
		func(region): return region != current_region
	)

	if available_regions.is_empty():
		available_regions = house.regionsHouse

	current_region = available_regions.pick_random()
	traveling_to_region = true
	waiting = false

	choose_wander_destination()

func get_random_point_in_region(region: NavigationRegion2D) -> Vector2:
	var nav_polygon = region.navigation_polygon

	if nav_polygon == null:
		return region.global_position

	var vertices = nav_polygon.get_vertices()
	var triangles: Array = []
	var total_area: float = 0.0

	for i in range(nav_polygon.get_polygon_count()):
		var indices = nav_polygon.get_polygon(i)

		if indices.size() < 3:
			continue

		var a = vertices[indices[0]]

		for j in range(1, indices.size() - 1):
			var b = vertices[indices[j]]
			var c = vertices[indices[j + 1]]

			var area = abs((b - a).cross(c - a)) / 2.0

			if area <= 0.0:
				continue

			triangles.append([a, b, c, area])
			total_area += area

	if total_area <= 0.0:
		return region.global_position

	var random_area = randf() * total_area

	for triangle in triangles:
		random_area -= triangle[3]

		if random_area <= 0.0:
			var a = triangle[0]
			var b = triangle[1]
			var c = triangle[2]

			var r1 = sqrt(randf())
			var r2 = randf()

			var local_point = (
				(1.0 - r1) * a
				+ r1 * (1.0 - r2) * b
				+ r1 * r2 * c
			)

			return region.to_global(local_point)

	return region.global_position

func choose_wander_destination() -> void:
	if current_region == null:
		return

	var desired_position = get_random_point_in_region(current_region)

	agent.target_position = desired_position

func tomar_susto(susto: String, pontosDeSusto: int) -> void:
	# TEM QUE LEMBRAR DE TIRAR ESSA PORRA HEIN
	if susto == last_susto:
		return
	if pontosDeSusto <= 0:
		return

	var multiplicador_nivel = 1.0 / (
		1.0 + nivel_medo * reducao_por_nivel
	)

	var pontos_recebidos = pontosDeSusto * multiplicador_nivel * house.intensidade_susto(global_position)

	if susto != "objeto":
		last_susto = susto

	pular_de_susto()

	barra_susto = minf(barra_susto + pontos_recebidos, 100.0)

	if barra_susto >= 100.0:
		barra_susto = 0.0
		nivel_medo += 1
		GameManager.sustos += 1
		mostrar_mais_um()
		house.camera.tremer(3.0)
		if nivel_medo == 1 or nivel_medo == 2:
			current_estado = Estado.Normal
		elif nivel_medo == 3 or nivel_medo == 4:
			current_estado = Estado.Assustado
		elif nivel_medo >= 5:
			fugir() # ou foge, vou implementar a lógica disso aqui depois


# pulinho de susto, só no desenho (a posição do npc não muda)
func pular_de_susto() -> void:
	if tween_pulo:
		tween_pulo.kill()
	tween_pulo = create_tween()
	tween_pulo.tween_property(sprite, "position:y", altura_sprite - 14.0, 0.08).set_ease(Tween.EASE_OUT)
	tween_pulo.tween_property(sprite, "position:y", altura_sprite, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# pisca claro na hora do susto
	sprite.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)

# o peito sobe e desce esticando o desenho pra cima (o pivô do sprite fica nos pés).
# cresce sempre em pixel inteiro de tela: escala quebrada em pixel art fica piscando
func respirar(delta: float) -> void:
	var velocidade = velocidade_ofegante if current_estado == Estado.Assustado else velocidade_respiracao
	tempo_respiracao += delta * velocidade
	var pixels = roundf((sin(tempo_respiracao) + 1.0) / 2.0 * pixels_respiracao)
	var altura = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_height()
	sprite.scale.y = escala_sprite.y + pixels / altura

# "+1" subindo em cima da cabeça quando o medo sobe de nível
func mostrar_mais_um() -> void:
	var texto = Label.new()
	texto.text = "+1"
	texto.z_index = 1
	texto.add_theme_font_size_override("font_size", 28)
	texto.add_theme_constant_override("outline_size", 8)
	texto.add_theme_color_override("font_outline_color", Color.BLACK)
	texto.position = Vector2(-14, -120)
	add_child(texto)
	var tween = texto.create_tween()
	tween.tween_property(texto, "position:y", texto.position.y - 40.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(texto, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tween.tween_callback(texto.queue_free)

func atordoar(tempo: float, dreno: float = 0.0) -> void:
	tempo_stun = tempo
	dreno_medo = dreno
	velocity = Vector2.ZERO

# sai correndo pra algum outro cômodo
func correr_para_outro_comodo(tempo: float) -> void:
	choose_random_destination()
	tempo_correndo = tempo

func fugir() -> void:
	if current_estado == Estado.Foge:
		return

	if house.ponto_fuga == null:
		push_error("Ponto de fuga não configurado!")
		return

	current_estado = Estado.Foge

	waiting = false
	traveling_to_region = false

	agent.target_position = house.ponto_fuga.global_position
