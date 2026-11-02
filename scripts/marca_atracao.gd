extends Node2D

# o lugar pra onde um convidado foi atraído, e todo o espetáculo em volta: a corrente sai do ponto e
# puxa ele, que vem deixando rastro; na chegada o círculo bate e as correntes prendem; preso, ele se
# debate; no fim as correntes arrebentam. Poder de atrair cria isso em efeitos_chao

enum Etapa { Puxando, Preso, Fim }

const COR = Color(1, 0.3, 0.25)
const RAIO = 56.0
# tempo que falta pra piscar e fazer tique-taque
const ALERTA = 5.0

var npc: Npc
var lugar: Vector2
var duracao: float = 30.0
var etapa: int = Etapa.Puxando
var tempo: float = 0.0
var tempo_etapa: float = 0.0
# quanto a corrente já saiu do ponto até ele (0 a 1), e o tremor dela (quando ele se debate)
var alcance: float = 0.0
var tremor: float = 1.0
var impacto: float = 0.0
var proximo_rastro: float = 0.0
var proxima_luta: float = 1.5
var ultimo_tique: int = 99
# cacos das correntes quando arrebentam: [posição, velocidade, giro]
var cacos: Array = []
# fim sem arrebentar: ele morreu preso
var fim_quieto: bool = false
# as correntes passam por cima de tudo; o círculo fica no chão, onde este nó está
var acima: Node2D
var luz: PointLight2D

func _ready() -> void:
	material = preload("res://assets/sem_luz.tres")
	global_position = Vector2.ZERO
	acima = Node2D.new()
	acima.material = material
	acima.z_index = 2
	acima.draw.connect(desenhar_correntes)
	add_child(acima)
	luz = PointLight2D.new()
	luz.texture = preload("res://assets/luz.tres")
	luz.color = COR
	luz.texture_scale = 2.2
	luz.position = lugar
	add_child(luz)

func _process(delta: float) -> void:
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	tempo += real
	tempo_etapa += real
	alcance = minf(alcance + real * 7.0, 1.0)
	tremor = move_toward(tremor, 0.0, 2.5 * real)
	impacto = move_toward(impacto, 0.0, 2.2 * real)
	match etapa:
		Etapa.Puxando:
			processar_puxando(real)
		Etapa.Preso:
			processar_preso(real)
		Etapa.Fim:
			processar_fim(real)
	luz.energy = (0.9 + 0.5 * sin(tempo * 7.0) + impacto * 3.0) * (clampf(1.0 - tempo_etapa / 0.5, 0.0, 1.0) if etapa == Etapa.Fim else 1.0)
	queue_redraw()
	acima.queue_redraw()

func acabou_atracao() -> bool:
	return not is_instance_valid(npc) or not npc.atraido

func processar_puxando(real: float) -> void:
	if acabou_atracao():
		terminar()
		return
	proximo_rastro -= real
	if proximo_rastro <= 0.0:
		proximo_rastro = 0.05
		soltar_rastro()
	if npc.agent.is_navigation_finished() and npc.global_position.distance_to(lugar) < 16.0:
		chegou()

# chegou: o círculo bate no chão, as correntes prendem e a tela sente
func chegou() -> void:
	etapa = Etapa.Preso
	tempo_etapa = 0.0
	impacto = 1.0
	tremor = 1.0
	var house = GameManager.house
	house.camera.tremer(7.0)
	house.camera.chutar(0.04)
	house.pos.chutar(4.0)
	house.piscar_luzes(lugar, 0.4)
	GameManager.som.tocar("caveira_pow")
	Onomatopeia.soltar("PRESO!", lugar + Vector2(0, -180), COR, 5.0)
	npc.pular_de_susto()
	soltar_poeira()

