extends Node3D

# Atmosfera 3D da noite de Halloween (filha do mundo3d, que é filho da House). Tudo é criado aqui no _ready:
# ambiente (luz ambiente na cor da noite, tonemap, glow, SSAO, névoa volumétrica), lua, neblina rasteira
# do quintal, fumaça da pista, fogos-fátuos, folhas, fogo da lareira e varais. As posições vêm dos nós 2D.

const V = preload("res://scripts/vista3d.gd")
const SHADER_NEBLINA = preload("res://assets/ambiente_neblina3d.gdshader")

@export_group("Ambiente")
@export var energia_ambiente: float = 0.9
@export var energia_lua: float = 0.6
@export var cor_fundo: Color = Color(0.015, 0.012, 0.03)
@export var glow: float = 0.9
@export var ssao: bool = true
@export_group("Névoa")
@export var fog_volumetrico: bool = false
@export var fog_densidade: float = 0.004
@export var fog_energia_luz: float = 1.2
@export var neblina_densidade: float = 0.14
@export var fumaca_densidade: float = 0.3

var house: Node2D
var env: Environment
var lua: DirectionalLight3D
var noite: CanvasModulate
var ruido: NoiseTexture2D
var neblinas: Array[ShaderMaterial] = []
var fogos: Array = []   # {no, base, fase}
var folhas: Array = []  # {no, pos, vel, fase}
var lampadas: Array = [] # {mat, cor, i}
var halos: Array = []   # {luz, no}: brilho (feixe falso) em volta das luzes da pista e da lareira
var tempo: float = 0.0
var limites_fora := Rect2(-800, -500, 3520, 2100)

func _ready() -> void:
	house = get_parent().get_parent()
	noite = house.get_node_or_null("noite")
	ruido = NoiseTexture2D.new()
	var fn = FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 3
	ruido.noise = fn
	ruido.seamless = true
	ruido.width = 512
	ruido.height = 512
	criar_ambiente()
	criar_lua()
	criar_neblina_fora()
	criar_fumaca_pista()
	criar_fogos_fatuos()
	criar_folhas()
	criar_lareira()
	criar_varais()
	criar_halos()

func _process(delta: float) -> void:
	delta = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	tempo += delta
	if noite:
		env.ambient_light_color = noite.color
		env.ambient_light_energy = energia_ambiente
	for f in fogos:
		var p: Vector3 = f.base
		f.no.position = p + Vector3(sin(tempo * 0.4 + f.fase) * 30.0, sin(tempo * 0.7 + f.fase * 2.0) * 12.0, cos(tempo * 0.33 + f.fase) * 30.0)
		var brilho = 0.55 + 0.45 * sin(tempo * 1.3 + f.fase * 3.0)
		f.no.material_override.albedo_color.a = brilho
	for l in folhas:
		l.pos += l.vel * delta
		l.pos.y -= 18.0 * delta
		if l.pos.y < 0.0 or not limites_fora.has_point(Vector2(l.pos.x, l.pos.z * V.SEN)):
			reciclar_folha(l)
		l.no.position = l.pos
		l.no.rotation = Vector3(sin(tempo + l.fase) * 0.8, tempo * 1.5 + l.fase, cos(tempo * 0.8 + l.fase) * 0.8)
	var luzes3d: Dictionary = get_parent().luzes
	for h in halos:
		var omni = luzes3d.get(h.luz)
		h.no.visible = omni != null and omni.visible
		if h.no.visible:
			h.no.position = omni.position
			h.no.material_override.albedo_color = Color(omni.light_color, h.forca * clampf(omni.light_energy / 4.0, 0.0, 1.0))
	var passo = int(tempo * 3.0)
	for l in lampadas:
		var aceso = 1.0 if (l.i + passo) % 3 == 0 else 0.35
		l.mat.emission_energy_multiplier = 0.8 + 3.0 * aceso

# ---------- ambiente, lua ----------

