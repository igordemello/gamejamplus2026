extends Node3D

# Vista 2.5D da casa (cena casa3d.tscn, filha da House). A lógica continua toda no 2D; este nó só desenha:
# - câmera: a Camera3D usa o centro, o zoom e a tremida da Camera2D (que fica desligada: quem monta a
#   canvas_transform é este nó) e gira em volta do meio da tela com o botão do meio do mouse. A
#   canvas_transform vira o chão visto pela câmera 3D, então get_global_mouse_position() continua sendo o
#   ponto do chão embaixo do mouse, com qualquer giro (na perspectiva, exato no mouse)
# - personagens: todo AnimatedSprite2D filho de npc/fantasma (e quem estiver no grupo "espelho3d") vira um
#   billboard: quad 3D em pé no pé, virado pra câmera, com o mesmo quadro, flip, cor, contorno e brilho
# - desenhos 2D do mundo que continuam 2D (medidor, "!", caveira do marcado, onomatopeias, notas...) ficam em
#   pé no lugar certo: antes de desenhar, o transform deles no RenderingServer é trocado (em_pe)
# - hover e clique em personagem/prop são pela projeção do desenho 3D na tela (mouse_no_desenho...)
# - luzes: cada PointLight2D vira uma OmniLight3D com a mesma cor e energia (tremor, pista, piscar, sirene)
# O que tem versão 3D vai pra camada 2D oculta (vista3d.CAMADA_OCULTA); F3 mostra o 2D de novo pra comparar.
# F4 troca pra perspectiva.

const V = preload("res://scripts/vista3d.gd")
const SHADER_SPRITE = preload("res://assets/sprite3d.gdshader")

# cenário 2D que tem versão 3D (a estrutura3d e o ambiente3d)
const CENARIO_2D = ["grama", "neblina_fora", "folhas", "fogos_fatuos", "chao", "tapete", "sombas",
	"fumaca_pista", "globo", "paredes2", "paredes8", "decoracao", "fogo_lareira"]
# desenhos 2D que ficam deitados no chão (o tapete da pista)
const DEITADOS_2D = ["tapete"]
# camada de render dos desenhos (a sombra decal no chão não pinta eles)
const CAMADA_SPRITES := 2
# graus de giro por pixel arrastado com o botão do meio
const GIRO_POR_PIXEL := 0.3
# limites da inclinação (graus pra baixo): perto de 90 o billboard deita, perto de 0 vê só parede
const INCLINACAO_MIN := 15.0
const INCLINACAO_MAX := 85.0
const ONOMATOPEIA = preload("res://scripts/onomatopeia.gd")

# luz 2D -> 3D: energia multiplicada, alcance (raio da textura 128 * texture_scale) multiplicado,
# altura das luzes da casa em pixels de tela (abaixo do topo das paredes: cada cômodo fica com a sua luz).
# atenuacao_luz 0 = cai só perto do alcance, como o gradiente da luz 2D (1 seria físico, e o mundo aqui
# mede centenas de unidades: a luz sumiria a poucos passos)
@export var energia_luz: float = 2.5
@export var atenuacao_luz: float = 0.0
@export var alcance_luz: float = 1.5
@export var altura_luz: float = 44.0
@export var sombra_luzes: bool = true
@export var distancia_camera: float = 4000.0
@export var fov_perspectiva: float = 32.0
# tamanho dos personagens na vista 2.5D (1 = o mesmo do 2D). O que fica em cima deles (medidor, caveira,
# "!", "+1") sobe junto; o clique vale pelo desenho 3D
@export var escala_billboard: float = 1.2

@onready var camera: Camera3D = $camera
@onready var espelhos: Node3D = $espelhos

