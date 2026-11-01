extends CanvasLayer

# tela do fim: aparece quando não sobra ninguém na casa (House.terminar). vitória se cumpriu
# algum objetivo, senão "fim de festa". os números entram um a um e o rank cai carimbado no fim

const PAPEL = Color(0.86, 0.84, 0.76)
const SANGUE = Color(1, 0.25, 0.25)
# tremida do carimbo, cor da letra e o comentário de cada rank
const RANKS = {
	"S": {"tremida": 30.0, "cor": SANGUE, "texto": "Ninguém saiu vivo pra contar a história."},
	"A": {"tremida": 18.0, "cor": Color.WHITE, "texto": "Essa festa vai virar lenda urbana."},
	"B": {"tremida": 11.0, "cor": PAPEL, "texto": "Assustou direitinho. Dá pra ser pior."},
	"C": {"tremida": 6.0, "cor": Color(PAPEL, 0.55), "texto": "Pra eles, foi só uma festa meio estranha."},
}

@onready var fundo: ColorRect = $fundo
@onready var caixa: VBoxContainer = $caixa
@onready var titulo: Label = $caixa/titulo

var rank: String = "C"
var tween_fim: Tween
var animando: bool = false
var posicao_caixa: Vector2
var tempo_selo: float = 0.0
var carimbado: bool = false
# em volta da letra: desenhado no sinal draw do selo
var selo: Control
var clarao: ColorRect
var rotulo: Label
var letra: Label
var comentario: Label
var centro: Vector2
# anéis que saem do carimbo: [raio, alfa]. almas subindo (A e S): [posição, velocidade, tamanho]
var aneis: Array = []
var almas: Array = []

func _ready() -> void:
	hide()
	%jogar_de_novo.pressed.connect(_on_jogar_de_novo)
	%menu.pressed.connect(_on_menu)
	selo = Control.new()
	selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selo.set_anchors_preset(Control.PRESET_FULL_RECT)
	selo.draw.connect(desenhar_selo)
	add_child(selo)
	move_child(selo, 1)
	rotulo = criar_texto(40)
	rotulo.text = "Rank"
	letra = criar_texto(340)
	comentario = criar_texto(30)
	comentario.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comentario.custom_minimum_size.x = 500.0
	clarao = ColorRect.new()
	clarao.color = Color(1, 1, 1, 0)
	clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clarao.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(clarao)

func criar_texto(tamanho: int) -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", tamanho)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	add_child(label)
	return label

# o Esc da pausa não vale aqui; clicar durante a animação pula pro fim
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if animando and event is InputEventMouseButton and event.pressed:
		tween_fim.custom_step(60.0)
		get_viewport().set_input_as_handled()

# S só infartando todo mundo. A: dois objetivos, ou um objetivo e pelo menos metade dos convidados mortos.
# B: um objetivo. C: nenhum
static func calcular_rank(fugiram: int, mortes: int, objetivos: int) -> String:
	if fugiram == 0 and mortes > 0:
		return "S"
	if objetivos >= 2 or (objetivos >= 1 and mortes * 2 >= fugiram + mortes):
		return "A"
	return "B" if objetivos >= 1 else "C"

