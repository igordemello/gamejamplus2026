extends MeshInstance3D

# desenhado no chão: o alcance das ações do fantasma (de leve) e, arrastando uma carta, os lugares
# onde ela pode cair, mais a prévia da corrente do ímã. a fase cria isso em fase.mundo

const MARCA = preload("res://scripts/efeitos/marca_atracao.gd")
# quadradinho de onde a carta pode cair (metros), e quanto do mapa em volta da câmera é testado
const CELULA = 0.4
const MEIO_MAPA = Vector2(14.0, 11.0)
const Y_CELULAS = 0.02
const Y_AREAS = 0.03
const LARGURA_LINHA = 0.04

var area_jogo: Control
var menu_acoes: Control
var tempo: float = 0.0
var mostrando: bool = false
# [área, força]
var areas: Array = []
# os quadradinhos são montados uma vez por carta; depois só o alfa pulsa
var carta_atual: Variant = null
var no_celulas: MeshInstance3D
var material_celulas: StandardMaterial3D

func _ready() -> void:
	top_level = true
	global_position = Vector3.ZERO
	mesh = ImmediateMesh.new()
	material_override = material_chao()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ui = GameManager.fase.ui
	area_jogo = ui.get_node("area_jogo")
	menu_acoes = ui.get_node("menu_acoes")
	material_celulas = material_chao()
	no_celulas = MeshInstance3D.new()
	no_celulas.material_override = material_celulas
	no_celulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no_celulas.top_level = true
	no_celulas.hide()
	add_child(no_celulas)

func material_chao() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _process(delta: float) -> void:
	tempo += minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	atualizar_carta()
	areas = areas_de_agora()
	# a prévia da corrente muda todo quadro
	var poder = GameManager.fase.ui.poder
	var previa = poder.etapa == poder.Etapa.EscolheLugar and is_instance_valid(poder.escolhido)
	if not areas.is_empty() or previa:
		redesenhar(previa)
	elif mostrando:
		(mesh as ImmediateMesh).clear_surfaces()
	mostrando = not areas.is_empty() or previa

func atualizar_carta() -> void:
	var viewport = get_viewport()
	var carta = viewport.gui_get_drag_data() if viewport.gui_is_dragging() else null
	if not (is_instance_valid(carta) and carta.get("cena") != null):
		carta = null
	# escolhendo pra onde mover: os mesmos quadradinhos, pela regra do próprio fantasma
	var movendo = area_jogo.mira_fantasma
	if is_instance_valid(movendo) and area_jogo.mira_acao == movendo.acao_mover:
		carta = movendo
	# o poder de atrair, escolhendo o lugar
	var poder = GameManager.fase.ui.poder
	if poder.etapa == poder.Etapa.EscolheLugar:
		carta = poder
	if carta != carta_atual:
		carta_atual = carta
		no_celulas.visible = carta != null
		if carta:
			montar_celulas(carta)
			# carta que só cabe lá fora: mostra o lado de fora pra dar onde soltar
			if carta.fora_de_casa and carta.get("cena") != null:
				GameManager.fase.camera.mostrar_exterior()
	if carta:
		material_celulas.albedo_color.a = 0.75 + 0.25 * sin(tempo * 5.0)

# o mapa em volta da câmera em quadradinhos, pela mesma regra de quem deixa soltar a carta
func montar_celulas(carta: Variant) -> void:
	var malha = ImmediateMesh.new()
	var centro: Vector3 = GameManager.fase.camera.alvo
	var cor = Color(1, 1, 1, 0.13)
	var meio = CELULA / 2.0
	var folga = CELULA * 0.04
	malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var z = centro.z - MEIO_MAPA.y
	while z < centro.z + MEIO_MAPA.y:
		var x = centro.x - MEIO_MAPA.x
		while x < centro.x + MEIO_MAPA.x:
			if area_jogo.pode_soltar_em(carta, Vector3(x + meio, 0.0, z + meio)):
				quadrado(malha, Vector3(x + folga, Y_CELULAS, z + folga), Vector3(x + CELULA - folga, Y_CELULAS, z + CELULA - folga), cor)
			x += CELULA
		z += CELULA
	malha.surface_end()
	no_celulas.mesh = malha

# mirando: o alcance da mira. no menu: a ação escolhida, ou de leve todas. com o mouse em cima: de leve todas
func areas_de_agora() -> Array:
	if is_instance_valid(area_jogo.mira_fantasma):
		if area_jogo.mira_acao == area_jogo.mira_fantasma.acao_mover:
			return []
		return [[area_jogo.mira_fantasma.area_de(area_jogo.mira_acao), 1.0]]
	var fantasma = menu_acoes.fantasma
	if is_instance_valid(fantasma):
		var escolhida = menu_acoes.acao_na_bolinha()
		if escolhida == fantasma.acao_mover and escolhida != null:
			return []
		if escolhida:
			return [[fantasma.area_de(escolhida), 1.0]]
		return todas_de(fantasma, 0.5)
	if get_viewport().gui_is_dragging():
		return []
	for outro in get_tree().get_nodes_in_group("fantasma"):
		if outro.no_hover:
			return todas_de(outro, 0.5)
	return []