var house: Node2D
var camera_2d: Camera2D
var vista_3d: bool = true
# giro da câmera em volta do ponto do meio da tela, em radianos (0 = a vista do 2D)
var giro: float = 0.0
# inclinação da câmera em graus (ANGULO = a vista do 2D); o botão do meio arrastando pra cima/baixo muda
var inclinacao: float = V.ANGULO
# a canvas_transform montada pela câmera 3D, e a parte linear dela sem o zoom (giro e achatamento do chão)
var canvas: Transform2D = Transform2D()
var linear: Transform2D = Transform2D()
# CanvasItem -> {malha, corpo, pe, sombra}
var sprites: Dictionary = {}
# corpo -> y 2D do chão usado no quad dele (o mesmo vale pra projetar o que está preso nele)
var ancoras: Dictionary = {}
# desenho 2D que fica em pé na vista 3D -> âncora fixa no chão (Vector2), ou null se a âncora é o corpo pai
var em_pe: Dictionary = {}
# PointLight2D -> OmniLight3D
var luzes: Dictionary = {}
var proxima_varredura: float = 0.0
var quad: ArrayMesh
var textura_sombra: GradientTexture2D
var dica: Label

func _ready() -> void:
	house = get_parent()
	camera_2d = house.get_node_or_null("Camera2D")
	RenderingServer.frame_pre_draw.connect(_antes_de_desenhar)
	# depois da Camera2D e de quem mexe nos desenhos; e também com o jogo pausado (F3, janela mudando)
	process_priority = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	quad = criar_quad()
	textura_sombra = criar_textura_sombra()
	for nome in CENARIO_2D:
		var no = house.get_node_or_null(nome)
		if no:
			V.esconder(no)
	for parede in get_tree().get_nodes_in_group("parede"):
		V.esconder(parede)
	for nome in DEITADOS_2D:
		var deitado = house.get_node_or_null(nome)
		if deitado is Sprite2D:
			deitar(deitado)
	criar_dica()
	aplicar_vista()

func _process(delta: float) -> void:
	sincronizar_camera()
	proxima_varredura -= delta
	if proxima_varredura <= 0.0:
		proxima_varredura = 0.2
		varrer()
	atualizar_sprites()
	for luz in luzes.keys():
		atualizar_luz(luz, luzes[luz])
	if dica.modulate.a > 0.0:
		dica.modulate.a -= minf(delta / maxf(Engine.time_scale, 0.01), 0.05) * 0.08

func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_antes_de_desenhar)

# segurando o botão do meio e arrastando: pro lado gira, pra cima/baixo inclina
func _unhandled_input(event: InputEvent) -> void:
	if vista_3d and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		giro = wrapf(giro - deg_to_rad(event.relative.x * GIRO_POR_PIXEL), -PI, PI)
		inclinacao = clampf(inclinacao + event.relative.y * GIRO_POR_PIXEL, INCLINACAO_MIN, INCLINACAO_MAX)
		if camera_2d and camera_2d.has_method("jogador_mexeu"):
			camera_2d.jogador_mexeu()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F3:
		vista_3d = not vista_3d
		aplicar_vista()
	elif event.keycode == KEY_F4:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else Camera3D.PROJECTION_ORTHOGONAL
	else:
		return
	dica.modulate.a = 1.0
	get_viewport().set_input_as_handled()

func aplicar_vista() -> void:
	var vp = get_viewport()
	if vista_3d:
		vp.canvas_cull_mask &= ~V.CAMADA_OCULTA
	else:
		vp.canvas_cull_mask |= V.CAMADA_OCULTA
		devolver_em_pe()
	visible = vista_3d
	# na vista 2.5D quem monta a canvas_transform é a câmera 3D; no 2D volta a ser a Camera2D
	if camera_2d:
		camera_2d.enabled = not vista_3d

# a câmera 3D olha pro ponto do chão no centro da Camera2D, com o mesmo zoom, inclinada ANGULO e girada;
# depois a tela 2D (mouse, chão desenhado em 2D) passa a seguir o chão visto por ela
func sincronizar_camera() -> void:
	if camera_2d == null or not vista_3d:
		return
	var vp = get_viewport()
	var tela = vp.get_visible_rect().size
	var zoom = absf(camera_2d.zoom.y)
	if zoom <= 0.0:
		return
	var centro = camera_2d.global_position + camera_2d.offset
	var altura_vista = tela.y / zoom
	var distancia = distancia_camera
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = altura_vista
	else:
		camera.fov = fov_perspectiva
		distancia = altura_vista / 2.0 / tan(deg_to_rad(fov_perspectiva) / 2.0)
	var base = Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -deg_to_rad(inclinacao))
	camera.global_transform = Transform3D(base, V.chao(centro) + base.z * distancia)
	# ortográfica: o chão na tela é afim, então é exato em toda a tela. perspectiva: exato no mouse
	var ref = centro
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		var sob_mouse = chao_sob_mouse()
		if sob_mouse != null:
			ref = sob_mouse
	canvas = afim_do_chao(ref)
	vp.canvas_transform = canvas
	linear = Transform2D(canvas.x / zoom, canvas.y / zoom, Vector2.ZERO)

