extends Control

# os fantasmas que estão na casa, em ícones embaixo do ímã. mouse em cima acende o contorno dele no mapa,
# clique aproxima a câmera dele. o ui_main cria isso

const LADO = 52.0
const ESPACO = 8.0
const TOPO = 34.0
const COLUNAS = 2
# passando disso, mais colunas (senão a lista desceria até as cartas)
const POR_COLUNA = 10

var itens: Array = []
var hover: int = -1
# deslocamento do ícone embaixo do mouse, de 0 a 1
var realce: float = 0.0
var soco: Array = []

func _ready() -> void:
	position = Vector2(16, 270)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): trocar_hover(-1))
	hide()

func _process(delta: float) -> void:
	atualizar_itens()
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	realce = lerpf(realce, 1.0 if hover >= 0 else 0.0, minf(15.0 * real, 1.0))
	for i in soco.size():
		soco[i] = maxf(soco[i] - 4.0 * real, 0.0)
	if visible:
		queue_redraw()

# entra quem foi invocado; quem não existe mais sai
func atualizar_itens() -> void:
	var fantasmas = get_tree().get_nodes_in_group("fantasma")
	var antes = itens.size()
	for i in range(itens.size() - 1, -1, -1):
		if not is_instance_valid(itens[i].fantasma):
			itens.remove_at(i)
			soco.remove_at(i)
	for fantasma in fantasmas:
		if not itens.any(func(item): return item.fantasma == fantasma):
			itens.append(novo_item(fantasma))
			soco.append(1.0)
	if itens.size() != antes:
		hover = -1
		var colunas = colunas_agora()
		var linhas = ceili(itens.size() / float(colunas))
		size = Vector2(colunas * (LADO + ESPACO), TOPO + linhas * (LADO + ESPACO))
		visible = not itens.is_empty()

func colunas_agora() -> int:
	return maxi(COLUNAS, ceili(itens.size() / float(POR_COLUNA)))

# ícone e nome vêm da carta dele; sem carta (invocado por outro meio), do próprio desenho
func novo_item(fantasma: Node) -> Dictionary:
	var item = {"fantasma": fantasma, "icone": null, "nome": String(fantasma.name)}
	for carta in get_parent().get_node("painel_fantasmas/lista").get_children():
		if carta.cena and carta.cena.resource_path == fantasma.scene_file_path:
			item.icone = carta.icone
			item.nome = carta.get_node("nome").text.replace("\n", " ")
	if item.icone == null:
		var sprite: AnimatedSprite2D = fantasma.get_node("AnimatedSprite2D")
		item.icone = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	return item

func retangulo(i: int) -> Rect2:
	var colunas = colunas_agora()
	return Rect2(Vector2((i % colunas) * (LADO + ESPACO), TOPO + (i / colunas) * (LADO + ESPACO)), Vector2.ONE * LADO)

func item_em(pos: Vector2) -> int:
	for i in itens.size():
		if retangulo(i).has_point(pos):
			return i
	return -1

func trocar_hover(novo: int) -> void:
	if novo == hover:
		return
	if hover >= 0 and hover < itens.size() and is_instance_valid(itens[hover].fantasma):
		itens[hover].fantasma.destacado = false
	hover = novo
	if hover >= 0:
		itens[hover].fantasma.destacado = true
		GameManager.som.tocar_ui("hover_ui")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		trocar_hover(item_em(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i = item_em(event.position)
		if i >= 0:
			accept_event()
			soco[i] = 1.0
			GameManager.som.tocar_ui("hover_carta")
			GameManager.house.camera.aproximar_de(itens[i].fantasma.global_position)

func _get_tooltip(at_position: Vector2) -> String:
	var i = item_em(at_position)
	return itens[i].nome if i >= 0 else ""

func _draw() -> void:
	draw_string(get_theme_default_font(), Vector2(0, TOPO - 10.0), "Fantasmas", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	for i in itens.size():
		var caixa = retangulo(i)
		var em_cima = i == hover
		var cresce = (0.12 * realce if em_cima else 0.0) + 0.2 * soco[i]
		caixa = caixa.grow(LADO * cresce / 2.0)
		draw_rect(caixa, Color(0.05, 0.04, 0.06, 0.92))
		if em_cima:
			draw_rect(caixa, Color.WHITE, false, 2.0)
		# cabe no quadrado sem esticar
		var icone: Texture2D = itens[i].icone
		var tamanho = icone.get_size()
		var fator = (caixa.size.x - 8.0) / maxf(tamanho.x, tamanho.y)
		var desenho = tamanho * fator
		draw_texture_rect(icone, Rect2(caixa.get_center() - desenho / 2.0, desenho), false)
