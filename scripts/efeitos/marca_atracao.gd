extends Node3D

# o lugar pra onde um convidado foi atraído, e todo o espetáculo em volta: a corrente sai do ponto e
# puxa ele, que vem deixando rastro; na chegada o círculo bate e as correntes prendem; preso, ele se
# debate; no fim as correntes arrebentam. Poder de atrair cria isso em fase.mundo.
# Aqui também ficam as helpers de malha (faixas viradas pra câmera e desenhos no chão) que o efeito_grupo reusa

enum Etapa { Puxando, Preso, Fim }

const COR = Color(1, 0.3, 0.25)
# metros (era 56 px)
const RAIO = 0.64
# tempo que falta pra piscar e fazer tique-taque
const ALERTA = 5.0
# altura do desenho no chão, pra não brigar com o piso
const Y_CHAO = 0.03

var npc: Npc
var lugar: Vector3
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
var malha_chao := ImmediateMesh.new()
# as correntes passam por cima de tudo; o círculo fica no chão
var malha_acima := ImmediateMesh.new()
var luz: OmniLight3D
# contagem regressiva embaixo dele (UI de tela presa no mundo)
var contagem: Node2D

static func nova_malha(malha: ImmediateMesh, sem_profundidade: bool) -> MeshInstance3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = sem_profundidade
	var mi = MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 100.0
	return mi

static func quad(m: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color) -> void:
	m.surface_set_color(cor)
	for p in [a, b, c, a, c, d]:
		m.surface_add_vertex(p)

# traço de largura fixa virado pra câmera
static func linha(m: ImmediateMesh, de: Vector3, ate: Vector3, largura: float, cor: Color) -> void:
	var lado = (ate - de).cross(GameManager.fase.camera.global_basis.z)
	if lado.length_squared() < 0.000001:
		return
	lado = lado.normalized() * largura / 2.0
	quad(m, de - lado, de + lado, ate + lado, ate - lado, cor)

# disco virado pra câmera
static func disco(m: ImmediateMesh, centro: Vector3, raio: float, cor: Color) -> void:
	var base = GameManager.fase.camera.global_basis
	for i in 12:
		var a0 = TAU * i / 12.0
		var a1 = TAU * (i + 1) / 12.0
		m.surface_set_color(cor)
		m.surface_add_vertex(centro)
		m.surface_add_vertex(centro + (base.x * cos(a0) + base.y * sin(a0)) * raio)
		m.surface_add_vertex(centro + (base.x * cos(a1) + base.y * sin(a1)) * raio)

# arco deitado no chão (a0 e a1 em radianos)
static func arco(m: ImmediateMesh, centro: Vector3, raio: float, a0: float, a1: float, largura: float, cor: Color) -> void:
	var passos = maxi(int(absf(a1 - a0) / TAU * 64.0), 2)
	var dentro = maxf(raio - largura / 2.0, 0.0)
	var fora = raio + largura / 2.0
	for i in passos:
		var u0 = Vector3(cos(lerpf(a0, a1, float(i) / passos)), 0, sin(lerpf(a0, a1, float(i) / passos)))
		var u1 = Vector3(cos(lerpf(a0, a1, float(i + 1) / passos)), 0, sin(lerpf(a0, a1, float(i + 1) / passos)))
		quad(m, centro + u0 * dentro, centro + u0 * fora, centro + u1 * fora, centro + u1 * dentro, cor)

static func disco_chao(m: ImmediateMesh, centro: Vector3, raio: float, cor: Color) -> void:
	for i in 32:
		var a0 = TAU * i / 32.0
		var a1 = TAU * (i + 1) / 32.0
		m.surface_set_color(cor)
		m.surface_add_vertex(centro)
		m.surface_add_vertex(centro + Vector3(cos(a0), 0, sin(a0)) * raio)
		m.surface_add_vertex(centro + Vector3(cos(a1), 0, sin(a1)) * raio)

