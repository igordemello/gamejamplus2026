extends CharacterBody2D
class_name Npc

@export var house: House
# animações desse npc (gotica.tres, cheerleader.tres...), precisa ter "andar" desenhada virada pra direita
@export var visual: SpriteFrames

@export var speed: float = 150.0
@export var acceleration: float = 300.0
@export var deceleration: float = 450.0

# gosto pessoal: a atividade da festa que ele escolhe mais vezes
@export_enum("aleatória", "dançar", "beber", "conversar", "descansar") var preferencia: String = "aleatória"
# chance de, em vez de ir pra um ponto da festa, só dar uma volta por algum cômodo
@export var chance_zanzar: float = 0.1

# ponto da festa (ponto_festa.gd) onde ele está ou pra onde está indo
var ponto
var ultimo_ponto
# quanto tempo ainda fica fazendo o que está fazendo depois de chegar
var tempo_atividade: float = 0.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var altura_sprite: float = sprite.position.y
@onready var escala_sprite: Vector2 = sprite.scale
var tween_pulo: Tween
# estica/amassa do susto, multiplica a escala do desenho
var deformacao: Vector2 = Vector2.ONE
var exclamacao: Label
var tween_exclamacao: Tween
# barrinha de medo em cima da cabeça (desenhada no sinal draw)
var medidor: Node2D
var barra_mostrada: float = 0.0
var alfa_medidor: float = 0.0
# chegou na saída e está sumindo
var saindo: bool = false

# o fantasma que mata esse npc do coração: vem do visual (metadata infarto_tipo e infarto_tier)
var infarto_tipo: String = ""
var infarto_tier: int = 0
# sustos a mais (além do +1 do nível) quando ele infarta
@export var bonus_infarto: int = 2

# respiração parado: quantos pixels de tela o desenho cresce e a velocidade (assustado fica ofegante)
@export var pixels_respiracao: int = 4
@export var velocidade_respiracao: float = 2.0
@export var velocidade_ofegante: float = 7.0
# cada um começa num ponto da respiração, senão todos respiram juntos
var tempo_respiracao: float = randf() * TAU

var navigation_ready: bool = false

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
		# desenho menor que os outros (psicopata) vem com metadata "escala" no .tres
		escala_sprite *= visual.get_meta("escala", 1.0)
		sprite.scale = escala_sprite
	infarto_tipo = sprite.sprite_frames.get_meta("infarto_tipo", "")
	infarto_tier = sprite.sprite_frames.get_meta("infarto_tier", 0)
	medidor = Node2D.new()
	medidor.z_index = 2
	medidor.position = Vector2(0, -90)
	add_child(medidor)
	medidor.draw.connect(_desenhar_medidor)
	if preferencia == "aleatória":
		preferencia = ["dançar", "beber", "conversar", "descansar"].pick_random()
	# cada um no seu passo
	speed *= randf_range(0.85, 1.15)
	await initialize_navigation()
	# já está na festa: fica um tempo onde foi colocado antes de sair, cada um no seu tempo
	agent.target_position = global_position
	tempo_atividade = randf_range(0.0, 20.0)
	navigation_ready = true

func _process(delta: float) -> void:
	$Label.text = str(nivel_medo) +" - "+ str(roundi(barra_susto)) + "/100"
	if current_estado == Estado.Infarta:
		processar_infarto(delta)
		return

	# a barra enche e esvazia suave; o medidor aparece quando tem algum medo
	barra_mostrada = lerpf(barra_mostrada, barra_susto, minf(12.0 * delta, 1.0))
	alfa_medidor = move_toward(alfa_medidor, 1.0 if barra_susto > 0.0 or nivel_medo > 0 else 0.0, 4.0 * delta)
	medidor.scale = medidor.scale.lerp(Vector2.ONE, minf(10.0 * delta, 1.0))
	medidor.queue_redraw()

	# parado fica no primeiro quadro; andando vira pro lado que está indo
	if velocity.length() > 10.0:
		sprite.play("andar")
		# correndo ou fugindo as pernas vão no dobro
		sprite.speed_scale = 2.0 if tempo_correndo > 0.0 or current_estado == Estado.Foge else 1.0
		sprite.scale = escala_sprite * deformacao
		if absf(velocity.x) > 5.0:
			sprite.flip_h = velocity.x < 0.0
	else:
		sprite.stop()
		respirar(delta)
		olhar_pro_ponto()

func _physics_process(delta: float) -> void:
	if not navigation_ready or current_estado == Estado.Infarta:
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
			sair_da_festa()
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

	# FESTA
	if agent.is_navigation_finished():
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)
		move_and_slide()

		tempo_atividade -= delta
		if tempo_atividade <= 0.0:
			escolher_atividade()
		return

	mover_npc(delta)