# transformação afim (2D do chão -> tela) que bate com a câmera 3D em volta de ref
func afim_do_chao(ref: Vector2) -> Transform2D:
	var o = camera.unproject_position(V.chao(ref))
	var ex = (camera.unproject_position(V.chao(ref + Vector2(64.0, 0.0))) - o) / 64.0
	var ey = (camera.unproject_position(V.chao(ref + Vector2(0.0, 64.0))) - o) / 64.0
	return Transform2D(ex, ey, o - ex * ref.x - ey * ref.y)

# ponto do chão (2D) embaixo do mouse, pelo raio da câmera 3D
func chao_sob_mouse() -> Variant:
	var m = get_viewport().get_mouse_position()
	var origem = camera.project_ray_origin(m)
	var direcao = camera.project_ray_normal(m)
	if absf(direcao.y) < 0.0001:
		return null
	var t = -origem.y / direcao.y
	if t < 0.0:
		return null
	var p = origem + direcao * t
	return Vector2(p.x, p.z * V.SEN)

# eixos do billboard em p: [direita, cima] da câmera (ortográfica) ou de frente pra posição dela (perspectiva).
# 1 pixel 2D = 1 unidade 3D nesses eixos: de frente pra câmera o desenho não precisa ser esticado
func eixos_para(p: Vector3) -> Array:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return [camera.global_basis.x, camera.global_basis.y]
	var frente = camera.global_position - p
	var direita = Vector3.UP.cross(frente)
	if direita.length_squared() < 0.0001:
		return [camera.global_basis.x, camera.global_basis.y]
	direita = direita.normalized()
	return [direita, frente.normalized().cross(direita)]

# ponto 2D de algo preso num corpo (k = escala do billboard dele) no billboard, em pé no pé
func ponto_em_pe(p: Vector2, ancora: Vector2, k: float) -> Vector3:
	var eixos = eixos_para(V.chao(ancora))
	return V.em_pe(p, ancora, eixos[0], eixos[1], k)

# pixels de tela por unidade 3D perto de p
func escala_em(p: Vector3) -> float:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return get_viewport().get_visible_rect().size.y / camera.size
	return camera.unproject_position(p).distance_to(camera.unproject_position(p + camera.global_basis.x))

func varrer() -> void:
	var corpos = get_tree().get_nodes_in_group("npc") + get_tree().get_nodes_in_group("fantasma")
	for corpo in corpos:
		for filho in corpo.get_children():
			if filho is AnimatedSprite2D and not sprites.has(filho):
				registrar_sprite(filho, corpo, corpo.is_in_group("npc"))
		var sombra_2d = corpo.get_node_or_null("sombra")
		if sombra_2d is CanvasItem:
			V.esconder(sombra_2d)
		for filho in corpo.get_children():
			if fica_em_pe(filho):
				em_pe[filho] = null
	# soltos no mundo: a âncora é onde apareceram (a onomatopeia sobe na tela, não anda pro fundo)
	var soltos = house.get_children().filter(func(n): return n.get_script() == ONOMATOPEIA)
	for filho in house.y_sort.get_children():
		if filho is AnimatedSprite2D or filho is Sprite2D:
			soltos.append(filho)
	for solto in soltos:
		if fica_em_pe(solto):
			em_pe[solto] = solto.global_position
	# pontos de spawn (armaduras, lareira) mostram a silhueta do fantasma em pé no ponto
	for ponto in house.find_children("*", "Marker2D", true, false):
		if not "ocupante" in ponto:
			continue
		for filho in ponto.get_children():
			if fica_em_pe(filho):
				em_pe[filho] = ponto.global_position
	for item in get_tree().get_nodes_in_group("espelho3d"):
		if item is CanvasItem and not sprites.has(item):
			registrar_sprite(item, item, false)
	for luz in house.find_children("*", "PointLight2D", true, false):
		if not luzes.has(luz) and luz.name != "lua":
			registrar_luz(luz)