func processar_preso(real: float) -> void:
	if acabou_atracao():
		terminar()
		return
	# de vez em quando ele tenta se soltar: pula, as correntes tremem e às vezes grita
	proxima_luta -= real
	if proxima_luta <= 0.0:
		proxima_luta = randf_range(2.0, 3.5)
		tremor = 1.0
		npc.pular_de_susto()
		if randf() < 0.4:
			Onomatopeia.soltar(["ME SOLTA!", "SOCORRO!", "AAAH!"].pick_random(), npc.global_position + Vector2(randf_range(-30.0, 30.0), -170.0), Color(1, 0.95, 0.6), 2.5)
	# últimos segundos: tique-taque cada vez mais presente
	var falta = ceili(npc.tempo_preso)
	if falta != ultimo_tique and falta <= int(ALERTA):
		ultimo_tique = falta
		impacto = maxf(impacto, 0.35)
		var som = GameManager.som.tocar("hover_carta")
		if som:
			som.pitch_scale = 0.8 + 0.12 * (ALERTA - falta)

func terminar() -> void:
	etapa = Etapa.Fim
	tempo_etapa = 0.0
	# morreu preso: o infarto já é o espetáculo, as correntes só somem
	fim_quieto = not is_instance_valid(npc) or npc.current_estado == npc.Estado.Infarta
	if fim_quieto:
		return
	impacto = 1.0
	GameManager.som.tocar("diabrete_quebra")
	GameManager.house.camera.tremer(4.0)
	Onomatopeia.soltar("CLAC!", npc.global_position + Vector2(0, -170), Color(0.9, 0.9, 1), 4.0)
	soltar_poeira()
	for i in 22:
		var angulo = randf() * TAU
		cacos.append([npc.global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-90.0, -10.0)), Vector2.from_angle(angulo) * randf_range(120.0, 340.0), randf() * TAU])

func processar_fim(real: float) -> void:
	for caco in cacos:
		caco[0] += caco[1] * real
		caco[1].y += 700.0 * real
		caco[2] += 12.0 * real
	if tempo_etapa >= 0.6:
		queue_free()

# cópia apagada do quadro atual: o rastro de quem vem sendo arrastado
func soltar_rastro() -> void:
	var sprite = npc.sprite
	var copia = Sprite2D.new()
	copia.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	copia.offset = sprite.offset
	copia.flip_h = sprite.flip_h
	copia.scale = sprite.scale
	copia.rotation = sprite.rotation
	copia.global_position = sprite.global_position
	copia.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	copia.material = preload("res://assets/brilho.tres")
	copia.modulate = Color(COR, 0.55)
	copia.z_index = 1
	GameManager.house.y_sort.add_child(copia)
	copia.global_position = sprite.global_position
	var some = copia.create_tween()
	some.tween_property(copia, "modulate:a", 0.0, 0.28)
	some.tween_callback(copia.queue_free)

func soltar_poeira() -> void:
	var poeira = preload("res://scene/fumaca.tscn").instantiate()
	var y_sort = GameManager.house.y_sort
	poeira.position = y_sort.to_local(npc.global_position)
	y_sort.add_child(poeira)

func alfa_geral() -> float:
	return clampf(1.0 - tempo_etapa / 0.35, 0.0, 1.0) if etapa == Etapa.Fim else 1.0

