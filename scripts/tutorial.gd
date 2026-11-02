extends CanvasLayer

@export var objeto_levitavel: Sprite2D

# tutorial do começo: uma frase por passo num painel no topo, com o jogo rodando atrás e o destaque
# no que ela fala (controle da tela pulsando, ou seta e brilho em cima de algo do mundo).
# os passos com "feito" passam sozinhos quando o jogador faz o que foi pedido.
# a casa chama comecar() toda vez que a partida começa; a pausa tem "Como jogar"

@onready var texto: Label = %texto
@onready var proximo: Button = %proximo
@onready var seta: Node2D = $seta

var house
var passos: Array = []
var atual: int = 0
# tempo real (a câmera lenta do menu de ações não atrasa o tutorial)
var tempo: float = 0.0
var tempo_passo: float = 0.0
# controle da tela que pulsa no passo atual
var destaque: CanvasItem
# coisa do mundo que pulsa e leva a seta em cima, resolvida todo quadro pelo "alvo" do passo
var alvo: CanvasItem
# como estava quando o passo começou, pra saber se o jogador já fez
var zoom_inicial: float
var arrastado_inicial: float
var fantasmas_inicial: int
var concluido: bool = false
# o painel é de papel. no primeiro passo ele fica no meio da tela, com o resto escurecido, e depois sobe pro topo
const ALTURA_TOPO = 16.0
@onready var painel: PanelContainer = $painel
var estilo: StyleBoxFlat
var fundo: ColorRect
var contagem: Label
var tween_painel: Tween

func _ready() -> void:
	hide()
	%pular.pressed.connect(terminar)
	proximo.pressed.connect(avancar)
	seta.draw.connect(desenhar_seta)
	estilo = StyleBoxFlat.new()
	estilo.bg_color = Color(0.86, 0.84, 0.76)
	painel.add_theme_stylebox_override("panel", estilo)
	fundo = ColorRect.new()
	fundo.color = Color(0, 0, 0, 0)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	move_child(fundo, 0)
	contagem = Label.new()
	contagem.add_theme_font_size_override("font_size", 22)
	contagem.add_theme_color_override("font_color", Color(0.36, 0.34, 0.3))
	contagem.position = Vector2(14, 2)
	contagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(contagem)
	contagem.top_level = true

func comecar(casa) -> void:
	house = casa
	var cam = house.camera
	passos = [
		{"texto": "Assuste todo mundo da festa até a casa ficar vazia."},
		{"texto": "Segure o botão esquerdo no objeto que flutua: ele assusta quem estiver no cômodo.",
			"alvo": func(): return objeto_levitavel if is_instance_valid(objeto_levitavel) and objeto_levitavel.is_in_group("levitavel") else null,
			"feito": func(): return GameManager.sustos >= 6},
		{"texto": "Cada nível de medo vale 1 susto.",
			"destaque": house.ui.get_node("contadores/sustos"), "auto": 4.0},
		{"texto": "Junte sustos e arraste uma carta do baralho pra casa.",
			"destaque": house.ui.get_node("painel_fantasmas"),
			"feito": func(): return get_tree().get_nodes_in_group("fantasma").size() > fantasmas_inicial},
		{"texto": "Segure o botão esquerdo no fantasma e solte numa ação.",
			"alvo": ultimo_fantasma,
			"feito": func(): return get_tree().get_nodes_in_group("fantasma").any(func(f): return f.recarga_restante.values().any(func(r): return r > 0.0))},
		{"texto": "Rodinha: zoom. Botão direito: arrasta a câmera.",
			"feito": func(): return absf(cam.zoom_alvo - zoom_inicial) > 0.01 or cam.arrastado - arrastado_inicial > 100.0},
		{"texto": "Mate quem tem a caveira ou outro objetivo. Clique num convidado pra ver como.",
			"destaque": house.ui.get_node("objetivos"), "abrir_objetivos": true},
		{"texto": "Com %d mortes a polícia vem. Esc pausa. Boa assombração!" % house.limite_mortes},
	]
	atual = -1
	show()
	fundo.color.a = 0.6
	avancar()

func avancar() -> void:
	apagar_destaques()
	atual += 1
	if atual >= passos.size():
		terminar()
		return
	var passo = passos[atual]
	texto.text = passo.texto
	proximo.text = "Começar" if atual == passos.size() - 1 else "Próximo"
	destaque = passo.get("destaque")
	concluido = false
	mostrar_painel()
	tempo_passo = 0.0
	zoom_inicial = house.camera.zoom_alvo
	arrastado_inicial = house.camera.arrastado
	fantasmas_inicial = get_tree().get_nodes_in_group("fantasma").size()
	# o painel de objetivos se fecha sozinho: no passo dele ele abre de novo
	if passo.get("abrir_objetivos", false):
		house.ui.abrir_objetivos(true)