func _ready() -> void:
	add_child(nova_malha(malha_chao, false))
	add_child(nova_malha(malha_acima, true))
	luz = OmniLight3D.new()
	luz.light_color = COR
	luz.omni_range = 3.2
	luz.omni_attenuation = 0.0
	luz.position = Vector3(lugar.x, 0.8, lugar.z)
	add_child(luz)
	contagem = Node2D.new()
	contagem.draw.connect(desenhar_contagem)
	add_child(contagem)

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
	luz.light_energy = 2.0 * (0.9 + 0.5 * sin(tempo * 7.0) + impacto * 3.0) * (clampf(1.0 - tempo_etapa / 0.5, 0.0, 1.0) if etapa == Etapa.Fim else 1.0)
	desenhar_chao()
	desenhar_correntes()
	atualizar_contagem()

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
	if npc.agent.is_navigation_finished() and npc.global_position.distance_to(lugar) < 0.18:
		chegou()

# chegou: o círculo bate no chão, as correntes prendem e a tela sente
func chegou() -> void:
	etapa = Etapa.Preso
	tempo_etapa = 0.0
	impacto = 1.0
	tremor = 1.0
	var fase = GameManager.fase
	fase.camera.tremer(7.0)
	fase.camera.chutar(0.04)
	fase.pos.chutar(4.0)
	fase.piscar_luzes(lugar, 0.4)
	GameManager.som.tocar("caveira_pow")
	Onomatopeia.soltar("PRESO!", lugar + Vector3.UP * 2.0, COR, 5.0)
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
			Onomatopeia.soltar(["ME SOLTA!", "SOCORRO!", "AAAH!"].pick_random(), npc.global_position + Vector3(randf_range(-0.35, 0.35), 1.9, 0), Color(1, 0.95, 0.6), 2.5)
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
	GameManager.fase.camera.tremer(4.0)
	Onomatopeia.soltar("CLAC!", npc.global_position + Vector3.UP * 1.9, Color(0.9, 0.9, 1), 4.0)
	soltar_poeira()
	for i in 22:
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		cacos.append([npc.global_position + Vector3(randf_range(-0.23, 0.23), randf_range(0.1, 1.0), randf_range(-0.23, 0.23)), dir * randf_range(1.4, 3.9), randf() * TAU])

func processar_fim(real: float) -> void:
	for caco in cacos:
		caco[0] += caco[1] * real
		caco[1].y -= 8.0 * real
		caco[0].y = maxf(caco[0].y, 0.0)
		caco[2] += 12.0 * real
	if tempo_etapa >= 0.6:
		queue_free()

# cópia apagada do quadro atual: o rastro de quem vem sendo arrastado
func soltar_rastro() -> void:
	var sprite = npc.sprite
	var copia = Sprite3D.new()
	copia.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	copia.centered = sprite.centered
	copia.offset = sprite.offset
	copia.pixel_size = sprite.pixel_size
	copia.flip_h = sprite.flip_h
	copia.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	copia.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	copia.shaded = false
	copia.modulate = Color(COR, 0.55)
	GameManager.fase.mundo.add_child(copia)
	copia.global_position = sprite.global_position
	copia.scale = sprite.global_transform.basis.get_scale()
	var some = copia.create_tween()
	some.tween_property(copia, "modulate:a", 0.0, 0.28)
	some.tween_callback(copia.queue_free)

func soltar_poeira() -> void:
	var poeira = preload("res://scene/efeitos/fumaca.tscn").instantiate()
	GameManager.fase.mundo.add_child(poeira)
	poeira.global_position = npc.global_position

func alfa_geral() -> float:
	return clampf(1.0 - tempo_etapa / 0.35, 0.0, 1.0) if etapa == Etapa.Fim else 1.0

