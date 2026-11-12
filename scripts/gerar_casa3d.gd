extends SceneTree

# Gera a casa em 3D da vista 2.5D: assets/casa3d_paredes.tres, casa3d_chao.tres e casa3d_grama.tres
# (a scene/estrutura3d.tscn só referencia esses meshes). Rode de novo se mudar a casa ou o ANGULO
# de scripts/vista3d.gd (a altura das paredes e o esticamento em z dependem dele):
#   godot --headless --path . --script res://scripts/gerar_casa3d.gd
#
# Como funciona: os traços pretos das peças do grupo "parede" (layoutcasa.png e as faixas pretas dos
# outros) são o TOPO das paredes na tela; a face marrom/bege logo abaixo tem ALTURA_PAREDE px.
# Então um pixel de topo em (x, y) é uma coluna de parede cujo pé está em y + ALTURA_PAREDE no chão.
# A grade fina de pés vira retângulos (greedy) pro topo, e as faces expostas viram faixas, em
# marrom (tem chão da casa daquele lado) ou bege (lado de fora). A cor vai no COLOR do vértice;
# COLOR.a = 0 marca o topo (assets/parede3d.gdshader).

const V = preload("res://scripts/vista3d.gd")

const PASSO = 2
# área do chão (mundo 2D) onde procuramos os pés das paredes
const AREA = Rect2i(100, -100, 1740, 1360)
const COR_TOPO = Color(0.02, 0.02, 0.025)
# a grama crua fica clara e verde demais com a luz 3D: escurece e puxa pro cinza, como a noite do 2D
const TOM_GRAMA = Color(0.5, 0.52, 0.58)
# cores da arte (paredes.png e Casa.png), em sRGB
const COR_DENTRO = Color8(128, 88, 60)
const COR_FORA = Color8(190, 174, 134)

var house
var sprites: Array = []
var imagens: Array = []
var chao_sprite: Sprite2D
var chao_img: Image

func _initialize() -> void:
	_gerar()

func _gerar() -> void:
	await process_frame
	house = load("res://scene/house.tscn").instantiate()
	root.add_child(house)
	await process_frame

	for s in get_nodes_in_group("parede"):
		sprites.append(s)
		imagens.append(s.texture.get_image())
	chao_sprite = house.get_node("chao")
	chao_img = chao_sprite.texture.get_image()

	var tam = AREA.size / PASSO
	var topo = PackedByteArray()
	topo.resize(tam.x * tam.y)
	for y in tam.y:
		for x in tam.x:
			var pe = Vector2(AREA.position) + (Vector2(x, y) + Vector2(0.5, 0.5)) * PASSO
			if _escuro(pe - Vector2(0, V.ALTURA_PAREDE)):
				topo[y * tam.x + x] = 1

	var paredes = _mesh_paredes(topo, tam)
	_salvar(paredes, "res://assets/casa3d_paredes.tres")
	_salvar(_mesh_chao(), "res://assets/casa3d_chao.tres")
	_salvar(_mesh_grama(), "res://assets/casa3d_grama.tres")
	quit()

func _salvar(m: Mesh, caminho: String) -> void:
	var erro = ResourceSaver.save(m, caminho)
	print(caminho, " -> ", erro, " (", m.get_surface_count(), " superfícies)")

# --- amostragem das imagens 2D ---

func _cor(s: Sprite2D, img: Image, p: Vector2) -> Color:
	var l = s.to_local(p) - s.get_rect().position
	var px = Vector2i(l.floor())
	if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
		return Color(0, 0, 0, 0)
	return img.get_pixelv(px)

# pixel preto (traço do topo) em alguma peça de parede
func _escuro(p: Vector2) -> bool:
	for i in sprites.size():
		var c = _cor(sprites[i], imagens[i], p)
		if c.a > 0.5 and c.r + c.g + c.b < 0.3:
			return true
	return false

