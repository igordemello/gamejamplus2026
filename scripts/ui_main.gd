extends CanvasLayer

const FOCO = preload("res://assets/foco.gdshader")

@onready var lbl_sustos: Label = $lbl_sustos

var sustos_antes: int = 0
var tween_sustos: Tween
# sustos que ainda estão voando até o contador (só contam quando chegam)
var voando: int = 0
# tela escura em volta de alguém (infarto); criada na primeira vez
var foco: ColorRect
var foco_alvo: Node2D
var tween_foco: Tween
# escuridão (0 a 1) e raio do buraco claro, em fração da altura da tela
var foco_forca: float = 0.0
var foco_raio: float = 0.6

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sustos_antes = GameManager.sustos


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mostrados = GameManager.sustos - voando
	if mostrados != sustos_antes:
		# cresce quando ganha, encolhe quando gasta
		pular_contador(1.4 if mostrados > sustos_antes else 0.8)
		sustos_antes = mostrados
	lbl_sustos.text = "Sustos: " + str(mostrados)

	if foco and foco.visible:
		foco.material.set_shader_parameter("forca", foco_forca)
		foco.material.set_shader_parameter("raio", foco_raio)
		foco.material.set_shader_parameter("proporcao", foco.size.x / foco.size.y)
		if is_instance_valid(foco_alvo):
			var centro = foco_alvo.get_global_transform_with_canvas() * Vector2(0, -30)
			foco.material.set_shader_parameter("centro", centro / foco.size)

func pular_contador(tamanho: float) -> void:
	if tween_sustos:
		tween_sustos.kill()
	tween_sustos = create_tween().set_ignore_time_scale()
	tween_sustos.tween_property(lbl_sustos, "scale", Vector2.ONE * tamanho, 0.06)
	tween_sustos.tween_property(lbl_sustos, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# "+1" que pula da cabeça do npc (posição de tela) e voa em curva até o contador
func voar_susto(de: Vector2, quantos: int = 1) -> void:
	voando += quantos
	var texto = Label.new()
	texto.text = "+%d" % quantos
	texto.add_theme_font_size_override("font_size", 34)
	texto.add_theme_constant_override("outline_size", 10)
	texto.add_theme_color_override("font_outline_color", Color.BLACK)
	texto.position = de - Vector2(20, 20)
	texto.pivot_offset = Vector2(20, 20)
	add_child(texto)
	var destino = lbl_sustos.position + Vector2(lbl_sustos.size.x, lbl_sustos.size.y / 2.0) - Vector2(10, 20)
	# em tempo real, pra não ficar parado no hitstop
	var tween = texto.create_tween().set_ignore_time_scale()
	texto.scale = Vector2(0.3, 0.3)
	tween.tween_property(texto, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(texto, "position:y", texto.position.y - 50.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# x e y com curvas diferentes fazem o arco
	tween.tween_property(texto, "position:x", destino.x, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(texto, "position:y", destino.y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(texto, "scale", Vector2(0.6, 0.6), 0.5)
	tween.tween_callback(chegou.bind(texto, quantos))

func chegou(texto: Label, quantos: int) -> void:
	texto.queue_free()
	voando -= quantos

# texto grande que bate na tela (posição de tela), fica um pouco e some subindo
func letreiro(texto: String, de: Vector2) -> void:
	var label = Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0
	label.position = de - label.size / 2.0
	label.rotation = randf_range(-0.12, 0.12)
	label.scale = Vector2(3.0, 3.0)
	label.modulate.a = 0.0
	var tween = label.create_tween().set_ignore_time_scale()
	tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.1)
	tween.tween_interval(0.9)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.35).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)

# escurece a tela em volta de alguém, fechando até o raio (fração da altura da tela)
func focar(alvo: Node2D, raio: float) -> void:
	if foco == null:
		foco = ColorRect.new()
		foco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foco.set_anchors_preset(Control.PRESET_FULL_RECT)
		foco.material = ShaderMaterial.new()
		foco.material.shader = FOCO
		add_child(foco)
		# por baixo do resto da interface
		move_child(foco, 0)
	foco_alvo = alvo
	foco.show()
	if tween_foco:
		tween_foco.kill()
	tween_foco = create_tween().set_parallel().set_ignore_time_scale()
	tween_foco.tween_property(self, "foco_forca", 0.65, 0.25)
	tween_foco.tween_property(self, "foco_raio", raio, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func desfocar() -> void:
	if foco == null:
		return
	if tween_foco:
		tween_foco.kill()
	tween_foco = create_tween().set_parallel().set_ignore_time_scale()
	tween_foco.tween_property(self, "foco_forca", 0.0, 0.5)
	tween_foco.tween_property(self, "foco_raio", 0.6, 0.5)
	tween_foco.chain().tween_callback(foco.hide)
