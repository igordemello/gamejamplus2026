extends Control

@export var tempo_lento: float = 0.25
@export var raio_icone: float = 34.0
@export var distancia_icones: float = 120.0
@export var espaco_icones: float = 92.0

@onready var painel_descricao: PanelContainer = $painel_descricao
@onready var titulo: Label = $painel_descricao/textos/titulo
@onready var descricao: Label = $painel_descricao/textos/descricao

var fantasma: Fantasma
# a bolinha é o mouse arrastado a partir de onde apertou (origem do menu)
var bolinha: Vector2 = Vector2.ZERO
# -1 = ícones em cima, 1 = embaixo (quando o fantasma está colado no topo da tela)
var sentido: float = -1.0
# 0 → 1 quando abre: os ícones saltam pra fora a partir do clique
var abertura: float = 1.0
# tamanho de cada ícone (cresce quando a bolinha entra) e o anel que pisca nessa hora
var realce: Array[float] = []
var piscada: Array[float] = []
var escolhida_antes: Acao

func abrir(f: Fantasma, onde: Vector2) -> void:
	fantasma = f
	fantasma.selecionado = true
	position = onde
	bolinha = Vector2.ZERO
	sentido = -1.0 if onde.y > distancia_icones + raio_icone + 140 else 1.0
	GameManager.mudar_tempo(tempo_lento, 0.15)
	realce.resize(f.acoes.size())
	realce.fill(1.0)
	piscada.resize(f.acoes.size())
	piscada.fill(0.0)
	escolhida_antes = null
	abertura = 0.0
	var tween = create_tween().set_ignore_time_scale()
	tween.tween_property(self, "abertura", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show()

func soltar() -> void:
	if fantasma == null:
		return
	var acao = acao_na_bolinha()
	if acao and is_instance_valid(fantasma):
		fantasma.executar(acao)
	fechar()

func fechar() -> void:
	if is_instance_valid(fantasma):
		fantasma.selecionado = false
	fantasma = null
	GameManager.mudar_tempo(1.0, 0.1)
	hide()

# saiu da casa (voltou pro menu) no meio da câmera lenta: o tempo volta ao normal
func _exit_tree() -> void:
	GameManager.tempo_normal()

func _input(event: InputEvent) -> void:
	if fantasma and event is InputEventMouseMotion:
		bolinha = (event.position - position).limit_length(distancia_icones + raio_icone)

func _process(delta: float) -> void:
	if fantasma == null:
		return
	if not is_instance_valid(fantasma):
		fechar()
		return

	var acao = acao_na_bolinha()
	# delta sem a câmera lenta, senão o realce fica arrastado
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	for i in realce.size():
		var dela = fantasma.acoes[i] == acao
		realce[i] = lerpf(realce[i], 1.25 if dela else 1.0, minf(20.0 * real, 1.0))
		piscada[i] = maxf(piscada[i] - 4.0 * real, 0.0)
		if dela and acao != escolhida_antes:
			piscada[i] = 1.0
	escolhida_antes = acao
	painel_descricao.visible = acao != null
	if acao:
		titulo.text = acao.nome
		descricao.text = acao.descricao
		if acao.propriedade_medo != &"":
			descricao.text += "\nMedo " + acao.texto_medo(fantasma)
		var borda = (distancia_icones + raio_icone + 14) * sentido
		painel_descricao.position.x = -painel_descricao.size.x / 2
		painel_descricao.position.y = borda - painel_descricao.size.y if sentido < 0 else borda
	queue_redraw()

func centro_icone(i: int) -> Vector2:
	var n = fantasma.acoes.size()
	return Vector2((i - (n - 1) / 2.0) * espaco_icones, distancia_icones * sentido)

func acao_na_bolinha() -> Acao:
	for i in fantasma.acoes.size():
		if bolinha.distance_to(centro_icone(i)) <= raio_icone:
			return fantasma.acoes[i]
	return null

func _draw() -> void:
	if fantasma == null:
		return
	var escolhida = acao_na_bolinha()
	var fonte = get_theme_default_font()

	# trilho e bolinha por baixo, então a bolinha some dentro do ícone escolhido
	draw_arc(Vector2.ZERO, 12, 0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	draw_line(Vector2.ZERO, bolinha, Color(1, 1, 1, 0.3), 3.0, true)
	draw_circle(bolinha, 10, Color.WHITE, true, -1.0, true)

	for i in fantasma.acoes.size():
		var acao = fantasma.acoes[i]
		var c = centro_icone(i) * abertura
		var r = raio_icone * abertura * realce[i]
		var falta = fantasma.recarga_restante.get(acao, 0.0)

		draw_circle(c, r, Color(0, 0, 0, 0.6), true, -1.0, true)
		if acao.icone:
			# cabe no círculo sem esticar
			var t = acao.icone.get_size()
			var tam = t * (r * 1.4 / maxf(t.x, t.y))
			draw_texture_rect(acao.icone, Rect2(c - tam / 2, tam), false, Color.WHITE if falta <= 0.0 else Color(0.35, 0.35, 0.4))

		# anel: completo quando pronta, vai fechando conforme a recarga acaba
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.2), 2.0, true)
		var progresso = 1.0 - falta / acao.recarga
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * progresso, 48, Color.WHITE, 3.0 if acao == escolhida else 2.0, true)
		if falta > 0.0:
			draw_string(fonte, c + Vector2(-r, 9), str(ceili(falta)), HORIZONTAL_ALIGNMENT_CENTER, r * 2, 26)
		# anel que abre e some quando a bolinha entra no ícone
		if piscada[i] > 0.0:
			draw_arc(c, r * (1.0 + (1.0 - piscada[i]) * 0.5), 0, TAU, 48, Color(1, 1, 1, piscada[i]), 3.0, true)