func _tem_chao(p: Vector2) -> bool:
	return _cor(chao_sprite, chao_img, p).a > 0.5

# --- geometria ---

class Malha:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()

	# quad a,b,c,d (em volta) com normal n; o Godot usa horário como frente, então ajusta o giro
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, normal: Vector3, cor: Color) -> void:
		var tris = [a, b, cc, a, cc, d]
		if (b - a).cross(cc - a).dot(normal) > 0.0:
			tris = [a, cc, b, a, d, cc]
		for p in tris:
			v.append(p)
			n.append(normal)
			c.append(cor)
			uv.append(Vector2.ZERO)

	func mesh(material: Material, existente: ArrayMesh = null) -> ArrayMesh:
		var m = existente if existente else ArrayMesh.new()
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(m.get_surface_count() - 1, material)
		return m

func _mesh_paredes(topo: PackedByteArray, tam: Vector2i) -> ArrayMesh:
	var malha = Malha.new()
	var usado = PackedByteArray()
	usado.resize(topo.size())
	var h = V.ALTURA_PAREDE
	var linear_topo = COR_TOPO.srgb_to_linear()
	linear_topo.a = 0.0

	# topo: retângulos greedy
	for y in tam.y:
		for x in tam.x:
			if topo[y * tam.x + x] == 0 or usado[y * tam.x + x] == 1:
				continue
			var w = 1
			while x + w < tam.x and topo[y * tam.x + x + w] == 1 and usado[y * tam.x + x + w] == 0:
				w += 1
			var alt = 1
			var ok = true
			while ok and y + alt < tam.y:
				for i in w:
					if topo[(y + alt) * tam.x + x + i] == 0 or usado[(y + alt) * tam.x + x + i] == 1:
						ok = false
						break
				if ok:
					alt += 1
			for j in alt:
				for i in w:
					usado[(y + j) * tam.x + x + i] = 1
			var p0 = Vector2(AREA.position) + Vector2(x, y) * PASSO
			var p1 = p0 + Vector2(w, alt) * PASSO
			malha.quad(V.chao(p0, h), V.chao(Vector2(p1.x, p0.y), h), V.chao(p1, h), V.chao(Vector2(p0.x, p1.y), h), Vector3.UP, linear_topo)

	# faces expostas: sul, norte (faixas em x) e leste, oeste (faixas em y)
	_faces(malha, topo, tam, true, 1)
	_faces(malha, topo, tam, true, -1)
	_faces(malha, topo, tam, false, 1)
	_faces(malha, topo, tam, false, -1)

	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/parede3d.gdshader")
	mat.set_shader_parameter("cos_angulo", V.COS)
	mat.set_shader_parameter("altura_parede", h)
	var m = malha.mesh(mat)
	print("paredes: ", malha.v.size() / 3, " triângulos")
	return m

# horizontal: faces voltadas pra +-y (faixas ao longo de x); senão pra +-x (faixas ao longo de y)
func _faces(malha: Malha, topo: PackedByteArray, tam: Vector2i, horizontal: bool, sinal: int) -> void:
	var d = Vector2i(0, sinal) if horizontal else Vector2i(sinal, 0)
	var normal = Vector3(d.x, 0, d.y)
	var h = V.ALTURA_PAREDE
	var linhas = tam.y if horizontal else tam.x
	var colunas = tam.x if horizontal else tam.y
	for l in linhas:
		var inicio = -1
		var cor_atual = 0
		for k in colunas + 1:
			var cor = 0
			if k < colunas:
				var c = Vector2i(k, l) if horizontal else Vector2i(l, k)
				var vizinho = c + d
				var vizinho_topo = vizinho.x >= 0 and vizinho.y >= 0 and vizinho.x < tam.x and vizinho.y < tam.y and topo[vizinho.y * tam.x + vizinho.x] == 1
				if topo[c.y * tam.x + c.x] == 1 and not vizinho_topo:
					# 1 = voltada pra dentro (tem chão da casa daquele lado), 2 = pra fora
					var pe = Vector2(AREA.position) + (Vector2(c) + Vector2(0.5, 0.5)) * PASSO + Vector2(d) * PASSO * 3.0
					cor = 1 if _tem_chao(pe) else 2
			if cor != cor_atual or k == colunas:
				if cor_atual != 0:
					_faixa(malha, horizontal, sinal, l, inicio, k, cor_atual, normal, h)
				inicio = k
				cor_atual = cor