# cada passo entra caindo e dando um tranco, com um somzinho
func mostrar_painel() -> void:
	GameManager.som.tocar_ui("carta_pegar")
	contagem.text = "Tutorial %d/%d" % [atual + 1, passos.size()]
	var tela = get_viewport().get_visible_rect().size
	var altura = (tela.y - painel.size.y) * 0.4 if atual == 0 else ALTURA_TOPO
	painel.pivot_offset = painel.size / 2.0
	if tween_painel:
		tween_painel.kill()
	tween_painel = create_tween().set_parallel().set_ignore_time_scale()
	painel.scale = Vector2.ONE * 1.25
	tween_painel.tween_property(painel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if atual == 0:
		painel.position.y = altura
	else:
		tween_painel.tween_property(painel, "position:y", altura, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_painel.tween_property(fundo, "color:a", 0.0, 0.35)

func _process(delta: float) -> void:
	if atual < 0 or atual >= passos.size():
		return
	# a cada 4 s parado no mesmo passo, um tranquinho pra chamar o olho
	contagem.global_position = painel.global_position + Vector2(16, 6)
	if tempo_passo > 4.0 and fmod(tempo_passo, 4.0) < 0.05 and not (tween_painel and tween_painel.is_running()):
		painel.pivot_offset = painel.size / 2.0
		painel.scale = Vector2.ONE * 1.06
		tween_painel = create_tween().set_ignore_time_scale()
		tween_painel.tween_property(painel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	tempo += real
	tempo_passo += real
	var passo = passos[atual]
	var brilho = Color.WHITE.lerp(Color(1.8, 1.8, 1.8), 0.5 + 0.5 * sin(tempo * 6.0))
	if destaque:
		destaque.modulate = brilho
	# o alvo do mundo pode mudar de um quadro pro outro (o fantasma só existe depois do pentagrama)
	var novo = passo["alvo"].call() if passo.has("alvo") else null
	if novo != alvo:
		tirar_brilho(alvo)
		alvo = novo
	if is_instance_valid(alvo):
		brilho.a = alvo.modulate.a
		alvo.modulate = brilho
	seta.queue_redraw()

	var feito = passo.get("feito")
	if feito and not concluido and feito.call():
		# fez o que o passo pedia: mostra que deu certo e passa sozinho
		concluido = true
		proximo.text = "Boa!"
		var passo_agora = atual
		get_tree().create_timer(0.8, true, false, true).timeout.connect(func():
			if atual == passo_agora:
				avancar())
	elif passo.has("auto") and not concluido and tempo_passo >= passo["auto"]:
		avancar()

func terminar() -> void:
	apagar_destaques()
	fundo.color.a = 0.0
	atual = passos.size()
	hide()

# o fantasma invocado mais recente (null enquanto o pentagrama ainda não soltou nenhum)
func ultimo_fantasma() -> Node:
	var fantasmas = get_tree().get_nodes_in_group("fantasma")
	return null if fantasmas.is_empty() else fantasmas.back()

# o brilho de quem pulsa volta ao normal (só a cor: o alfa do fantasma aparecendo é de outro tween)
func tirar_brilho(no: CanvasItem) -> void:
	if is_instance_valid(no):
		no.modulate = Color(1, 1, 1, no.modulate.a)

func apagar_destaques() -> void:
	tirar_brilho(destaque)
	tirar_brilho(alvo)
	destaque = null
	alvo = null
	seta.queue_redraw()

# topo do desenho do alvo na tela (acompanha a câmera e o zoom)
func topo_na_tela(no: CanvasItem) -> Vector2:
	if no is Fantasma:
		var sprite: AnimatedSprite2D = no.get_node("AnimatedSprite2D")
		return sprite.get_global_transform_with_canvas() * sprite.offset - Vector2(0, no.raio_clique * house.camera.zoom.x)
	var retangulo = no.get_rect()
	return no.get_global_transform_with_canvas() * Vector2(retangulo.get_center().x, retangulo.position.y)

# seta grande quicando, com a ponta em cima do alvo
func desenhar_seta() -> void:
	if not is_instance_valid(alvo):
		return
	var ponta = topo_na_tela(alvo) - Vector2(0, 8.0 + absf(sin(tempo * 4.5)) * 18.0)
	var forma = PackedVector2Array([Vector2(0, 0), Vector2(-30, -36), Vector2(-13, -36), Vector2(-13, -76),
		Vector2(13, -76), Vector2(13, -36), Vector2(30, -36)])
	for i in forma.size():
		forma[i] += ponta
	seta.draw_colored_polygon(forma, Color(1, 0.85, 0.2))
	forma.append(forma[0])
	seta.draw_polyline(forma, Color(0.55, 0.3, 0.05), 3.0)
