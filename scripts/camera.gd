extends Camera2D

@export var zoom_min: float = 0.8
@export var zoom_max: float = 1.5
@export var passo_zoom: float = 0.1
# quanto maior, mais rápido o zoom chega onde o scroll mandou
@export var suavidade_zoom: float = 8.0
# quanto a tremida perde por segundo
@export var queda_tremida: float = 40.0

# o que a câmera mostra do jeito que está no editor é a borda: ela nunca mostra além disso
var limite: Rect2
var zoom_alvo: float
# o zoom do scroll; o zoom de verdade é esse mais o tranco
var zoom_atual: float
var tremida: float = 0.0
var tranco: float = 0.0

func _ready() -> void:
	var tela = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var visivel = tela / zoom
	limite = Rect2(position - visivel / 2, visivel)
	zoom_alvo = zoom.x
	zoom_atual = zoom.x

func _process(delta: float) -> void:
	# tremida e tranco em tempo real: continuam durante o hitstop e a câmera lenta
	# (com teto: no frame em que o time_scale muda o delta ainda vem do jeito antigo)
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	tremida = move_toward(tremida, 0.0, queda_tremida * real)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tremida
	tranco = lerpf(tranco, 0.0, minf(10.0 * real, 1.0)) if tranco > 0.0005 else 0.0

	var zoom_antes = zoom.x
	if not is_equal_approx(zoom_atual, zoom_alvo):
		var novo = lerpf(zoom_atual, zoom_alvo, minf(suavidade_zoom * delta, 1.0))
		if absf(novo - zoom_alvo) < 0.001:
			novo = zoom_alvo
		# aproxima na direção do mouse: o ponto embaixo dele não sai do lugar
		var mouse = get_viewport().get_mouse_position() - get_viewport_rect().size / 2
		position += mouse / zoom_atual - mouse / novo
		zoom_atual = novo
	zoom = Vector2.ONE * zoom_atual * (1.0 + tranco)
	if zoom.x != zoom_antes:
		prender()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_alvo = clampf(zoom_alvo + passo_zoom, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_alvo = clampf(zoom_alvo - passo_zoom, zoom_min, zoom_max)

	# segurando o botão direito arrasta o mapa junto com o mouse
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		position -= event.relative / zoom
		prender()

func prender() -> void:
	var meio = (get_viewport_rect().size / zoom / 2).min(limite.size / 2)
	position = position.clamp(limite.position + meio, limite.end - meio)

# chacoalha a tela; se já estiver tremendo mais forte, fica a mais forte
func tremer(forca: float) -> void:
	tremida = maxf(tremida, forca)

# aproxima de repente um tiquinho e volta (0.03 = 3%)
func chutar(forca: float) -> void:
	tranco = maxf(tranco, forca)