func _faixa(malha: Malha, horizontal: bool, sinal: int, l: int, k0: int, k1: int, cor_id: int, normal: Vector3, h: float) -> void:
	var cor = (COR_DENTRO if cor_id == 1 else COR_FORA).srgb_to_linear()
	var linha = (l + (1 if sinal > 0 else 0)) * PASSO
	var a: Vector2
	var b: Vector2
	if horizontal:
		a = Vector2(AREA.position) + Vector2(k0 * PASSO, linha)
		b = Vector2(AREA.position) + Vector2(k1 * PASSO, linha)
	else:
		a = Vector2(AREA.position) + Vector2(linha, k0 * PASSO)
		b = Vector2(AREA.position) + Vector2(linha, k1 * PASSO)
	malha.quad(V.chao(a, 0.0), V.chao(b, 0.0), V.chao(b, h), V.chao(a, h), normal, cor)

# retângulo de um sprite centrado no mundo 2D (sem rotação), no plano y = altura 3D
func _plano(malha: Malha, s: Sprite2D, y3d: float) -> void:
	var r = s.get_rect()
	var p0 = s.global_transform * r.position
	var p1 = s.global_transform * r.end
	var cantos = [Vector3(p0.x, y3d, p0.y / V.SEN), Vector3(p1.x, y3d, p0.y / V.SEN), Vector3(p1.x, y3d, p1.y / V.SEN), Vector3(p0.x, y3d, p1.y / V.SEN)]
	var uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	malha.quad(cantos[0], cantos[1], cantos[2], cantos[3], Vector3.UP, Color.WHITE)
	# o quad empilha 6 vértices: a,b,c,a,c,d (ou a,c,b,a,d,c); acerta os uv pelos cantos
	for i in 6:
		var ponto = malha.v[malha.v.size() - 6 + i]
		for j in 4:
			if ponto.is_equal_approx(cantos[j]):
				malha.uv[malha.uv.size() - 6 + i] = uvs[j]

func _material_textura(s: Sprite2D, scissor: bool) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load(s.texture.resource_path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if scissor:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	return mat

func _mesh_chao() -> ArrayMesh:
	var malha = Malha.new()
	_plano(malha, chao_sprite, 0.0)
	return malha.mesh(_material_textura(chao_sprite, true))

func _mesh_grama() -> ArrayMesh:
	var malha = Malha.new()
	var grama = house.get_node("grama")
	# um pouco abaixo do chão, pra não brigar com ele
	_plano(malha, grama, -1.0)
	var material_grama = _material_textura(grama, false)
	material_grama.albedo_color = TOM_GRAMA
	var m = malha.mesh(material_grama)

	# plano enorme em volta, da cor média da grama, pra nunca aparecer fundo vazio
	var img = grama.texture.get_image()
	var soma = Vector3.ZERO
	var n = 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c = img.get_pixel(x, y)
			soma += Vector3(c.r, c.g, c.b)
			n += 1
	soma /= n
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(soma.x, soma.y, soma.z) * TOM_GRAMA
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var enorme = Malha.new()
	var a = Vector2(-6000, -4000)
	var b = Vector2(8000, 6000)
	enorme.quad(Vector3(a.x, -2.0, a.y), Vector3(b.x, -2.0, a.y), Vector3(b.x, -2.0, b.y), Vector3(a.x, -2.0, b.y), Vector3.UP, Color.WHITE)
	enorme.mesh(mat, m)
	return m