func atualizar_sprites() -> void:
	for item in sprites.keys():
		atualizar_sprite(item, sprites[item])

func registrar_sprite(item: CanvasItem, corpo: Node2D, pe: bool) -> void:
	var malha = MeshInstance3D.new()
	malha.mesh = quad
	malha.layers = CAMADA_SPRITES
	var material = ShaderMaterial.new()
	material.shader = SHADER_SPRITE
	malha.material_override = material
	malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	espelhos.add_child(malha)
	# a sombra sai de uma cópia em pé (sem esticar), não do billboard deitado pra trás
	var sombra_em_pe = MeshInstance3D.new()
	sombra_em_pe.mesh = quad
	sombra_em_pe.layers = CAMADA_SPRITES
	sombra_em_pe.material_override = material
	sombra_em_pe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sombra_em_pe.set_instance_shader_parameter("so_sombra", 1.0)
	espelhos.add_child(sombra_em_pe)
	var sombra: Decal = null
	# a sombra redonda no chão era do npc (o 2D desenhava uma elipse embaixo dos pés)
	if pe and item.name == "AnimatedSprite2D":
		sombra = Decal.new()
		sombra.texture_albedo = textura_sombra
		sombra.size = Vector3(42.0, 40.0, 26.0)
		sombra.cull_mask = 1
		sombra.upper_fade = 0.0
		sombra.lower_fade = 0.0
		espelhos.add_child(sombra)
	# só personagem cresce com escala_billboard (a comida e outros soltos ficam do tamanho do 2D)
	sprites[item] = {"malha": malha, "sombra_em_pe": sombra_em_pe, "corpo": corpo, "pe": pe, "sombra": sombra, "personagem": corpo != item}
	V.esconder(item)

func atualizar_sprite(item, dados: Dictionary) -> void:
	var malha: MeshInstance3D = dados.malha
	var sombra: Decal = dados.sombra
	if not is_instance_valid(item):
		malha.queue_free()
		dados.sombra_em_pe.queue_free()
		if sombra:
			sombra.queue_free()
		sprites.erase(item)
		return
	var quadro = quadro_de(item)
	var cor = cor_global(item)
	var mostrar = item.is_visible_in_tree() and not quadro.is_empty() and cor.a > 0.01
	malha.visible = mostrar
	dados.sombra_em_pe.visible = mostrar
	var corpo = dados.corpo if is_instance_valid(dados.corpo) else item
	var k = escala_billboard if dados.personagem else 1.0
	if sombra:
		sombra.visible = mostrar
		sombra.size = Vector3(42.0, 40.0, 26.0) * k
		sombra.position = V.chao(corpo.global_position)
		sombra.modulate = Color(1, 1, 1, cor.a)
	if not mostrar:
		return
	var g: Transform2D = item.get_global_transform()
	var r: Rect2 = quadro.rect
	var ancora = corpo.global_position.y
	if corpo.has_meta("chao_y"):
		ancora = corpo.get_meta("chao_y")
	elif not dados.pe:
		# quem flutua (centro do desenho na origem) não pode ter metade enfiada no chão
		for canto in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
			ancora = maxf(ancora, (g * canto).y)
	if item.name == "AnimatedSprite2D":
		ancoras[corpo] = ancora
	var pe = Vector2(corpo.global_position.x, ancora)
	var eixos = eixos_para(V.chao(pe))
	var t = V.quad(g, r, pe, eixos[0], eixos[1], k)
	# filhos com z_index (dentes da caveira, lágrimas) ficam um tico na frente do corpo
	var na_frente = t.basis.z.normalized() * item.z_index * 0.8
	t.origin += na_frente
	malha.transform = t
	# a cópia que faz sombra fica em pé de verdade, no tamanho do desenho (1 px = 1 unidade)
	var em_pe_horizontal = Vector3(eixos[0].x, 0.0, eixos[0].z).normalized()
	dados.sombra_em_pe.transform = V.quad(g, r, pe, em_pe_horizontal, Vector3.UP, k)
	var m: ShaderMaterial = malha.material_override
	m.set_shader_parameter("pe", V.chao(pe) + na_frente)
	m.set_shader_parameter("normal_pe", em_pe_horizontal.cross(Vector3.UP))
	var atlas: Texture2D = quadro.atlas
	var tamanho = Vector2(atlas.get_size())
	var pixel = filtro_pixel(item)
	m.set_shader_parameter("pixel", pixel)
	m.set_shader_parameter("tex_pixel" if pixel else "tex_suave", atlas)
	m.set_shader_parameter("regiao", Vector4(quadro.src.position.x / tamanho.x, quadro.src.position.y / tamanho.y, quadro.src.size.x / tamanho.x, quadro.src.size.y / tamanho.y))
	m.set_shader_parameter("texel", Vector2.ONE / tamanho)
	m.set_shader_parameter("espelhar", Vector2(1.0 if quadro.flip_h else 0.0, 1.0 if quadro.flip_v else 0.0))
	m.set_shader_parameter("cor", cor)
	var contorno = false
	var brilho = 0.0
	var cor_contorno = Color.WHITE
	if item.material is ShaderMaterial:
		var original: ShaderMaterial = item.material
		contorno = original.get_shader_parameter("contorno") == true
		var b = original.get_shader_parameter("brilho")
		brilho = b if b is float else 0.0
		var c = original.get_shader_parameter("cor")
		cor_contorno = c if c is Color else Color.WHITE
	m.set_shader_parameter("contorno", contorno)
	m.set_shader_parameter("brilho", brilho)
	m.set_shader_parameter("cor_contorno", cor_contorno)

