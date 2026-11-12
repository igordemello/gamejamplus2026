extends CharacterBody3D
class_name Npc

# convidado da festa (3D): anda na malha, toma susto, foge ou infarta. A UI em cima da cabeça é 2D presa no mundo.
const FUMACA = preload("res://scene/efeitos/fumaca.tscn")
const ALMA = preload("res://assets/alma.gdshader")
const PAPEL = Color(0.86, 0.84, 0.76)
# nível de medo que libera cada pedaço da lore (a árvore que abre no clique)
const NIVEIS_LORE = [1, 3, 4]
# a partir desse nível de medo, o fantasma certo mata do coração
const NIVEL_INFARTO = 3
# metros do topo do desenho até o medidor
const ALTURA_MEDIDOR = 0.18

# a fase se registra no GameManager antes dos filhos ficarem prontos
@onready var fase: Fase = GameManager.fase
# animações do npc: precisa ter "andar" desenhada virada pra direita
@export var visual: SpriteFrames
# nome do tipo e lore (um texto por NIVEIS_LORE) vêm da metadata do visual; preenchidos aqui, valem no lugar
@export var nome_tipo: String = ""
@export var lore: PackedStringArray = PackedStringArray()

@export var speed: float = 1.7
@export var acceleration: float = 6.8
@export var deceleration: float = 5.1

# gosto pessoal: a atividade da festa que ele escolhe mais vezes
@export_enum("aleatória", "dançar", "beber", "conversar", "descansar") var preferencia: String = "aleatória"
# atraído pelo poder do jogador: vai até lá e fica preso, sem nada tirar ele de lá
var atraido: bool = false
var ponto_atraido: Vector3
var tempo_preso: float = 0.0
# a comida da geleia que ele está indo comer
var indo_comer: Node3D
# chance de só dar uma volta por um cômodo em vez de ir pra um ponto da festa
@export var chance_zanzar: float = 0.1
# nunca fica mais que isso parado no mesmo lugar
@export var tempo_max_parado: float = 12.0

# ponto da festa onde ele está ou pra onde vai
var ponto
var ultimo_ponto
# quanto tempo ainda fica no que está fazendo
var tempo_atividade: float = 0.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var sprite: SpritePersonagem = $sprite
@onready var altura_sprite: float = sprite.position.y
@onready var escala_sprite: Vector3 = sprite.scale
var tween_pulo: Tween
# estica/amassa do susto, multiplica a escala do sprite
var deformacao: Vector2 = Vector2.ONE
var exclamacao: Label
var ancora_exclamacao: Node2D
var tween_exclamacao: Tween
# barrinha de medo em cima da cabeça (desenhada no sinal draw)
var medidor: Node2D
# pulinho do medidor, multiplica o tamanho dele na tela
var pulo_medidor: float = 1.0
var barra_mostrada: float = 0.0
var alfa_medidor: float = 0.0
# chegou na saída e está sumindo
var saindo: bool = false
# o mouse está nele (a area_jogo marca): anel de papel no chão
var em_destaque: bool = false
var anel: MeshInstance3D
var sombra: MeshInstance3D
var alfa_anel: float = 0.0

# o fantasma que mata esse npc do coração (metadata do visual)
var infarto_tipo: String = ""
var infarto_tier: int = 0
# sustos a mais (além do +1 do nível) quando ele infarta
@export var bonus_infarto: int = 2
# os pontos de susto são divididos por isso (o policial tem 1,5)
@export var resistencia: float = 1.0
# o policial: azulado, com sirene
@export var policial: bool = false
# um dos marcados pra morrer (objetivo): caveira vermelha em cima da cabeça
var marcado: bool = false
var marca: Sprite2D
# metros acima do topo do desenho
var altura_marca: float = 0.0
# cor fixa do sprite; os clarões do infarto voltam pra ela
var cor_sprite: Color = Color.WHITE
var sirene: OmniLight3D

# respiração parado: quantos pixels o desenho cresce e a velocidade (assustado fica ofegante)
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

@export var reducao_por_nivel: float = 0.05
@export var distancia_fuga: float = 0.17

@export var velocidade_correr: float = 3.4
@export var duracao_stun: float = 3.0