# o círculo no chão: anel do tempo, runas girando e o impacto abrindo
func desenhar_chao() -> void:
	malha_chao.clear_surfaces()
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
	var c = Vector3(lugar.x, Y_CHAO, lugar.z)
	malha_chao.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	disco_chao(malha_chao, c, raio, Color(COR, (0.14 + impacto * 0.4) * pulso * alfa))
	arco(malha_chao, c, raio, 0.0, TAU, 0.023, Color(COR, 0.3 * alfa))
	arco(malha_chao, c, raio, -PI / 2.0, -PI / 2.0 + TAU * falta, 0.07, Color(COR, pulso * pisca * alfa))
	# runas: tracinhos girando, mais rápido na puxada
	var giro = tempo * (2.5 if etapa == Etapa.Puxando else 0.8)
	for i in 8:
		var a = giro + TAU * i / 8.0
		var d = Vector3(cos(a), 0, sin(a))
		var lado = d.cross(Vector3.UP) * 0.023
		quad(malha_chao, c + d * (raio + 0.09) + lado, c + d * (raio + 0.09) - lado, c + d * (raio + 0.23) - lado, c + d * (raio + 0.23) + lado, Color(COR, 0.8 * pisca * alfa))
	# anéis do impacto
	if impacto > 0.0:
		arco(malha_chao, c, raio + (1.0 - impacto) * 1.93, 0.0, TAU, 0.034 + 0.09 * impacto, Color(Color.WHITE, impacto * 0.8))
	malha_chao.surface_end()

func desenhar_correntes() -> void:
	malha_acima.clear_surfaces()
	malha_acima.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var alfa = alfa_geral()
	if alfa > 0.0 and is_instance_valid(npc) and not fim_quieto:
		var corpo = npc.global_position + Vector3.UP * 0.62
		var c = Vector3(lugar.x, Y_CHAO, lugar.z)
		if etapa == Etapa.Puxando:
			desenhar_corrente(malha_acima, c, c.lerp(corpo, alcance), Color(COR, alfa), tempo, 0.5 + tremor)
		elif etapa == Etapa.Preso:
			# quatro correntes da beira do círculo até o corpo
			for i in 4:
				var angulo = PI / 4.0 + TAU * i / 4.0
				var d = Vector3(cos(angulo), 0, sin(angulo))
				desenhar_corrente(malha_acima, c + d * RAIO, corpo + d * 0.16, Color(COR, alfa), tempo + i, tremor)
	for caco in cacos:
		var t = clampf(1.0 - tempo_etapa / 0.6, 0.0, 1.0)
		var cam = GameManager.fase.camera.global_basis
		var lado = (cam.x * cos(caco[2]) + cam.y * sin(caco[2])) * 0.07
		linha(malha_acima, caco[0] - lado, caco[0] + lado, 0.045, Color(COR.lerp(Color.WHITE, 0.3), t))
	malha_acima.surface_end()

func atualizar_contagem() -> void:
	contagem.visible = etapa == Etapa.Preso and is_instance_valid(npc) and npc.tempo_preso > 0.0 and alfa_geral() > 0.0
	if not contagem.visible:
		return
	var fase = GameManager.fase
	var zoom = fase.pixels_por_metro(npc.global_position) / 88.0
	fase.posicionar(contagem, npc.global_position)
	contagem.position.y += 40.0 * zoom
	contagem.scale = Vector2.ONE * (1.0 + impacto * 0.6) * zoom
	contagem.queue_redraw()

func desenhar_contagem() -> void:
	contagem.draw_string(ThemeDB.fallback_font, Vector2(-30, 10), str(ceili(npc.tempo_preso)), HORIZONTAL_ALIGNMENT_CENTER, 60, 30, Color(Color.WHITE, 0.95))

# elos alternando grosso e fino, com uma onda que some nas pontas; tremor faz ela sacudir.
# também usada na prévia enquanto o jogador escolhe o lugar. Só acrescenta triângulos à malha
static func desenhar_corrente(malha: ImmediateMesh, de: Vector3, ate: Vector3, cor: Color, tempo: float, tremor: float = 0.0) -> void:
	var total = de.distance_to(ate)
	if total < 0.023:
		return
	var elos = maxi(int(total / 0.16), 2)
	var lado = (ate - de).cross(GameManager.fase.camera.global_basis.z).normalized()
	var anterior = de
	for i in range(1, elos + 1):
		var t = float(i) / elos
		var onda = sin(t * PI) * sin(t * 14.0 + tempo * 30.0) * 0.08 * tremor
		var ponto = de.lerp(ate, t) + lado * onda
		var fim = anterior.lerp(ponto, 0.78)
		var grosso = i % 2 == 0
		linha(malha, anterior, fim, 0.1 if grosso else 0.057, Color(0.06, 0.03, 0.05, cor.a))
		linha(malha, anterior, fim, 0.057 if grosso else 0.023, cor)
		anterior = ponto