# textura do atlas, região do quadro no atlas (px), retângulo desenhado (local do item) e flips
func quadro_de(item: CanvasItem) -> Dictionary:
	var textura: Texture2D
	var rect: Rect2
	var src: Rect2
	if item is AnimatedSprite2D:
		if item.sprite_frames == null or not item.sprite_frames.has_animation(item.animation):
			return {}
		textura = item.sprite_frames.get_frame_texture(item.animation, item.frame)
		if textura == null:
			return {}
		var tamanho = textura.get_size()
		rect = Rect2(item.offset - (tamanho / 2.0 if item.centered else Vector2.ZERO), tamanho)
		src = Rect2(Vector2.ZERO, tamanho)
	elif item is Sprite2D:
		textura = item.texture
		if textura == null:
			return {}
		rect = item.get_rect()
		var base = item.region_rect if item.region_enabled else Rect2(Vector2.ZERO, textura.get_size())
		var tamanho_quadro = base.size / Vector2(item.hframes, item.vframes)
		src = Rect2(base.position + Vector2(item.frame % item.hframes, item.frame / item.hframes) * tamanho_quadro, tamanho_quadro)
	else:
		return {}
	var atlas = textura
	if textura is AtlasTexture and textura.atlas:
		atlas = textura.atlas
		src.position += textura.region.position
	return {"atlas": atlas, "src": src, "rect": rect, "flip_h": item.flip_h, "flip_v": item.flip_v}

func cor_global(item: CanvasItem) -> Color:
	var cor = item.self_modulate
	var no: Node = item
	while no is CanvasItem:
		cor *= no.modulate
		no = no.get_parent()
	return cor

func filtro_pixel(item: CanvasItem) -> bool:
	var no: Node = item
	while no is CanvasItem:
		if no.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return no.texture_filter in [CanvasItem.TEXTURE_FILTER_NEAREST, CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]
		no = no.get_parent()
	return false

func registrar_luz(luz: PointLight2D) -> void:
	var omni = OmniLight3D.new()
	# as luzes da casa fazem sombra (das paredes e da gente); as dos fantasmas e a sirene não
	omni.shadow_enabled = sombra_luzes and luz.is_in_group("luz")
	omni.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	omni.shadow_blur = 1.5
	espelhos.add_child(omni)
	luzes[luz] = omni