# quando diferente de zero o npc corre reto até bater numa parede e fica atordoado
var direcao_correr: Vector3 = Vector3.ZERO
var tempo_stun: float = 0.0
# quanto da barra de susto cai por segundo enquanto está atordoado
var dreno_medo: float = 0.0
# enquanto for > 0 anda com o dobro da velocidade (fugindo pra outro cômodo)
var tempo_correndo: float = 0.0
# quanto tempo corre depois de levar um susto num cômodo
@export var tempo_fuga_comodo: float = 3.0
# segundos tentando andar sem sair do lugar até desistir do destino
const TEMPO_TRAVADO = 3.0
# parado, abre espaço de quem estiver mais perto que isso (metros)
const DISTANCIA_SOCIAL = 0.82
const VELOCIDADE_AFASTAR = 0.8
var tempo_sem_andar: float = 0.0
var ultimo_lugar: Vector3

func _ready() -> void:
	sprite.sprite_frames = visual
	infarto_tipo = sprite.sprite_frames.get_meta("infarto_tipo", "")
	infarto_tier = sprite.sprite_frames.get_meta("infarto_tier", 0)
	if policial:
		add_to_group("policial")
		cor_sprite = Color(0.55, 0.7, 1.3)
		sprite.modulate = cor_sprite
		sirene = OmniLight3D.new()
		sirene.light_energy = 1.4
		sirene.omni_range = 2.5
		sirene.position = Vector3(0, 1.2, 0)
		add_child(sirene)
	medidor = Node2D.new()
	add_child(medidor)
	medidor.draw.connect(_desenhar_medidor)
	# sombra no chão, fica no lugar quando ele pula de susto
	var escuro = Gradient.new()
	escuro.offsets = PackedFloat32Array([0.0, 1.0])
	escuro.colors = PackedColorArray([Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.0)])
	sombra = disco_no_chao(0.6, escuro, 0.015)
	# anel do hover: miolo fraco e borda forte
	var borda = Gradient.new()
	borda.offsets = PackedFloat32Array([0.0, 0.76, 0.84, 0.94, 1.0])
	borda.colors = PackedColorArray([Color(PAPEL, 0.14), Color(PAPEL, 0.14), Color(PAPEL, 1.0), Color(PAPEL, 1.0), Color(PAPEL, 0.0)])
	anel = disco_no_chao(0.8, borda, 0.02)
	anel.visible = false
	if preferencia == "aleatória":
		preferencia = ["dançar", "beber", "conversar", "descansar"].pick_random()
	# um npc parado numa porta não pode travar quem vem atrás
	collision_mask = 0
	# cada um no seu passo
	speed *= randf_range(0.85, 1.15)
	await initialize_navigation()
	# começa parado onde foi colocado, cada um por um tempo
	agent.target_position = global_position
	tempo_atividade = randf_range(0.0, tempo_max_parado)
	navigation_ready = true

# quadrado achatado no chão com gradiente radial (sombra e anel)
func disco_no_chao(tamanho: float, gradiente: Gradient, altura: float) -> MeshInstance3D:
	var textura = GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 64
	textura.height = 64
	var malha = QuadMesh.new()
	malha.size = Vector2.ONE * tamanho
	malha.orientation = PlaneMesh.FACE_Y
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = textura
	var disco = MeshInstance3D.new()
	disco.mesh = malha
	disco.material_override = material
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disco.position.y = altura
	add_child(disco)
	return disco

# direita da câmera: o lado da tela
func direita() -> Vector3:
	return fase.camera.global_basis.x

# UI 2D presa na cabeça: posição e tamanho vêm da câmera, todo quadro
func posicionar_ui() -> void:
	var topo = fase.topo(sprite)
	var zoom = fase.pixels_por_metro(topo) / 88.0
	fase.posicionar(medidor, topo + Vector3.UP * ALTURA_MEDIDOR)
	medidor.scale = Vector2.ONE * pulo_medidor * zoom
	if ancora_exclamacao:
		fase.posicionar(ancora_exclamacao, topo + Vector3.UP * 0.45)
		ancora_exclamacao.scale = Vector2.ONE * zoom
	if marca and current_estado != Estado.Infarta:
		fase.posicionar(marca, topo + Vector3.UP * altura_marca)
		marca.position.y += roundf(sin(Time.get_ticks_msec() / 300.0) * 2.0)
		marca.scale = Vector2.ONE * 0.6 * zoom