func criar_ambiente() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = cor_fundo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = noite.color if noite else Color(0.42, 0.38, 0.6)
	env.ambient_light_energy = energia_ambiente
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = glow > 0.0
	env.glow_intensity = glow
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = ssao
	env.ssao_radius = 40.0
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	if fog_volumetrico:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = fog_densidade
		env.volumetric_fog_albedo = Color(0.7, 0.75, 1.0)
		env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
		env.volumetric_fog_gi_inject = 0.0
		env.volumetric_fog_anisotropy = 0.5
		env.volumetric_fog_length = 6000.0
		env.volumetric_fog_detail_spread = 1.0
	var mundo = WorldEnvironment.new()
	mundo.environment = env
	add_child(mundo)

# como a luzes/lua 2D: no canto de cima à direita, fria e fraca. A luz viaja pra esquerda, pra frente e pra baixo.
func criar_lua() -> void:
	lua = DirectionalLight3D.new()
	lua.light_color = Color(0.55, 0.65, 1.0)
	lua.light_energy = energia_lua
	lua.shadow_enabled = true
	lua.shadow_blur = 1.5
	lua.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	lua.directional_shadow_max_distance = 6000.0
	lua.light_volumetric_fog_energy = 0.5
	lua.look_at_from_position(Vector3.ZERO, Vector3(-0.55, -0.75, 0.4), Vector3.UP)
	add_child(lua)

# ---------- neblina e fumaça ----------

func plano(rect2d: Rect2, altura: float, cor: Color, densidade: float, escala: float, mascara: bool) -> ShaderMaterial:
	var m = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	var tam = Vector2(rect2d.size.x, rect2d.size.y / V.SEN)
	pm.size = tam
	m.mesh = pm
	m.position = Vector3(rect2d.position.x + rect2d.size.x / 2.0, altura, (rect2d.position.y + rect2d.size.y / 2.0) / V.SEN)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.layers = 1
	var mat = ShaderMaterial.new()
	mat.shader = SHADER_NEBLINA
	mat.set_shader_parameter("ruido", ruido)
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("densidade", densidade)
	mat.set_shader_parameter("escala", escala)
	mat.set_shader_parameter("tamanho_plano", tam)
	if mascara:
		var chao: Sprite2D = house.get_node("chao")
		var t = chao.texture.get_size() * chao.scale
		var canto = chao.global_position - t / 2.0
		mat.set_shader_parameter("usar_mascara", true)
		mat.set_shader_parameter("mascara", chao.texture)
		mat.set_shader_parameter("mascara_rect", Vector4(canto.x, canto.y / V.SEN, t.x, t.y / V.SEN))
	m.material_override = mat
	add_child(m)
	neblinas.append(mat)
	return mat

func criar_neblina_fora() -> void:
	var r = Rect2(-800, -500, 3520, 2100)
	plano(r, 14.0, Color(0.42, 0.48, 0.68), neblina_densidade, 0.0011, true)
	plano(r, 34.0, Color(0.36, 0.42, 0.62), neblina_densidade * 0.6, 0.0007, true).set_shader_parameter("vento", Vector2(-0.008, 0.006))

func criar_fumaca_pista() -> void:
	var f: ColorRect = house.get_node_or_null("fumaca_pista")
	if f == null:
		return
	var r = Rect2(f.position, f.size)
	var a = plano(r, 18.0, Color(0.8, 0.8, 0.85), fumaca_densidade, 0.0035, false)
	a.set_shader_parameter("vento", Vector2(0.03, -0.015))
	a.set_shader_parameter("corte", 0.3)
	var b = plano(r, 46.0, Color(0.8, 0.8, 0.85), fumaca_densidade * 0.7, 0.0025, false)
	b.set_shader_parameter("vento", Vector2(-0.02, 0.02))
	b.set_shader_parameter("corte", 0.3)

# ---------- partículas ----------

func material_brilho(cor: Color) -> StandardMaterial3D:
	var tex = GradientTexture2D.new()
	var g = Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.albedo_color = cor
	mat.disable_receive_shadows = true
	return mat