func todas_de(fantasma: Node, forca: float) -> Array:
	var lista = []
	for acao in fantasma.acoes:
		if acao != fantasma.acao_mover:
			lista.append([fantasma.area_de(acao), forca])
	return lista

func redesenhar(previa: bool) -> void:
	var malha: ImmediateMesh = mesh
	malha.clear_surfaces()
	malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var poder = GameManager.fase.ui.poder
	if previa:
		# corrente frouxa do convidado até o mouse, e o círculo de onde ele vai parar
		var mouse = GameManager.fase.mouse_no_chao()
		var cor = Color(1, 0.3, 0.25) if poder.no_mapa_ok else Color(0.5, 0.5, 0.5, 0.7)
		MARCA.desenhar_corrente(malha, poder.escolhido.global_position + Vector3(0, 0.6, 0), mouse + Vector3(0, 0.05, 0), cor, tempo, 0.8)
		anel(malha, mouse, MARCA.RAIO * (1.0 + 0.06 * sin(tempo * 6.0)), 0.05, cor)
	var pulso = 0.85 + 0.15 * sin(tempo * 3.0)
	for item in areas:
		var area: Dictionary = item[0]
		var forca: float = item[1] * pulso
		if area.has("raio"):
			disco(malha, area.centro, area.raio, Color(1, 1, 1, 0.05 * forca))
			anel(malha, area.centro, area.raio, LARGURA_LINHA, Color(1, 1, 1, 0.3 * forca))
		elif area.has("comodo"):
			desenhar_comodo(malha, area.comodo, forca)
	malha.surface_end()

# as caixas do cômodo (um Area3D com CollisionShape3D de caixa), no chão
func desenhar_comodo(malha: ImmediateMesh, nome: String, forca: float) -> void:
	for regiao in GameManager.fase.comodos:
		if regiao.name != nome:
			continue
		for forma in regiao.get_children():
			var meia: Vector3 = forma.shape.size / 2.0
			var cantos = []
			for c in [Vector3(-meia.x, 0, -meia.z), Vector3(meia.x, 0, -meia.z), Vector3(meia.x, 0, meia.z), Vector3(-meia.x, 0, meia.z)]:
				var p: Vector3 = forma.global_transform * c
				cantos.append(Vector3(p.x, Y_AREAS, p.z))
			var cor_miolo = Color(1, 1, 1, 0.05 * forca)
			triangulo(malha, cantos[0], cantos[1], cantos[2], cor_miolo)
			triangulo(malha, cantos[0], cantos[2], cantos[3], cor_miolo)
			for i in 4:
				linha(malha, cantos[i], cantos[(i + 1) % 4], LARGURA_LINHA, Color(1, 1, 1, 0.3 * forca))

func triangulo(malha: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, cor: Color) -> void:
	malha.surface_set_color(cor)
	malha.surface_add_vertex(a)
	malha.surface_add_vertex(b)
	malha.surface_add_vertex(c)

func quadrado(malha: ImmediateMesh, a: Vector3, b: Vector3, cor: Color) -> void:
	var c = Vector3(a.x, a.y, b.z)
	var d = Vector3(b.x, a.y, a.z)
	triangulo(malha, a, c, b, cor)
	triangulo(malha, a, b, d, cor)

# segmento no chão com espessura
func linha(malha: ImmediateMesh, a: Vector3, b: Vector3, largura: float, cor: Color) -> void:
	var lado = (b - a).cross(Vector3.UP).normalized() * largura / 2.0
	triangulo(malha, a - lado, a + lado, b + lado, cor)
	triangulo(malha, a - lado, b + lado, b - lado, cor)

func disco(malha: ImmediateMesh, centro: Vector3, raio: float, cor: Color) -> void:
	var meio = Vector3(centro.x, Y_AREAS, centro.z)
	for i in 48:
		var a = TAU * i / 48.0
		var b = TAU * (i + 1) / 48.0
		triangulo(malha, meio, meio + Vector3(cos(a), 0, sin(a)) * raio, meio + Vector3(cos(b), 0, sin(b)) * raio, cor)

func anel(malha: ImmediateMesh, centro: Vector3, raio: float, largura: float, cor: Color) -> void:
	var meio = Vector3(centro.x, Y_AREAS, centro.z)
	for i in 96:
		var a = TAU * i / 96.0
		var b = TAU * (i + 1) / 96.0
		linha(malha, meio + Vector3(cos(a), 0, sin(a)) * raio, meio + Vector3(cos(b), 0, sin(b)) * raio, largura, cor)