func mover_npc(delta: float) -> void:
	var next_point = agent.get_next_path_position()
	var direction = global_position.direction_to(next_point)

	var target_velocity = direction * speed * (2.0 if tempo_correndo > 0.0 or current_estado == Estado.Foge else 1.0)

	velocity = velocity.move_toward(
		target_velocity,
		acceleration * delta
	)

	move_and_slide()

func initialize_navigation() -> void:
	var navigation_map = agent.get_navigation_map()

	while NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
		await get_tree().physics_frame
	

# escolhe o que fazer agora: quase sempre um ponto da festa com vaga (o gosto dele pesa mais),
# às vezes só dar uma volta. outro_comodo = tem que ser longe do cômodo onde ele está
func escolher_atividade(outro_comodo: bool = false) -> void:
	sair_do_ponto()
	var meu_comodo = house.comodo_em(global_position)
	var opcoes = get_tree().get_nodes_in_group("ponto_festa").filter(func(p):
		return p.tem_vaga() and not (outro_comodo and house.comodo_em(p.global_position) == meu_comodo)
	)
	if opcoes.is_empty() or (not outro_comodo and randf() < chance_zanzar):
		zanzar(meu_comodo if outro_comodo else "")
		return

	var pesos = opcoes.map(peso_do_ponto)
	var sorteio = randf() * pesos.reduce(func(a, b): return a + b)
	ponto = opcoes[-1]
	for i in opcoes.size():
		sorteio -= pesos[i]
		if sorteio <= 0.0:
			ponto = opcoes[i]
			break
	ponto.ocupantes.append(self)
	agent.target_position = ponto.lugar_livre()
	tempo_atividade = randf_range(ponto.tempo_min, ponto.tempo_max)

# quanto ele quer ir pra esse ponto
func peso_do_ponto(p) -> float:
	var peso = 1.0
	if current_estado == Estado.Assustado:
		# assustado não quer saber de dançar: quer ficar perto de gente
		peso = {"dançar": 0.2, "conversar": 4.0}.get(p.atividade, 1.0)
	elif p.atividade == preferencia:
		peso = 5.0
	if p == ultimo_ponto:
		peso *= 0.3
	# prefere o que está mais perto, senão a casa inteira vira corredor
	return peso / (1.0 + global_position.distance_to(p.global_position) / 800.0)

# dá uma volta rápida até um lugar qualquer de algum cômodo
func zanzar(fora_de: String = "") -> void:
	var regioes = house.regionsHouse.filter(func(r): return r.name != fora_de)
	agent.target_position = get_random_point_in_region(regioes.pick_random())
	tempo_atividade = randf_range(2.0, 5.0)

func sair_do_ponto() -> void:
	if ponto:
		ponto.ocupantes.erase(self)
		ultimo_ponto = ponto
		ponto = null

# parado no ponto: vira pro meio da roda (com folga, pra não ficar virando quando está bem no meio)
func olhar_pro_ponto() -> void:
	if ponto == null or not agent.is_navigation_finished():
		return
	var dx = ponto.global_position.x - global_position.x
	if absf(dx) > 8.0:
		sprite.flip_h = dx < 0.0

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

