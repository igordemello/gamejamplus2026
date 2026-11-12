extends AnimatedSprite3D
class_name SpritePersonagem

# Sprite de npc e fantasma com o shader assets/personagem.gdshader: fica em pé virado pra câmera,
# recebe luz e tem o contorno do hover e o brilho branco das piscadas.
# O Godot não passa a textura do quadro pra material próprio, então ela vai daqui a cada troca.

const SHADER = preload("res://assets/personagem.gdshader")

@export var contorno: bool = false:
	set(valor):
		contorno = valor
		_material().set_shader_parameter("contorno", valor)
# 0 = normal, 1 = branco
@export_range(0.0, 1.0) var brilho: float = 0.0:
	set(valor):
		brilho = valor
		_material().set_shader_parameter("brilho", valor)

# gira o desenho no plano dele em volta do pé (radianos). a rotação do nó não vale: o shader vira pra câmera
@export var giro: float = 0.0:
	set(valor):
		giro = valor
		_material().set_shader_parameter("giro", valor)

func _ready() -> void:
	frame_changed.connect(_trocar_textura)
	animation_changed.connect(_trocar_textura)
	sprite_frames_changed.connect(_trocar_textura)
	_trocar_textura()

func _material() -> ShaderMaterial:
	if not material_override is ShaderMaterial:
		material_override = ShaderMaterial.new()
		material_override.shader = SHADER
	return material_override

func _trocar_textura() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(animation):
		return
	var textura = sprite_frames.get_frame_texture(animation, frame)
	_material().set_shader_parameter("texture_albedo", textura.atlas if textura is AtlasTexture else textura)