func _process(delta: float) -> void:
	# o anel aparece e some em tempo real (a lore abre em câmera lenta)
	var quer_anel = em_destaque and is_in_group("npc") and current_estado != Estado.Infarta
	var alfa_antes = alfa_anel
	alfa_anel = move_toward(alfa_anel, 1.0 if quer_anel else 0.0, 8.0 * minf(delta / maxf(Engine.time_scale, 0.01), 0.05))
	if alfa_anel > 0.0 or alfa_antes > 0.0:
		anel.visible = alfa_anel > 0.0
		anel.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() / 1000.0 * 5.0) * 0.06)
		anel.material_override.albedo_color.a = alfa_anel
	if sirene:
		sirene.light_color = Color(1, 0.15, 0.15) if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3 else Color(0.2, 0.4, 1)
	posicionar_ui()
	if current_estado == Estado.Infarta:
		processar_infarto(delta)
		return

	# a barra enche e esvazia suave; o medidor aparece quando tem algum medo
	barra_mostrada = lerpf(barra_mostrada, barra_susto, minf(12.0 * delta, 1.0))
	alfa_medidor = move_toward(alfa_medidor, 1.0 if barra_susto > 0.0 or nivel_medo > 0 else 0.0, 4.0 * delta)
	pulo_medidor = lerpf(pulo_medidor, 1.0, minf(10.0 * delta, 1.0))
	medidor.queue_redraw()

	# atraído: inclina pra onde está indo, depois volta a ficar reto
	var inclinacao = 0.0
	if atraido and not agent.is_navigation_finished():
		inclinacao = clampf(velocity.dot(direita()) / 9.0, -0.35, 0.35)
	if inclinacao != 0.0 or sprite.giro != 0.0:
		sprite.giro = lerpf(sprite.giro, inclinacao, minf(12.0 * delta, 1.0))
		if absf(sprite.giro) < 0.005 and inclinacao == 0.0:
			sprite.giro = 0.0

	# parado fica no primeiro quadro; andando vira pro lado da tela que está indo
	if velocity.length() > 0.11:
		sprite.play("andar")
		sprite.speed_scale = 2.0 if tempo_correndo > 0.0 or current_estado == Estado.Foge else 1.0
		sprite.scale = escala_sprite * Vector3(deformacao.x, deformacao.y, 1.0)
		var lado = velocity.dot(direita())
		if absf(lado) > 0.057:
			sprite.flip_h = lado < 0.0
	else:
		sprite.stop()
		respirar(delta)
		olhar_pro_ponto()

func _physics_process(delta: float) -> void:
	if not navigation_ready or current_estado == Estado.Infarta:
		return

	# stun
	if tempo_stun > 0.0:
		tempo_stun -= delta
		barra_susto = maxf(barra_susto - dreno_medo * delta, 0.0)
		return

	tempo_correndo = maxf(tempo_correndo - delta, 0.0)

	# atraído
	if atraido:
		direcao_correr = Vector3.ZERO
		processar_atraido(delta)
		return

	if direcao_correr != Vector3.ZERO:
		if fase.eh_parede(global_position + direcao_correr * 0.23):
			direcao_correr = Vector3.ZERO
			atordoar(duracao_stun)
			return
		velocity = direcao_correr * velocidade_correr
		move_and_slide()
		return

	# fuga
	if current_estado == Estado.Foge:
		# fim do caminho é o ponto mais perto da saída que dá pra chegar: sai por ali, nunca fica parado
		if agent.is_navigation_finished() or global_position.distance_to(fase.ponto_fuga.global_position) <= distancia_fuga:
			sair_da_festa()
			return

		mover_npc(delta)
		return

	# festa
	if agent.is_navigation_finished():
		velocity = velocity.move_toward(
			abrir_espaco() * VELOCIDADE_AFASTAR,
			deceleration * delta
		)
		move_and_slide()
		ficar_na_malha()

		tempo_atividade -= delta
		if tempo_atividade <= 0.0:
			escolher_atividade()
		return

	mover_npc(delta)

func mover_npc(delta: float) -> void:
	var next_point = agent.get_next_path_position()
	next_point.y = global_position.y
	# desvia de leve de quem está colado, sem sair do caminho
	var direction = (global_position.direction_to(next_point) + abrir_espaco() * 0.4).normalized()

	var rapido = 2.0 if tempo_correndo > 0.0 or current_estado == Estado.Foge else 1.0
	var target_velocity = direction * speed * rapido

	velocity = velocity.move_toward(
		target_velocity,
		acceleration * rapido * delta
	)

	move_and_slide()
	ficar_na_malha()
	verificar_travado(delta)