func atualizar_luz(luz, omni: OmniLight3D) -> void:
	if not is_instance_valid(luz):
		omni.queue_free()
		luzes.erase(luz)
		return
	omni.visible = luz.enabled and luz.is_visible_in_tree()
	var pai = luz.get_parent()
	if pai is Node2D and (pai.is_in_group("npc") or pai.is_in_group("fantasma") or pai is CharacterBody2D):
		# luz presa num personagem (sirene, brilho do fantasma): na altura certa em cima do pé dele
		var pe = ancora_do_corpo(pai)
		var p = luz.global_position
		p.y = minf(p.y, pe.y - 8.0)
		omni.position = ponto_em_pe(p, pe, escala_billboard)
	else:
		omni.position = V.chao(luz.global_position, altura_luz)
	omni.light_color = luz.color
	omni.light_energy = luz.energy * energia_luz
	omni.omni_range = 128.0 * luz.texture_scale * alcance_luz
	omni.omni_attenuation = atenuacao_luz

# Sprite2D parado no chão (tapete) vira uma placa deitada no chão 3D, cobrindo o mesmo lugar
func deitar(sprite: Sprite2D) -> void:
	var r = sprite.get_rect()
	var g = sprite.get_global_transform()
	var placa = MeshInstance3D.new()
	placa.mesh = quad
	placa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ex = g.basis_xform(Vector2(r.size.x, 0.0))
	var ey = g.basis_xform(Vector2(0.0, r.size.y))
	var b = Basis(Vector3(ex.x, 0.0, ex.y / V.SEN), Vector3(ey.x, 0.0, ey.y / V.SEN), Vector3.UP)
	placa.transform = Transform3D(b, V.chao(g * r.position) + Vector3(0.0, 0.5, 0.0))
	var material = StandardMaterial3D.new()
	material.albedo_texture = sprite.texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if filtro_pixel(sprite) else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	if sprite.region_enabled:
		var t = Vector2(sprite.texture.get_size())
		material.uv1_offset = Vector3(sprite.region_rect.position.x / t.x, sprite.region_rect.position.y / t.y, 0.0)
		material.uv1_scale = Vector3(sprite.region_rect.size.x / t.x, sprite.region_rect.size.y / t.y, 1.0)
	placa.material_override = material
	add_child(placa)

func criar_quad() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
		st.set_normal(Vector3(0, 0, 1))
		st.set_uv(v)
		st.add_vertex(Vector3(v.x, v.y, 0.0))
	return st.commit()

func criar_textura_sombra() -> GradientTexture2D:
	var gradiente = Gradient.new()
	gradiente.set_color(0, Color(0, 0, 0, 0.55))
	gradiente.set_color(1, Color(0, 0, 0, 0))
	var textura = GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 64
	textura.height = 64
	return textura

# lembrete das teclas da vista, some sozinho
func criar_dica() -> void:
	var camada = CanvasLayer.new()
	camada.layer = 5
	add_child(camada)
	dica = Label.new()
	dica.text = "Botão do meio: girar e inclinar    F3: 2D / 2.5D    F4: ortográfica / perspectiva"
	dica.add_theme_font_size_override("font_size", 22)
	dica.modulate = Color(1, 1, 1, 1.6)
	dica.anchor_left = 0.5
	dica.anchor_right = 0.5
	dica.offset_left = -400
	dica.offset_right = 400
	dica.offset_top = 70
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(dica)

# ---------- desenhos 2D em pé e projeção

# filho de corpo (ou solto no mundo) que continua sendo desenhado em 2D e precisa ficar em pé
func fica_em_pe(n: Node) -> bool:
	return n is CanvasItem and not em_pe.has(n) and not sprites.has(n) and n.visibility_layer != V.CAMADA_OCULTA \
		and not (n is Light2D or n is CPUParticles2D or n is GPUParticles2D) and n.name != "anel" \
		and not n.is_in_group("npc") and not n.is_in_group("fantasma") and not n.is_in_group("parede")

func ancora_do_corpo(corpo: Node2D) -> Vector2:
	if corpo.has_meta("chao_y"):
		return Vector2(corpo.global_position.x, corpo.get_meta("chao_y"))
	return Vector2(corpo.global_position.x, ancoras.get(corpo, corpo.global_position.y))

# em quem o nó está preso: corpo (npc, fantasma) ou prop com chao_y; null se está solto
func dono_de(no: Node) -> Node2D:
	var n = no
	while n is Node2D and n != house and n != house.y_sort:
		if n.has_meta("chao_y") or ancoras.has(n) or n.is_in_group("npc") or n.is_in_group("fantasma"):
			return n
		n = n.get_parent()
	return null

