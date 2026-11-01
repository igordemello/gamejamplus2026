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
var tremida: float = 0.0

func _ready() -> void:
	var tela = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var visivel = tela / zoom
	limite = Rect2(position - visivel / 2, visivel)
	zoom_alvo = zoom.x

func _process(delta: float) -> void:
	tremida = move_toward(tremida, 0.0, queda_tremida * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tremida

	# zoom é float de 32 bits, por isso não dá pra comparar com ==
	if is_equal_approx(zoom.x, zoom_alvo):
		return
	var novo = lerpf(zoom.x, zoom_alvo, minf(suavidade_zoom * delta, 1.0))
	if absf(novo - zoom_alvo) < 0.001:
		novo = zoom_alvo
	# aproxima na direção do mouse: o ponto embaixo dele não sai do lugar
	var mouse = get_viewport().get_mouse_position() - get_viewport_rect().size / 2
	position += mouse / zoom.x - mouse / novo
	zoom = Vector2.ONE * novo
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