# não tem física de parede: a malha da casa é o limite (com inércia ele cortava as quinas)
func ficar_na_malha() -> void:
	var ponto_malha = fase.ponto_na_casa(global_position)
	# só corrige o que dá pra ter andado num quadro (com a malha carregando o ponto vem na origem)
	var distancia = global_position.distance_to(ponto_malha)
	if distancia > 0.023 and distancia < 0.45:
		global_position = ponto_malha

# direção pra longe de quem está colado nele (zero se ninguém está)
func abrir_espaco() -> Vector3:
	var longe = Vector3.ZERO
	for outro in get_tree().get_nodes_in_group("npc"):
		if outro == self:
			continue
		var distancia = global_position.distance_to(outro.global_position)
		if distancia < DISTANCIA_SOCIAL:
			var angulo = randf() * TAU
			var lado = outro.global_position.direction_to(global_position) if distancia > 0.01 else Vector3(cos(angulo), 0.0, sin(angulo))
			longe += lado * (1.0 - distancia / DISTANCIA_SOCIAL)
	return longe.limit_length(1.0)

# gente na frente: em vez de ficar empurrando, desiste do destino e procura outro
func verificar_travado(delta: float) -> void:
	if global_position.distance_to(ultimo_lugar) > 0.23:
		ultimo_lugar = global_position
		tempo_sem_andar = 0.0
		return
	tempo_sem_andar += delta
	if tempo_sem_andar < TEMPO_TRAVADO:
		return
	tempo_sem_andar = 0.0
	if atraido:
		agent.target_position = ponto_atraido
	elif current_estado == Estado.Foge:
		agent.target_position = fase.ponto_fuga.global_position
	else:
		escolher_atividade()

func initialize_navigation() -> void:
	var navigation_map = agent.get_navigation_map()

	while NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		await get_tree().physics_frame