# antes de desenhar: cada desenho em pé vai pra onde o ponto dele (pé + altura) aparece na tela, sem girar
# junto com o chão. Sem giro (ortográfica) o resultado é o mesmo transform de sempre
func _antes_de_desenhar() -> void:
	if not vista_3d:
		return
	# de novo aqui: tweens (pulo, amassar) rodam depois do _process, e sem isso ficariam um quadro atrasados
	atualizar_sprites()
	for item in em_pe.keys():
		if not is_instance_valid(item) or not item.is_inside_tree():
			em_pe.erase(item)
			continue
		var pai = item.get_parent()
		if not pai is CanvasItem:
			continue
		var g: Transform2D = item.get_global_transform()
		var preso = em_pe[item] == null
		var ancora = ancora_do_corpo(pai) if preso else em_pe[item]
		var p = ponto_em_pe(g.origin, ancora, escala_billboard if preso else 1.0)
		var k = escala_em(p)
		var desejado = Transform2D(g.x * k, g.y * k, camera.unproject_position(p))
		var local = (canvas * pai.get_global_transform()).affine_inverse() * desejado
		RenderingServer.canvas_item_set_transform(item.get_canvas_item(), local)

# de volta pro 2D: o transform de verdade de cada um
func devolver_em_pe() -> void:
	for item in em_pe:
		if is_instance_valid(item):
			RenderingServer.canvas_item_set_transform(item.get_canvas_item(), item.get_transform())

# onde um ponto local de um nó do mundo aparece na tela (altura em pé, presa no corpo dele)
func projetar(no: Node2D, local: Vector2) -> Vector2:
	var dono = dono_de(no)
	var ancora = ancora_do_corpo(dono) if dono else no.global_position
	# só personagem cresce com escala_billboard (o prop é a caixa 3D, do tamanho do 2D)
	var k = escala_billboard if dono and (ancoras.has(dono) or dono.is_in_group("npc") or dono.is_in_group("fantasma")) else 1.0
	return camera.unproject_position(ponto_em_pe(no.global_transform * local, ancora, k))

func mouse_tela() -> Vector2:
	return get_viewport().get_mouse_position()

# deslocamento de tela -> deslocamento no mundo 2D (sem zoom), e o contrário
func tela_para_mundo(d: Vector2) -> Vector2:
	return linear.affine_inverse().basis_xform(d)

func mundo_para_tela(d: Vector2) -> Vector2:
	return linear.basis_xform(d)

# o mouse está em cima do desenho (o quadro inteiro, como o 2D fazia) do billboard desse item?
func mouse_no_desenho(item: CanvasItem) -> bool:
	var dados = sprites.get(item)
	if dados == null or not dados.malha.visible:
		return false
	var t: Transform3D = dados.malha.transform
	var cantos = PackedVector2Array()
	for c in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]:
		cantos.append(camera.unproject_position(t * c))
	return Geometry2D.is_point_in_polygon(mouse_tela(), cantos)

# meio do desenho do billboard na tela
func centro_na_tela(item: CanvasItem) -> Vector2:
	var dados = sprites.get(item)
	if dados == null:
		return Vector2.INF
	return camera.unproject_position(dados.malha.transform * Vector3(0.5, 0.5, 0.0))

# o mouse está a até raio (unidades do mundo) do meio do desenho? (o clique nos fantasmas)
func mouse_perto(item: CanvasItem, raio: float) -> bool:
	var dados = sprites.get(item)
	if dados == null or not dados.malha.visible:
		return false
	var meio = dados.malha.transform * Vector3(0.5, 0.5, 0.0)
	return camera.unproject_position(meio).distance_to(mouse_tela()) <= raio * (escala_billboard if dados.personagem else 1.0) * escala_em(meio)

# o mouse está em cima da malha 3D (props)? pelo contorno da caixa dela na tela
func mouse_na_malha(malha: MeshInstance3D) -> bool:
	if not malha.visible:
		return false
	var caixa = malha.get_aabb()
	var pontos = PackedVector2Array()
	for i in 8:
		pontos.append(camera.unproject_position(malha.global_transform * caixa.get_endpoint(i)))
	return Geometry2D.is_point_in_polygon(mouse_tela(), Geometry2D.convex_hull(pontos))