# fantasma = quem assustou (null no objeto levitável). se ele chegar no nível 5 pelo
# fantasma do tipo e do tier que matam ele do coração, infarta em vez de fugir
func tomar_susto(susto: String, pontosDeSusto: int, fantasma: Fantasma = null) -> void:
	if current_estado == Estado.Infarta:
		return
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
		if nivel_medo == 5 and mata_do_coracao(fantasma):
			infartar()
			return
		GameManager.sustos += 1
		# o +1 sai da cabeça e voa até o contador
		house.ui.voar_susto(get_global_transform_with_canvas() * Vector2(0, -100))
		mostrar_exclamacao("!!")
		# peso: tela treme, câmera dá um tranco e o jogo congela um instante (mais forte quando ele foge)
		var foge = nivel_medo >= 5
		house.camera.tremer(7.0 if foge else 3.0)
		house.camera.chutar(0.07 if foge else 0.03)
		GameManager.hitstop(0.15 if foge else 0.06)
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
	# sobe esticado, cai quicando e amassa na chegada
	tween_pulo.tween_property(sprite, "position:y", altura_sprite - 14.0, 0.08).set_ease(Tween.EASE_OUT)
	tween_pulo.parallel().tween_property(self, "deformacao", Vector2(0.85, 1.2), 0.08)
	tween_pulo.tween_property(sprite, "position:y", altura_sprite, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_pulo.parallel().tween_property(self, "deformacao", Vector2(1.15, 0.85), 0.08).set_delay(0.06)
	tween_pulo.tween_property(self, "deformacao", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# pisca claro na hora do susto
	sprite.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	medidor.scale = Vector2(1.4, 1.4)
	mostrar_exclamacao("!")

# "!" de quadrinho em cima da cabeça
func mostrar_exclamacao(texto: String) -> void:
	if exclamacao == null:
		exclamacao = Label.new()
		exclamacao.z_index = 2
		exclamacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		exclamacao.add_theme_font_size_override("font_size", 40)
		exclamacao.add_theme_constant_override("outline_size", 10)
		exclamacao.add_theme_color_override("font_outline_color", Color.BLACK)
		exclamacao.size = Vector2(60, 56)
		exclamacao.pivot_offset = Vector2(30, 56)
		exclamacao.position = Vector2(-30, -160)
		add_child(exclamacao)
	exclamacao.text = texto
	exclamacao.modulate.a = 1.0
	exclamacao.scale = Vector2(0.2, 0.2)
	exclamacao.rotation = randf_range(-0.25, 0.25)
	if tween_exclamacao:
		tween_exclamacao.kill()
	tween_exclamacao = exclamacao.create_tween()
	tween_exclamacao.tween_property(exclamacao, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_exclamacao.tween_interval(0.35)
	tween_exclamacao.tween_property(exclamacao, "modulate:a", 0.0, 0.2)

# barra de medo com os 5 níveis em quadradinhos em cima
func _desenhar_medidor() -> void:
	if alfa_medidor <= 0.01:
		return
	if current_estado == Estado.Infarta:
		desenhar_monitor()
		return
	var a = alfa_medidor
	var largura = 40.0
	var barra = Rect2(-largura / 2.0, 0, largura, 5)
	medidor.draw_rect(barra.grow(1.0), Color(0, 0, 0, a))
	medidor.draw_rect(barra, Color(0.25, 0.25, 0.25, a))
	medidor.draw_rect(Rect2(barra.position, Vector2(largura * barra_mostrada / 100.0, 5)), Color(1, 1, 1, a))
	for i in 5:
		var nivel = Rect2(-largura / 2.0 + i * 8.75, -7, 5, 4)
		medidor.draw_rect(nivel.grow(1.0), Color(0, 0, 0, a))
		medidor.draw_rect(nivel, Color(1, 1, 1, a) if i < nivel_medo else Color(0.25, 0.25, 0.25, a))

# o peito sobe e desce esticando o desenho pra cima (o pivô do sprite fica nos pés).
# cresce sempre em pixel inteiro de tela: escala quebrada em pixel art fica piscando
func respirar(delta: float) -> void:
	var velocidade = velocidade_ofegante if current_estado == Estado.Assustado else velocidade_respiracao
	tempo_respiracao += delta * velocidade
	var pixels = roundf((sin(tempo_respiracao) + 1.0) / 2.0 * pixels_respiracao)
	var altura = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_height()
	sprite.scale = Vector2(escala_sprite.x, escala_sprite.y + pixels / altura) * deformacao

func atordoar(tempo: float, dreno: float = 0.0) -> void:
	if current_estado == Estado.Infarta:
		return
	tempo_stun = tempo
	dreno_medo = dreno
	velocity = Vector2.ZERO

# sai correndo pra algum outro cômodo
func correr_para_outro_comodo(tempo: float) -> void:
	if current_estado == Estado.Infarta:
		return
	escolher_atividade(true)
	tempo_correndo = tempo

func fugir() -> void:
	if current_estado == Estado.Foge:
		return

	if house.ponto_fuga == null:
		push_error("Ponto de fuga não configurado!")
		return

	current_estado = Estado.Foge
	sair_do_ponto()

	agent.target_position = house.ponto_fuga.global_position

# chegou na saída: sai do jogo sumindo (já não conta como npc pros fantasmas)
func sair_da_festa() -> void:
	if saindo:
		return
	saindo = true
	remove_from_group("npc")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

# ---------- infarto ----------
# não tem arte pra isso, então é tudo no código: monitor cardíaco disparando em cima da cabeça,
# tela escurecendo em volta, linha reta, ele cai duro e a alma sobe

# o coração dispara até INFARTO_FIBRILA, treme sem ritmo até INFARTO_PARA e aí para
const INFARTO_FIBRILA = 1.6
const INFARTO_PARA = 2.1
# uma batida no monitor: x = fração da batida, y = altura
const BATIDA = [Vector2(0.0, 0.0), Vector2(0.15, -0.2), Vector2(0.35, 1.0), Vector2(0.55, -0.5), Vector2(0.75, 0.0)]
const DURACAO_BATIDA = 0.1
# quantos segundos de linha cabem no monitor
const JANELA_MONITOR = 1.2
# rachadura do coração partido, de baixo pra cima
const RACHADURA = [Vector2(0.5, 12.0), Vector2(2.0, 7.0), Vector2(-2.0, 2.0)]

var tempo_infarto: float = 0.0
var batidas: Array[float] = []
var proxima_batida: int = 0
# 1 na hora da batida e cai rápido: o desenho e o coraçãozinho pulsam junto
var pulso: float = 0.0
# 0 a 1: as metades do coração partido se afastando
var quebra: float = 0.0

func mata_do_coracao(fantasma: Fantasma) -> bool:
	return fantasma != null and Fantasma.Tipo.find_key(fantasma.tipo) == infarto_tipo and fantasma.tier == infarto_tier

func infartar() -> void:
	current_estado = Estado.Infarta
	# já não conta como npc: nenhum fantasma mira nele nem assusta mais
	remove_from_group("npc")
	sair_do_ponto()
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.stop()
	alfa_medidor = 1.0
	medidor.scale = Vector2(1.5, 1.5)

	# batidas cada vez mais perto uma da outra
	var t = 0.1
	var intervalo = 0.4
	while t < INFARTO_FIBRILA:
		batidas.append(t)
		t += intervalo
		intervalo = maxf(intervalo * 0.78, 0.12)

	house.ui.focar(self, 0.22)
	house.camera.tremer(8.0)
	house.camera.chutar(0.1)
	GameManager.hitstop(0.25)

	var lado = -1.0 if sprite.flip_h else 1.0
	var tween = create_tween()
	# passado o clarão do susto, vai ficando pálido
	tween.tween_interval(0.2)
	tween.tween_property(sprite, "modulate", Color(0.72, 0.76, 0.86), INFARTO_PARA - 0.2)
	tween.tween_callback(parar_coracao)
	# linha reta: tudo parado um instante antes de cair
	tween.tween_interval(0.45)
	# cai duro pra frente (o pivô do desenho é nos pés), quica uma vez e fica
	tween.tween_property(sprite, "rotation", lado * PI / 2.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(bater_no_chao.bind(lado))
	tween.tween_property(sprite, "rotation", lado * PI * 0.42, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", lado * PI / 2.0, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_callback(soltar_alma)
	tween.tween_property(self, "alfa_medidor", 0.0, 0.3)
	tween.tween_interval(0.5)
	tween.tween_callback(house.ui.desfocar)
	tween.tween_interval(0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)

func processar_infarto(delta: float) -> void:
	tempo_infarto += delta
	while proxima_batida < batidas.size() and tempo_infarto >= batidas[proxima_batida]:
		proxima_batida += 1
		pulso = 1.0
	pulso = move_toward(pulso, 0.0, 5.0 * delta)
	medidor.scale = medidor.scale.lerp(Vector2.ONE, minf(10.0 * delta, 1.0))
	medidor.queue_redraw()
	if tempo_infarto >= INFARTO_PARA:
		return
	# curva pra frente e treme cada vez mais (de pixel em pixel da arte); a cada batida dá um tranco
	var lado = -1.0 if sprite.flip_h else 1.0
	sprite.rotation = lado * 0.15 * tempo_infarto / INFARTO_PARA
	var tremor = 1.0 if tempo_infarto < INFARTO_FIBRILA else 2.0
	sprite.offset.x = roundf(sin(tempo_infarto * 60.0) * tremor)
	sprite.scale = escala_sprite * deformacao * Vector2(1.0 + pulso * 0.08, 1.0 - pulso * 0.05)
	sprite.self_modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.6), pulso)

# linha reta: o coração parte, a tela fecha nele e aparece o letreiro
func parar_coracao() -> void:
	sprite.offset.x = 0.0
	sprite.scale = escala_sprite
	sprite.self_modulate = Color.WHITE
	pulso = 0.0
	create_tween().tween_property(self, "quebra", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	house.ui.focar(self, 0.13)
	house.camera.tremer(5.0)
	house.ui.letreiro("INFARTO!", get_global_transform_with_canvas() * Vector2(0, -170))

func bater_no_chao(lado: float) -> void:
	house.camera.tremer(6.0)
	house.camera.chutar(0.05)
	GameManager.hitstop(0.08)
	var poeira = Fantasma.FUMACA.instantiate()
	poeira.position = get_parent().to_local(global_position + Vector2(lado * 40.0, 25.0))
	get_parent().add_child(poeira)
	# a recompensa sai do corpo caído
	GameManager.sustos += 1 + bonus_infarto
	house.ui.voar_susto(get_global_transform_with_canvas() * Vector2(lado * 40.0, 0), 1 + bonus_infarto)

# a alma sai do corpo: o mesmo desenho em branco, meio transparente, subindo e balançando
func soltar_alma() -> void:
	var alma = Sprite2D.new()
	alma.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	alma.offset = Vector2(0.0, sprite.offset.y)
	alma.flip_h = sprite.flip_h
	alma.scale = escala_sprite
	alma.position = sprite.position
	alma.z_index = 1
	alma.material = Fantasma.CONTORNO.duplicate()
	alma.material.set_shader_parameter("brilho", 1.0)
	alma.modulate.a = 0.0
	add_child(alma)
	var tween = alma.create_tween().set_parallel()
	tween.tween_property(alma, "position:y", alma.position.y - 110.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(alma, "modulate:a", 0.7, 0.3)
	tween.tween_property(alma, "modulate:a", 0.0, 0.9).set_delay(0.7)
	var balanco = alma.create_tween().set_loops(2)
	balanco.tween_property(alma, "position:x", 8.0, 0.4).set_trans(Tween.TRANS_SINE)
	balanco.tween_property(alma, "position:x", -8.0, 0.4).set_trans(Tween.TRANS_SINE)

# monitor cardíaco no lugar do medidor de medo: a linha com as batidas passando e o coraçãozinho do lado
func desenhar_monitor() -> void:
	var a = alfa_medidor
	var tela = Rect2(-22, -14, 56, 24)
	medidor.draw_rect(tela.grow(1.0), Color(0, 0, 0, a))
	medidor.draw_rect(tela, Color(0.1, 0.1, 0.1, a))
	var meio = tela.get_center().y
	var inicio = tempo_infarto - JANELA_MONITOR
	var linha = PackedVector2Array([Vector2(tela.position.x, meio)])
	for b in batidas:
		for p in BATIDA:
			var quando = b + p.x * DURACAO_BATIDA
			if quando > inicio and quando < tempo_infarto:
				linha.append(Vector2(tela.position.x + (quando - inicio) / JANELA_MONITOR * tela.size.x, meio - p.y * 9.0))
	# fibrilação: tremido sem ritmo nenhum
	var t = maxf(INFARTO_FIBRILA, inicio)
	while t < minf(INFARTO_PARA, tempo_infarto):
		var x = tela.position.x + (t - inicio) / JANELA_MONITOR * tela.size.x
		linha.append(Vector2(x, meio - (sin(t * 47.0) * 0.4 + sin(t * 113.0) * 0.3) * 9.0))
		t += JANELA_MONITOR / tela.size.x
	linha.append(Vector2(tela.end.x, meio))
	for i in linha.size():
		linha[i] = linha[i].round()
	medidor.draw_polyline(linha, Color(1, 1, 1, a), 2.0)
	desenhar_coracao(Vector2(tela.position.x - 10.0, meio), a)

func desenhar_coracao(centro: Vector2, a: float) -> void:
	var cor = Color(0.85, 0.12, 0.16).lerp(Color.WHITE, pulso * 0.4) if quebra == 0.0 else Color(0.4, 0.4, 0.4)
	cor.a = a
	var tamanho = 0.4 * (1.0 + pulso * 0.4)
	var metades = []
	for lado in [-1.0, 1.0]:
		var pontos = PackedVector2Array()
		var lugar = centro + Vector2(lado * quebra * 3.0, quebra * 2.0)
		for p in metade_coracao(lado):
			pontos.append(lugar + p.rotated(lado * quebra * 0.3) * tamanho)
		metades.append(pontos)
	# borda preta: o mesmo desenho 1 px pra cada lado, por baixo das duas metades
	for pontos in metades:
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			medidor.draw_colored_polygon(Transform2D(0.0, d) * pontos, Color(0, 0, 0, a))
	for pontos in metades:
		medidor.draw_colored_polygon(pontos, cor)

# metade do coração (x = 16 sen³t), fechando pela rachadura no meio; as duas metades se encaixam
func metade_coracao(lado: float) -> PackedVector2Array:
	var pontos = PackedVector2Array()
	for i in 13:
		var t = PI * i / 12.0
		pontos.append(Vector2(lado * 16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))))
	for p in RACHADURA:
		pontos.append(p)
	return pontos
