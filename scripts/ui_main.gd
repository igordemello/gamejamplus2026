extends CanvasLayer

@onready var lbl_sustos: Label = $lbl_sustos

var sustos_antes: int = 0
var tween_sustos: Tween
# sustos que ainda estão voando até o contador (só contam quando chegam)
var voando: int = 0

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

func pular_contador(tamanho: float) -> void:
	if tween_sustos:
		tween_sustos.kill()
	tween_sustos = create_tween().set_ignore_time_scale()
	tween_sustos.tween_property(lbl_sustos, "scale", Vector2.ONE * tamanho, 0.06)
	tween_sustos.tween_property(lbl_sustos, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# "+1" que pula da cabeça do npc (posição de tela) e voa em curva até o contador
func voar_susto(de: Vector2) -> void:
	voando += 1
	var texto = Label.new()
	texto.text = "+1"
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
	tween.tween_callback(chegou.bind(texto))

func chegou(texto: Label) -> void:
	texto.queue_free()
	voando -= 1
