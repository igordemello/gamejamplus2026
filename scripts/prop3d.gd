extends Node

# Versão 3D de um prop de debug (filho do Sprite2D). O Sprite2D continua sendo a lógica: levita, treme,
# some ao quebrar, recebe o clique. Este nó esconde ele (V.esconder) e desenha uma primitiva colorida em
# mundo3d/espelhos que, em repouso, cobre o mesmo retângulo de tela do Sprite2D (o clique 2D bate com o 3D).
#   retângulo de tela W x H = profundidade de chão d + altura h (pixels de tela): H = d + h
#   caixa 3D (W, h / COS, d / SEN) apoiada no chão, com a base da frente na base do Sprite2D
# altura 3D = quanto o Sprite2D subiu em relação ao repouso; x segue o 2D; rotação, escala, cor e o
# contorno do hover (parâmetro "cor" do material do objeto levitável) são copiados.

const V = preload("res://scripts/vista3d.gd")
# camada dos desenhos (a sombra decal no chão não pinta eles)
const CAMADA_SPRITES := 2
# a partir daqui (pixels de tela) a sombra já está no mínimo
const ALTURA_SOMBRA := 40.0

@export var cor: Color = Color(0.1, 0.9, 1.0)
@export var cilindro: bool = false
# quanto da altura do retângulo vira profundidade de chão (o resto é altura)
@export_range(0.1, 0.9) var fracao_profundidade: float = 0.45

static var textura_sombra: GradientTexture2D

var prop: Sprite2D
var malha: MeshInstance3D
var material: StandardMaterial3D
var sombra: Decal
# posição global do Sprite2D em repouso e escala de repouso
var repouso: Vector2
var escala_repouso: Vector2
# retângulo do Sprite2D em repouso (px de tela) e a divisão profundidade/altura
var retangulo: Rect2
var profundidade: float
var altura: float

func _ready() -> void:
	prop = get_parent()
	repouso = prop.global_position
	escala_repouso = prop.global_scale.abs()
	var r = prop.get_rect()
	retangulo = Rect2(r.position * escala_repouso, r.size * escala_repouso)
	profundidade = retangulo.size.y * fracao_profundidade
	altura = retangulo.size.y - profundidade
	V.esconder(prop)

func _process(_delta: float) -> void:
	if malha == null and not criar():
		return
	# a sombra 2D e qualquer outro filho do prop somem junto (nascem depois do _ready do filho)
	for filho in prop.get_children():
		if filho is CanvasItem and filho.visibility_layer != V.CAMADA_OCULTA:
			V.esconder(filho)
	var c: Color = prop.self_modulate * prop.modulate
	var mostrar = prop.is_visible_in_tree() and c.a > 0.01
	malha.visible = mostrar
	sombra.visible = mostrar
	if not mostrar:
		return
	var rel = (prop.global_scale.abs() / escala_repouso).clamp(Vector2(0.05, 0.05), Vector2(5, 5))
	var subida = maxf(repouso.y - prop.global_position.y, 0.0)
	var centro_x = prop.global_position.x + retangulo.get_center().x
	var base_y = repouso.y + retangulo.end.y
	# o chão do prop (a projeção da seta do tutorial e o espelho usam)
	prop.set_meta("chao_y", base_y)
	# a caixa fica em pé na base do retângulo: estica/amassa em volta da base
	var tamanho = Vector3(retangulo.size.x * rel.x, altura * rel.y / V.COS, profundidade * rel.x / V.SEN)
	var centro = V.chao(Vector2(centro_x, base_y - profundidade * rel.x / 2.0), subida)
	centro.y += tamanho.y / 2.0
	var b = Basis(Vector3.BACK, -prop.global_rotation) * Basis.from_scale(tamanho)
	malha.transform = Transform3D(b, centro)

	var hover = false
	if prop.material is ShaderMaterial:
		var marca = prop.material.get_shader_parameter("cor")
		hover = marca is Color and marca.a > 0.5
	var brilho = clampf(maxf(c.r, maxf(c.g, c.b)) - 1.0, 0.0, 1.0)
	material.albedo_color = Color(cor.r * minf(c.r, 1.0), cor.g * minf(c.g, 1.0), cor.b * minf(c.b, 1.0), c.a)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.emission = cor * 0.45 + Color.WHITE * (brilho * 0.6 + (0.45 if hover else 0.0))

	# sombra redonda no chão: encolhe e clareia conforme sobe
	var alt = clampf(subida / ALTURA_SOMBRA, 0.0, 1.0)
	var lado = maxf(retangulo.size.x, profundidade) * 1.35 * (1.0 - alt * 0.35)
	sombra.size = Vector3(lado, 40.0, lado / V.SEN)
	sombra.position = V.chao(Vector2(centro_x, base_y - profundidade / 2.0))
	sombra.modulate = Color(1, 1, 1, c.a * (0.8 - alt * 0.4))

func criar() -> bool:
	var espelhos = GameManager.house.get_node_or_null("mundo3d/espelhos") if is_instance_valid(GameManager.house) else null
	if espelhos == null:
		return false
	if cilindro:
		var m = CylinderMesh.new()
		m.top_radius = 0.5
		m.bottom_radius = 0.5
		m.height = 1.0
		malha = MeshInstance3D.new()
		malha.mesh = m
	else:
		malha = MeshInstance3D.new()
		malha.mesh = BoxMesh.new()
	material = StandardMaterial3D.new()
	material.roughness = 0.6
	material.emission_enabled = true
	malha.material_override = material
	malha.layers = CAMADA_SPRITES
	espelhos.add_child(malha)
	sombra = Decal.new()
	sombra.texture_albedo = criar_textura_sombra()
	sombra.cull_mask = 1
	sombra.upper_fade = 0.0
	sombra.lower_fade = 0.0
	espelhos.add_child(sombra)
	return true

static func criar_textura_sombra() -> GradientTexture2D:
	if textura_sombra == null:
		var gradiente = Gradient.new()
		gradiente.set_color(0, Color(0, 0, 0, 0.7))
		gradiente.set_color(1, Color(0, 0, 0, 0))
		textura_sombra = GradientTexture2D.new()
		textura_sombra.gradient = gradiente
		textura_sombra.fill = GradientTexture2D.FILL_RADIAL
		textura_sombra.fill_from = Vector2(0.5, 0.5)
		textura_sombra.fill_to = Vector2(1.0, 0.5)
		textura_sombra.width = 64
		textura_sombra.height = 64
	return textura_sombra

# liberar o prop libera a malha. sair da árvore (reparent do diabrete) não conta: só o delete de verdade
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for no in [malha, sombra]:
			if is_instance_valid(no):
				no.queue_free()