# o círculo no chão: anel do tempo, runas girando e o impacto abrindo
func _draw() -> void:
	var alfa = alfa_geral()
	if alfa <= 0.0:
		return
	var falta = 1.0
	var pisca = 1.0
	if etapa == Etapa.Preso and is_instance_valid(npc):
		falta = npc.tempo_preso / duracao
		if npc.tempo_preso <= ALERTA:
			pisca = 0.4 + 0.6 * absf(sin(tempo * (6.0 + (ALERTA - npc.tempo_preso) * 2.0)))
	var pulso = 0.8 + 0.2 * sin(tempo * 6.0)
	# abre de pequeno no começo e ganha tamanho ao bater
	var raio = RAIO * (lerpf(0.55, 1.0, minf(tempo * 3.0, 1.0)) if etapa == Etapa.Puxando else 1.0 + impacto * 0.25)
	draw_set_transform(lugar, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, raio, Color(COR, (0.14 + impacto * 0.4) * pulso * alfa))
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 64, Color(COR, 0.3 * alfa), 2.0, true)
	draw_arc(Vector2.ZERO, raio, -PI / 2.0, -PI / 2.0 + TAU * falta, 64, Color(COR, pulso * pisca * alfa), 6.0, true)
	# runas: tracinhos girando, mais rápido na puxada
	var giro = tempo * (2.5 if etapa == Etapa.Puxando else 0.8)
	for i in 8:
		var direcao = Vector2.from_angle(giro + TAU * i / 8.0)
		draw_line(direcao * (raio + 8.0), direcao * (raio + 20.0), Color(COR, 0.8 * pisca * alfa), 4.0)
	# anéis do impacto
	if impacto > 0.0:
		draw_arc(Vector2.ZERO, raio + (1.0 - impacto) * 170.0, 0.0, TAU, 64, Color(Color.WHITE, impacto * 0.8), 3.0 + 8.0 * impacto, true)
	draw_set_transform(Vector2.ZERO)

func desenhar_correntes() -> void:
	var alfa = alfa_geral()
	if alfa > 0.0 and is_instance_valid(npc) and not fim_quieto:
		var corpo = npc.global_position + Vector2(0, -55)
		if etapa == Etapa.Puxando:
			desenhar_corrente(acima, lugar, lugar.lerp(corpo, alcance), Color(COR, alfa), tempo, 0.5 + tremor)
		elif etapa == Etapa.Preso:
			# quatro correntes da beira do círculo até o corpo
			for i in 4:
				var angulo = PI / 4.0 + TAU * i / 4.0
				var ponta = lugar + Vector2(cos(angulo) * RAIO, sin(angulo) * RAIO * 0.5)
				desenhar_corrente(acima, ponta, corpo + Vector2(cos(angulo) * 14.0, sin(angulo) * 26.0), Color(COR, alfa), tempo + i, tremor)
			if npc.tempo_preso > 0.0:
				var escala = 1.0 + impacto * 0.6
				acima.draw_set_transform(npc.global_position + Vector2(0, 40), 0.0, Vector2.ONE * escala)
				acima.draw_string(ThemeDB.fallback_font, Vector2(-30, 10), str(ceili(npc.tempo_preso)), HORIZONTAL_ALIGNMENT_CENTER, 60, 30, Color(Color.WHITE, 0.95))
				acima.draw_set_transform(Vector2.ZERO)
	for caco in cacos:
		var t = clampf(1.0 - tempo_etapa / 0.6, 0.0, 1.0)
		var lado = Vector2.from_angle(caco[2]) * 6.0
		acima.draw_line(caco[0] - lado, caco[0] + lado, Color(COR.lerp(Color.WHITE, 0.3), t), 4.0)

# elos alternando grosso e fino, com uma onda que some nas pontas; tremor faz ela sacudir.
# também usada na prévia enquanto o jogador escolhe o lugar
static func desenhar_corrente(tela: CanvasItem, de: Vector2, ate: Vector2, cor: Color, tempo: float, tremor: float = 0.0) -> void:
	var total = de.distance_to(ate)
	if total < 2.0:
		return
	var elos = maxi(int(total / 14.0), 2)
	var lado = (ate - de).orthogonal().normalized()
	var anterior = de
	for i in range(1, elos + 1):
		var t = float(i) / elos
		var onda = sin(t * PI) * sin(t * 14.0 + tempo * 30.0) * 7.0 * tremor
		var ponto = de.lerp(ate, t) + lado * onda
		var fim = anterior.lerp(ponto, 0.78)
		var grosso = i % 2 == 0
		tela.draw_line(anterior, fim, Color(0.06, 0.03, 0.05, cor.a), 9.0 if grosso else 5.0)
		tela.draw_line(anterior, fim, cor, 5.0 if grosso else 2.0)
		anterior = ponto