func mostrar(fugiram: int, mortes: int, tempo: float, venceu: bool, objetivos: int = 0) -> void:
	rank = calcular_rank(fugiram, mortes, objetivos)
	titulo.text = "Vitória!" if venceu else "Fim de festa"
	$caixa/subtitulo.text = "A casa esvaziou e você cumpriu um objetivo." if venceu else "A casa esvaziou, mas nenhum objetivo foi cumprido."
	%jogar_de_novo.text = "Jogar de novo" if venceu else "Tentar de novo"
	%fugiram.text = "%d fugiram da casa" % fugiram
	%tempo.text = "Tempo: %d:%02d" % [int(tempo) / 60, int(tempo) % 60]
	contar_mortes(0)
	get_tree().paused = true
	GameManager.tempo_normal()
	show()
	posicionar_selo()
	posicao_caixa = caixa.position

	fundo.modulate.a = 0.0
	titulo.pivot_offset = titulo.size / 2.0
	titulo.scale = Vector2(2.5, 2.5)
	titulo.modulate.a = 0.0
	var linhas = [$caixa/subtitulo, $caixa/linha_fugiram, $caixa/linha_mortes, %tempo]
	var botoes = [%jogar_de_novo, %menu]
	for no in linhas + botoes:
		no.modulate.a = 0.0
	for botao in botoes:
		botao.disabled = true

	# animando desde já: o clique pula tudo, inclusive o carimbo
	animando = true
	tween_fim = create_tween()
	tween_fim.tween_property(fundo, "modulate:a", 1.0, 0.5)
	tween_fim.tween_property(titulo, "modulate:a", 1.0, 0.2)
	tween_fim.parallel().tween_property(titulo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for no in linhas:
		tween_fim.tween_interval(0.12)
		tween_fim.tween_callback(GameManager.som.tocar_ui.bind("hover_ui"))
		tween_fim.tween_property(no, "modulate:a", 1.0, 0.15)
		if no == $caixa/linha_mortes:
			tween_fim.tween_method(contar_mortes, 0, mortes, minf(0.12 * mortes, 0.8))
	# um silêncio antes do carimbo
	tween_fim.tween_interval(0.25)
	tween_fim.tween_property(rotulo, "modulate:a", 1.0, 0.25)
	tween_fim.tween_interval(0.5)
	letra.modulate = Color(RANKS[rank].cor, 0.0)
	letra.scale = Vector2.ONE * 7.0
	tween_fim.tween_property(letra, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween_fim.parallel().tween_property(letra, "modulate:a", RANKS[rank].cor.a, 0.08)
	tween_fim.tween_callback(carimbar)
	tween_fim.tween_interval(0.45)
	for botao in botoes:
		tween_fim.parallel().tween_property(botao, "modulate:a", 1.0, 0.25)
	tween_fim.tween_callback(terminar_animacao.bind(botoes))

func contar_mortes(valor: int) -> void:
	%mortes.text = "%d morreram de susto" % valor

func terminar_animacao(botoes: Array) -> void:
	animando = false
	for botao in botoes:
		botao.disabled = false

# a letra fica à direita da caixa do texto
func posicionar_selo() -> void:
	var tela = get_viewport().get_visible_rect().size
	centro = Vector2(lerpf(tela.x / 2.0 + 360.0, tela.x, 0.5), tela.y * 0.46)
	letra.text = rank
	comentario.text = RANKS[rank].texto
	for label in [rotulo, letra, comentario]:
		label.size = label.get_minimum_size()
		label.pivot_offset = label.size / 2.0
	letra.position = centro - letra.size / 2.0
	rotulo.position = centro - Vector2(rotulo.size.x / 2.0, letra.size.y / 2.0 + 48.0)
	comentario.position = centro + Vector2(-comentario.size.x / 2.0, letra.size.y / 2.0 + 10.0)

# a letra bateu: som, clarão, anéis, tremida e o texto
func carimbar() -> void:
	carimbado = true
	var dados = RANKS[rank]
	GameManager.som.tocar_ui("caveira_pow")
	if rank != "C":
		GameManager.som.tocar_ui("vitoria")
	if rank == "S":
		GameManager.som.tocar_ui("objetivo")

	var forte = dados.tremida / 30.0
	clarao.color.a = 0.25 + 0.55 * forte
	create_tween().tween_property(clarao, "color:a", 0.0, 0.3 + 0.3 * forte)
	aneis.append([60.0, 1.0])
	if rank == "S" or rank == "A":
		aneis.append([20.0, 0.8])
		for i in 40 if rank == "S" else 16:
			soltar_alma(true)

	create_tween().tween_method(tremer, dados.tremida, 0.0, 0.45)
	letra.scale = Vector2(1.25, 0.8)
	create_tween().tween_property(letra, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	comentario.position.y += 14.0
	var texto = create_tween().set_parallel()
	texto.tween_property(comentario, "modulate:a", 1.0, 0.3).set_delay(0.15)
	texto.tween_property(comentario, "position:y", comentario.position.y - 14.0, 0.3).set_delay(0.15).set_ease(Tween.EASE_OUT)

func tremer(forca: float) -> void:
	var desvio = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))
	caixa.position = posicao_caixa + desvio * 0.5
	letra.position = centro - letra.size / 2.0 + desvio

func soltar_alma(em_volta: bool) -> void:
	var lugar = centro + Vector2(randf_range(-230.0, 230.0), randf_range(-170.0, 190.0) if em_volta else 230.0)
	almas.append([lugar, randf_range(50.0, 140.0), randf_range(3.0, 8.0)])

func _process(delta: float) -> void:
	if not visible or not carimbado:
		return
	tempo_selo += delta
	for anel in aneis:
		anel[0] += 520.0 * delta
		anel[1] = move_toward(anel[1], 0.0, 1.6 * delta)
	aneis = aneis.filter(func(a): return a[1] > 0.0)
	for alma in almas:
		alma[0].y -= alma[1] * delta
	almas = almas.filter(func(a): return a[0].y > centro.y - 300.0)
	# no S a letra respira e as almas continuam subindo
	if rank == "S":
		if randf() < 12.0 * delta:
			soltar_alma(false)
		if not animando:
			letra.scale = Vector2.ONE * (1.0 + sin(tempo_selo * 3.5) * 0.03)
	elif rank == "A" and randf() < 3.0 * delta:
		soltar_alma(false)
	selo.queue_redraw()

func desenhar_selo() -> void:
	if not carimbado:
		return
	var cor: Color = RANKS[rank].cor
	# raios girando atrás da letra
	if rank == "S" or rank == "A":
		var alcance = 330.0 if rank == "S" else 250.0
		for i in 12:
			var angulo = tempo_selo * 0.35 + TAU * i / 12.0
			var triangulo = PackedVector2Array([centro, centro + Vector2.from_angle(angulo - 0.11) * alcance, centro + Vector2.from_angle(angulo + 0.11) * alcance])
			selo.draw_colored_polygon(triangulo, Color(cor, 0.13 if rank == "S" else 0.08))
	for anel in aneis:
		selo.draw_arc(centro, anel[0], 0.0, TAU, 64, Color(cor, anel[1]), 6.0)
	# quadradinhos, como o resto da arte
	for alma in almas:
		var fim = clampf((alma[0].y - (centro.y - 300.0)) / 120.0, 0.0, 1.0)
		selo.draw_rect(Rect2(alma[0], Vector2.ONE * alma[2]), Color(1, 1, 1, 0.75 * fim))

func _on_jogar_de_novo() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/menu.tscn")