# escolhe o que fazer: quase sempre um ponto da festa com vaga (o gosto dele pesa mais), às vezes só uma volta.
# outro_comodo = tem que ser fora do cômodo onde ele está
func escolher_atividade(outro_comodo: bool = false) -> void:
	if atraido:
		return
	indo_comer = null
	sair_do_ponto()
	var meu_comodo = fase.comodo_em(global_position)
	var opcoes = get_tree().get_nodes_in_group("ponto_festa").filter(func(p):
		return p.tem_vaga() and p != ultimo_ponto and not (outro_comodo and fase.comodo_em(p.global_position) == meu_comodo)
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
	tempo_atividade = minf(randf_range(ponto.tempo_min, ponto.tempo_max), tempo_max_parado)

# quanto ele quer ir pra esse ponto
func peso_do_ponto(p) -> float:
	var peso = 1.0
	if current_estado == Estado.Assustado:
		# assustado não quer saber de dançar: quer ficar perto de gente
		peso = {"dançar": 0.2, "conversar": 4.0}.get(p.atividade, 1.0)
	elif p.atividade == preferencia:
		peso = 5.0
	# prefere o que está mais perto, senão a casa inteira vira corredor
	return peso / (1.0 + global_position.distance_to(p.global_position) / 9.1)

# dá uma volta rápida até um lugar qualquer de algum cômodo
func zanzar(fora_de: String = "") -> void:
	var regioes = fase.comodos.filter(func(r): return r.name != fora_de)
	agent.target_position = fase.ponto_no_comodo(regioes.pick_random())
	tempo_atividade = randf_range(2.0, 5.0)

func sair_do_ponto() -> void:
	if ponto:
		ponto.ocupantes.erase(self)
		ultimo_ponto = ponto
		ponto = null

# parado no ponto: vira pro meio da roda (com folga, pra não ficar virando no meio dela)
func olhar_pro_ponto() -> void:
	if ponto == null or not agent.is_navigation_finished():
		return
	var dx = (ponto.global_position - global_position).dot(direita())
	if absf(dx) > 0.09:
		sprite.flip_h = dx < 0.0

# fantasma = quem assustou (null no objeto levitável). A partir de NIVEL_INFARTO,
# o fantasma que mata do coração faz ele infartar na hora
func tomar_susto(susto: String, pontosDeSusto: int, fantasma: Fantasma = null) -> void:
	if current_estado == Estado.Infarta or pontosDeSusto <= 0:
		return

	var pontos_recebidos = pontosDeSusto / (1.0 + nivel_medo * reducao_por_nivel) * fase.intensidade_susto(global_position) / resistencia

	pular_de_susto()
	fase.registrar_susto(global_position)

	if nivel_medo >= NIVEL_INFARTO and nivel_medo < 5 and mata_do_coracao(fantasma):
		infartar()
		return

	barra_susto = minf(barra_susto + pontos_recebidos, 100.0)
	# o objeto levitável não expulsa ninguém, o policial só sai infartado e o atraído fica preso
	if (fantasma == null or policial or atraido) and nivel_medo == 4:
		barra_susto = minf(barra_susto, 99.0)

	var subiu = barra_susto >= 100.0
	if subiu:
		barra_susto = 0.0
		nivel_medo += 1
		GameManager.sustos += 1
		# o +1 voa até o contador
		fase.ui.voar_susto(fase.na_tela(fase.topo(sprite)))
		mostrar_exclamacao("!!")
		if nivel_medo < 5:
			GameManager.som.gritar()
		Onomatopeia.soltar("SOCORRO!" if nivel_medo >= 5 else ["AAAH!", "EEEK!", "AI AI AI!", "SOCORRO!"].pick_random(),
			global_position + direita() * randf_range(-0.45, 0.45) + Vector3.UP * 2.5, Color(1, 0.95, 0.6), 4.0 if nivel_medo >= 5 else 3.0)
		# peso: tela treme, tranco e hitstop (mais forte quando ele foge)
		var foge = nivel_medo >= 5
		fase.camera.tremer(7.0 if foge else 3.0)
		fase.camera.chutar(0.07 if foge else 0.03)
		GameManager.hitstop(0.15 if foge else 0.06)
		fase.pos.chutar(5.0 if foge else 2.5)
		fase.piscar_luzes(global_position, 0.6 if foge else 0.3)
		# quem já está fugindo (amanheceu) continua fugindo
		if current_estado != Estado.Foge:
			if nivel_medo >= 5:
				fugir()
			elif nivel_medo >= 3:
				current_estado = Estado.Assustado
			else:
				current_estado = Estado.Normal
		fugir_do_comodo()

# o mouse está em cima do desenho (retângulo do quadro, já com escala, respiração e flip)
func mouse_em_cima() -> bool:
	return fase.mouse_em_sprite(sprite)

# nome do tipo e os textos da lore, do npc ou, se ele não tiver, do visual
func dados_lore() -> Dictionary:
	var frames = sprite.sprite_frames
	return {
		"nome": nome_tipo if nome_tipo != "" else frames.get_meta("nome_tipo", ""),
		"lore": lore if not lore.is_empty() else PackedStringArray(frames.get_meta("lore", [])),
	}

# pulinho de susto, só no desenho
func pular_de_susto() -> void:
	if tween_pulo:
		tween_pulo.kill()
	tween_pulo = create_tween()
	# sobe esticado, cai quicando e amassa
	tween_pulo.tween_property(sprite, "position:y", altura_sprite + 0.16, 0.08).set_ease(Tween.EASE_OUT)
	tween_pulo.parallel().tween_property(self, "deformacao", Vector2(0.85, 1.2), 0.08)
	tween_pulo.tween_property(sprite, "position:y", altura_sprite, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_pulo.parallel().tween_property(self, "deformacao", Vector2(1.15, 0.85), 0.08).set_delay(0.06)
	tween_pulo.tween_property(self, "deformacao", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# pisca claro
	sprite.brilho = 1.0
	create_tween().tween_property(sprite, "brilho", 0.0, 0.2)
	pulo_medidor = 1.4
	mostrar_exclamacao("!")

# "!" de quadrinho em cima da cabeça (o Label fica dentro de uma âncora que a câmera posiciona)
func mostrar_exclamacao(texto: String) -> void:
	if exclamacao == null:
		ancora_exclamacao = Node2D.new()
		add_child(ancora_exclamacao)
		exclamacao = Label.new()
		exclamacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		exclamacao.add_theme_font_size_override("font_size", 40)
		exclamacao.size = Vector2(60, 56)
		exclamacao.pivot_offset = Vector2(30, 56)
		exclamacao.position = Vector2(-30, -56)
		ancora_exclamacao.add_child(exclamacao)
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
	var largura = 60.0
	var barra = Rect2(-largura / 2.0, 0, largura, 8)
	medidor.draw_rect(barra.grow(2.0), Color(0, 0, 0, a))
	medidor.draw_rect(barra, Color(0.25, 0.25, 0.25, a))
	medidor.draw_rect(Rect2(barra.position, Vector2(largura * barra_mostrada / 100.0, 8)), Color(1, 1, 1, a))
	# os 5 quadradinhos de nível ocupam a largura toda da barra
	var passo = (largura - 9.0) / 4.0
	for i in 5:
		var nivel = Rect2(-largura / 2.0 + i * passo, -12, 9, 7)
		medidor.draw_rect(nivel.grow(1.5), Color(0, 0, 0, a))
		medidor.draw_rect(nivel, Color(1, 1, 1, a) if i < nivel_medo else Color(0.25, 0.25, 0.25, a))

# o peito sobe e desce esticando o desenho pra cima (o pivô fica nos pés).
# sempre em pixel inteiro da textura: escala quebrada em pixel art fica piscando
func respirar(delta: float) -> void:
	var velocidade = velocidade_ofegante if current_estado == Estado.Assustado else velocidade_respiracao
	tempo_respiracao += delta * velocidade
	var pixels = roundf((sin(tempo_respiracao) + 1.0) / 2.0 * pixels_respiracao)
	var altura = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_height()
	sprite.scale = Vector3(escala_sprite.x * deformacao.x, (escala_sprite.y + pixels / altura) * deformacao.y, escala_sprite.z)

func atordoar(tempo: float, dreno: float = 0.0) -> void:
	if current_estado == Estado.Infarta:
		return
	tempo_stun = tempo
	dreno_medo = dreno
	velocity = Vector3.ZERO

func pode_ser_atraido() -> bool:
	return is_in_group("npc") and current_estado != Estado.Foge and current_estado != Estado.Infarta and not atraido

# poder do jogador: corre até o ponto e só sai depois de ficar lá esse tempo
func atrair(lugar: Vector3, tempo: float) -> void:
	sair_do_ponto()
	indo_comer = null
	direcao_correr = Vector3.ZERO
	atraido = true
	ponto_atraido = lugar
	tempo_preso = tempo
	agent.target_position = lugar

func soltar_atracao() -> void:
	atraido = false
	escolher_atividade()

# fim do tutorial: o medo volta a zero
func zerar_medo() -> void:
	nivel_medo = 0
	barra_susto = 0.0
	if current_estado == Estado.Assustado:
		current_estado = Estado.Normal

func processar_atraido(delta: float) -> void:
	if not agent.is_navigation_finished():
		tempo_correndo = maxf(tempo_correndo, 0.1)
		mover_npc(delta)
		return
	# freia na hora e fica em cima do ponto (a inércia levava ele uns 100 px adiante)
	velocity = Vector3.ZERO
	global_position = global_position.move_toward(ponto_atraido, speed * delta)
	tempo_preso -= delta
	if tempo_preso <= 0.0:
		soltar_atracao()

func pode_ir_comer() -> bool:
	return not atraido and current_estado != Estado.Foge and current_estado != Estado.Infarta and tempo_stun <= 0.0 and direcao_correr == Vector3.ZERO and tempo_correndo <= 0.0 and not is_instance_valid(indo_comer)

# cheiro da comida da geleia: larga o que fazia e vai até ela
func ir_comer(comida: Node3D) -> void:
	sair_do_ponto()
	indo_comer = comida
	agent.target_position = comida.global_position
	tempo_atividade = 1.0

# ficou tempo demais em cima de outro (Fase.vigiar_sobreposicao)
func redirecionar() -> bool:
	if current_estado == Estado.Foge or current_estado == Estado.Infarta or tempo_stun > 0.0:
		return false
	escolher_atividade()
	return true

# se está num cômodo e já não está correndo, sai dele
func fugir_do_comodo() -> void:
	if tempo_correndo <= 0.0 and fase.comodo_em(global_position) != "":
		correr_para_outro_comodo(tempo_fuga_comodo)

# corre pra outro cômodo (quem já foge da casa segue pra saída)
func correr_para_outro_comodo(tempo: float) -> void:
	if current_estado == Estado.Infarta or current_estado == Estado.Foge:
		return
	escolher_atividade(true)
	tempo_correndo = tempo

func fugir() -> void:
	if current_estado == Estado.Foge:
		return
	# o policial e quem está atraído só vão embora se amanhecer
	if (policial or atraido) and not fase.amanheceu:
		return
	atraido = false
	current_estado = Estado.Foge
	sair_do_ponto()
	GameManager.som.tocar("socorro", 4.85, 0.8)
	agent.target_position = fase.ponto_fuga.global_position

# chegou na saída: some com fade (já não conta como npc)
func sair_da_festa() -> void:
	if saindo:
		return
	saindo = true
	remove_from_group("npc")
	if marcado:
		fase.marcado_fugiu(self)
	var tween = create_tween().set_parallel()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(sombra, "transparency", 1.0, 0.4)
	tween.chain().tween_callback(queue_free)

# marcado pra morrer (objetivo): caveira vermelha em cima da cabeça
func marcar() -> void:
	marcado = true
	marca = Sprite2D.new()
	marca.texture = preload("res://assets/UI/icon_morte.png")
	marca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marca.modulate = Color(1, 0.25, 0.25)
	# acima do medidor (os quadradinhos de nível sobem uns 14 px)
	altura_marca = ALTURA_MEDIDOR + 0.32
	marca.scale = Vector2(0.6, 0.6)
	add_child(marca)

# ---------- infarto ----------
# sem arte: monitor cardíaco em cima da cabeça, tela escurecendo, linha reta, ele cai duro e a alma sobe

# o coração dispara até INFARTO_FIBRILA, treme sem ritmo até INFARTO_PARA e para
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
# 1 na hora da batida e cai rápido: desenho e coraçãozinho pulsam
var pulso: float = 0.0
# 0 a 1: as metades do coração partido se afastando
var quebra: float = 0.0

func mata_do_coracao(fantasma: Fantasma) -> bool:
	if fantasma == null:
		return false
	return Fantasma.Tipo.find_key(fantasma.tipo) == infarto_tipo and fantasma.tier == infarto_tier

func infartar() -> void:
	current_estado = Estado.Infarta
	atraido = false
	# já não conta como npc: nenhum fantasma mira nele (continua em "convidado" até sumir)
	remove_from_group("npc")
	sair_do_ponto()
	velocity = Vector3.ZERO
	$colisao.set_deferred("disabled", true)
	sprite.stop()
	alfa_anel = 0.0
	anel.visible = false
	alfa_medidor = 1.0
	pulo_medidor = 1.5
	if marca:
		marca.hide()

	# batidas cada vez mais juntas
	var t = 0.1
	var intervalo = 0.4
	while t < INFARTO_FIBRILA:
		batidas.append(t)
		t += intervalo
		intervalo = maxf(intervalo * 0.78, 0.12)

	fase.ui.focar(self, 0.22)
	fase.camera.tremer(8.0)
	fase.camera.chutar(0.1)
	GameManager.hitstop(0.25)
	fase.pos.chutar(7.0)
	fase.piscar_luzes(global_position, INFARTO_PARA)
	Onomatopeia.soltar("TUM TUM", global_position + direita() * 0.68 + Vector3.UP * 1.75, Color(1, 0.3, 0.3))

	var lado = -1.0 if sprite.flip_h else 1.0
	var tween = create_tween()
	# vai ficando pálido
	tween.tween_interval(0.2)
	tween.tween_property(sprite, "modulate", cor_sprite * Color(0.72, 0.76, 0.86), INFARTO_PARA - 0.2)
	tween.tween_callback(parar_coracao)
	# linha reta: parado um instante antes de cair
	tween.tween_interval(0.45)
	# cai duro pra frente, quica uma vez e fica
	tween.tween_property(sprite, "giro", lado * PI / 2.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(bater_no_chao.bind(lado))
	tween.tween_property(sprite, "giro", lado * PI * 0.42, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "giro", lado * PI / 2.0, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_callback(soltar_alma)
	tween.tween_property(self, "alfa_medidor", 0.0, 0.3)
	tween.tween_interval(0.5)
	tween.tween_callback(fase.ui.desfocar)
	tween.tween_interval(0.8)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(sombra, "transparency", 1.0, 0.6)
	tween.tween_callback(queue_free)

func processar_infarto(delta: float) -> void:
	tempo_infarto += delta
	while proxima_batida < batidas.size() and tempo_infarto >= batidas[proxima_batida]:
		proxima_batida += 1
		pulso = 1.0
	pulso = move_toward(pulso, 0.0, 5.0 * delta)
	pulo_medidor = lerpf(pulo_medidor, 1.0, minf(10.0 * delta, 1.0))
	medidor.queue_redraw()
	if tempo_infarto >= INFARTO_PARA:
		return
	# curva pra frente e treme cada vez mais, em pixel inteiro; a cada batida dá um tranco
	var lado = -1.0 if sprite.flip_h else 1.0
	sprite.giro = lado * 0.15 * tempo_infarto / INFARTO_PARA
	var tremor = 1.0 if tempo_infarto < INFARTO_FIBRILA else 2.0
	sprite.offset.x = roundf(sin(tempo_infarto * 60.0) * tremor)
	sprite.scale = escala_sprite * Vector3(deformacao.x * (1.0 + pulso * 0.08), deformacao.y * (1.0 - pulso * 0.05), 1.0)
	sprite.brilho = pulso * 0.6

# linha reta: o coração parte e aparece o letreiro
func parar_coracao() -> void:
	sprite.offset.x = 0.0
	sprite.scale = escala_sprite
	sprite.brilho = 0.0
	pulso = 0.0
	create_tween().tween_property(self, "quebra", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fase.ui.focar(self, 0.13)
	fase.camera.tremer(5.0)
	fase.ui.letreiro("INFARTO!", fase.na_tela(fase.topo(sprite) + Vector3.UP * 0.7))
	GameManager.som.tocar("infarto")

func bater_no_chao(lado: float) -> void:
	fase.camera.tremer(6.0)
	fase.camera.chutar(0.05)
	GameManager.hitstop(0.08)
	fase.pos.chutar(4.0)
	Onomatopeia.soltar("PLOFT!", global_position + direita() * lado * 0.57 + Vector3.UP * 0.6, Color(0.85, 0.85, 0.9), 4.0)
	var poeira = FUMACA.instantiate()
	poeira.position = global_position + direita() * lado * 0.45 + Vector3.UP * 0.2
	fase.mundo.add_child(poeira)
	# a recompensa sai do corpo
	GameManager.sustos += 1 + bonus_infarto
	GameManager.mortes += 1
	fase.registrar_morte(self)
	fase.ui.voar_susto(fase.na_tela(global_position + direita() * lado * 0.45 + Vector3.UP * 0.5), 1 + bonus_infarto)

# a alma: o mesmo desenho em branco, subindo e balançando
func soltar_alma() -> void:
	var alma = Sprite3D.new()
	var quadro = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	alma.texture = quadro
	alma.pixel_size = sprite.pixel_size
	alma.offset = Vector2(0.0, sprite.offset.y)
	alma.flip_h = sprite.flip_h
	alma.scale = escala_sprite
	alma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = ALMA
	material.set_shader_parameter("texture_albedo", quadro.atlas if quadro is AtlasTexture else quadro)
	material.set_shader_parameter("opacidade", 0.0)
	alma.material_override = material
	add_child(alma)
	alma.global_position = sprite.global_position
	var base = alma.global_position
	var lado = direita()
	var tween = alma.create_tween()
	# sobe 1,25 m em 1,6 s balançando de lado pra lado
	tween.tween_method(func(t: float):
		alma.global_position = base + Vector3.UP * 1.25 * sin(t * PI / 2.0) + lado * 0.09 * sin(t * TAU * 2.0), 0.0, 1.0, 1.6)
	var brilho = alma.create_tween()
	brilho.tween_property(material, "shader_parameter/opacidade", 0.7, 0.3)
	brilho.tween_interval(0.4)
	brilho.tween_property(material, "shader_parameter/opacidade", 0.0, 0.9)

# monitor cardíaco no lugar do medidor de medo
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
	# fibrilação: tremido sem ritmo
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
	# borda preta: o mesmo desenho 1 px pra cada lado, por baixo
	for pontos in metades:
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			medidor.draw_colored_polygon(Transform2D(0.0, d) * pontos, Color(0, 0, 0, a))
	for pontos in metades:
		medidor.draw_colored_polygon(pontos, cor)

# metade do coração (x = 16 sen³t), fechando pela rachadura no meio
func metade_coracao(lado: float) -> PackedVector2Array:
	var pontos = PackedVector2Array()
	for i in 13:
		var t = PI * i / 12.0
		pontos.append(Vector2(lado * 16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))))
	for p in RACHADURA:
		pontos.append(p)
	return pontos