func ponto_fora() -> Vector2:
	for i in 40:
		var p = Vector2(randf_range(limites_fora.position.x, limites_fora.end.x), randf_range(limites_fora.position.y, limites_fora.end.y))
		if house.fora_de_casa(p):
			return p
	return Vector2(-300, 500)

func criar_fogos_fatuos() -> void:
	for i in 18:
		var q = MeshInstance3D.new()
		var mesh = QuadMesh.new()
		mesh.size = Vector2(26, 26)
		q.mesh = mesh
		var mat = material_brilho(Color(0.55, 1.0, 0.75))
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.vertex_color_use_as_albedo = false
		mat.emission_enabled = false
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		fogos.append({"no": q, "base": V.chao(ponto_fora(), randf_range(30.0, 110.0)), "fase": randf() * TAU})

func criar_folhas() -> void:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(9, 6)
	mesh.orientation = PlaneMesh.FACE_Y
	for i in 36:
		var q = MeshInstance3D.new()
		q.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = [Color(0.55, 0.28, 0.08), Color(0.7, 0.4, 0.1), Color(0.35, 0.2, 0.08)][i % 3]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		var l = {"no": q, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "fase": randf() * TAU}
		reciclar_folha(l)
		l.pos.y = randf() * 150.0
		folhas.append(l)

func reciclar_folha(l: Dictionary) -> void:
	var p = ponto_fora()
	l.pos = V.chao(p, randf_range(60.0, 150.0))
	l.vel = Vector3(randf_range(15.0, 40.0), 0.0, randf_range(2.0, 14.0))

func criar_lareira() -> void:
	var no = house.get_node_or_null("fogo_lareira")
	if no == null:
		return
	var p = GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.7
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13, 1, 2)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.gravity = Vector3(0, 90, 0)
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 60.0
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.35, 0.9))
	g.add_point(0.5, Color(1.0, 0.4, 0.08, 0.7))
	g.set_color(2, Color(0.5, 0.05, 0.0, 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var mesh = QuadMesh.new()
	mesh.size = Vector2(16, 16)
	mesh.material = material_brilho(Color.WHITE)
	p.draw_pass_1 = mesh
	# o 2D desenha a chama na parede (y de tela 76); o pé da lareira fica ~49 px abaixo
	p.position = V.chao(Vector2(no.position.x, no.position.y + 49.0), 49.0)
	add_child(p)

# ---------- halos ----------

func criar_halos() -> void:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(1, 1)
	for luz in house.find_children("*", "PointLight2D", true, false):
		var n = String(luz.name)
		if not (n.begins_with("pista") or n == "lareira"):
			continue
		var q = MeshInstance3D.new()
		var m = QuadMesh.new()
		m.size = Vector2.ONE * (150.0 if n.begins_with("pista") else 110.0)
		q.mesh = m
		var mat = material_brilho(Color.WHITE)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		halos.append({"luz": luz, "no": q, "forca": 0.12 if n.begins_with("pista") else 0.15})

# ---------- varais ----------

func criar_varais() -> void:
	var deco = house.get_node_or_null("decoracao")
	if deco == null:
		return
	var esfera = SphereMesh.new()
	esfera.radius = 4.0
	esfera.height = 8.0
	esfera.radial_segments = 8
	esfera.rings = 4
	for varal in deco.get_children():
		if not "lampadas" in varal:
			continue
		for i in varal.lampadas:
			var cor: Color = varal.cores[i % varal.cores.size()]
			var pos2d: Vector2 = varal.global_position + varal.ponto((i + 0.5) / varal.lampadas)
			var m = MeshInstance3D.new()
			m.mesh = esfera
			var mat = StandardMaterial3D.new()
			mat.albedo_color = cor
			mat.emission_enabled = true
			mat.emission = cor
			mat.albedo_color = cor * 0.3
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# fio no topo da parede do fundo: o ponto de tela (x, y) fica a ALTURA_PAREDE acima do chão em y + ALTURA_PAREDE
			m.position = V.chao(pos2d + Vector2(0, V.ALTURA_PAREDE), V.ALTURA_PAREDE)
			add_child(m)
			lampadas.append({"mat": mat, "i": i})
