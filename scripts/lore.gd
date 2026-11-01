extends CanvasLayer

# lore do npc clicado (area_jogo): a câmera desliza e dá zoom nele, o mundo fica em câmera lenta e a árvore
# libera um pedaço da lore a cada nível de Npc.NIVEIS_LORE. fecha com o botão, clique fora, botão direito ou Esc

const PAPEL = Color(0.86, 0.84, 0.76)
const CADEADO = preload("res://assets/UI/cadeado.png")
const MARGEM_TELA = 40.0

# câmera lenta enquanto aberto (o mesmo valor do menu de ações)
@export var tempo_lento: float = 0.25

@onready var painel: PanelContainer = $painel
@onready var retrato: TextureRect = %retrato
@onready var nome: Label = %nome
@onready var lbl_medo: Label = %lbl_medo
@onready var medo: Control = %medo
@onready var arvore: VBoxContainer = %arvore
@onready var area_jogo = $"../UI_main/area_jogo"

var npc: Npc
var aberto: bool = false
# quantos nós da árvore estão liberados e o nível de medo que ela mostra (-1 = ainda não montou)
var liberados: int = -1
var nivel_mostrado: int = -1
# lado da tela do painel: 1 = direita (o npc fica na esquerda), -1 = esquerda
var lado: float = 1.0
# 0 → 1 quando abre: o painel desliza da borda e aparece
var entrada: float = 0.0
var tween_entrada: Tween
# cada nó da árvore: marcador (a linha e a bolinha), caixa, texto, cadeado e o pulso quando acende
var nos: Array[Dictionary] = []
var estilo_liberado: StyleBoxFlat
var estilo_bloqueado: StyleBoxFlat

func _ready() -> void:
	hide()
	%fechar.pressed.connect(fechar)
	medo.draw.connect(desenhar_medo)
	estilo_liberado = estilo_no(Color(0.17, 0.15, 0.19))
	estilo_bloqueado = estilo_no(Color(0.1, 0.085, 0.12))
	for i in Npc.NIVEIS_LORE.size():
		criar_no(i)

func estilo_no(cor: Color) -> StyleBoxFlat:
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_content_margin_all(14.0)
	return estilo

# uma linha da árvore: marcador na linha vertical e, do lado, a caixa com o texto
func criar_no(i: int) -> void:
	var linha = HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	arvore.add_child(linha)

	var marcador = Control.new()
	marcador.custom_minimum_size.x = 36.0
	marcador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcador.draw.connect(desenhar_marcador.bind(i))
	linha.add_child(marcador)

	var espaco = MarginContainer.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	espaco.add_theme_constant_override("margin_top", 7)
	espaco.add_theme_constant_override("margin_bottom", 7)
	linha.add_child(espaco)

	var caixa = PanelContainer.new()
	espaco.add_child(caixa)
	var conteudo = HBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 12)
	caixa.add_child(conteudo)

	var cadeado = TextureRect.new()
	cadeado.texture = CADEADO
	cadeado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cadeado.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	conteudo.add_child(cadeado)

	var texto = Label.new()
	texto.custom_minimum_size.x = 300.0
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_font_size_override("font_size", 26)
	conteudo.add_child(texto)
	nos.append({"marcador": marcador, "caixa": caixa, "texto": texto, "cadeado": cadeado, "pulso": 0.0})

func abrir(alvo: Npc) -> void:
	if aberto and alvo == npc:
		return
	var camera = GameManager.house.camera
	var trocando = aberto
	npc = alvo
	# onde ele cabe na tela (o limite da câmera pode empurrar): o painel vai pro outro lado
	var centro = Vector2(0.0, (alvo.topo_desenho + alvo.altura_sprite) / 2.0)
	var tela = get_viewport().get_visible_rect().size
	var x_tela = tela.x / 2.0 + (alvo.global_position.x + centro.x - camera.posicao_foco(alvo, centro, 1.0).x) * camera.zoom_foco
	lado = 1.0 if x_tela < tela.x * 0.55 else -1.0
	camera.focar(alvo, centro, lado)

	var dados = alvo.dados_lore()
	nome.text = dados.nome
	retrato.texture = alvo.sprite.sprite_frames.get_frame_texture("andar", 0)
	# uns 120 px de altura: em pixel inteiro (dobra) se o desenho é pequeno, encolhido se é grande
	var tamanho = retrato.texture.get_size()
	var fator = 120.0 / tamanho.y
	retrato.custom_minimum_size = tamanho * (roundf(fator) if fator >= 1.0 else fator)
	liberados = -1
	atualizar(false)

	if not aberto:
		aberto = true
		GameManager.mudar_tempo(tempo_lento, 0.15)
	# trocar de npc dá um empurrãozinho no painel
	if trocando:
		entrada = 0.5
	if tween_entrada:
		tween_entrada.kill()
	tween_entrada = create_tween().set_ignore_time_scale().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_entrada.tween_property(self, "entrada", 1.0, 0.25)
	show()
	posicionar()

# volta_tempo = false quando quem fechou já cuida do tempo (menu de ações, arraste de carta)
func fechar(volta_tempo: bool = true) -> void:
	if not aberto:
		return
	aberto = false
	npc = null
	var casa = GameManager.house
	if is_instance_valid(casa):
		casa.camera.soltar_foco()
	if volta_tempo:
		GameManager.mudar_tempo(1.0, 0.1)
	if tween_entrada:
		tween_entrada.kill()
	tween_entrada = create_tween().set_ignore_time_scale()
	tween_entrada.tween_property(self, "entrada", 0.0, 0.15)
	tween_entrada.tween_callback(func():
		if not aberto:
			hide())

# saiu da casa (menu principal) com a lore aberta: o tempo volta ao normal
func _exit_tree() -> void:
	if aberto:
		GameManager.tempo_normal()

func _input(event: InputEvent) -> void:
	if not aberto:
		return
	if event.is_action_pressed("ui_cancel"):
		# o Esc é só da lore: a pausa não abre junto
		fechar()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			fechar()
		elif event.button_index == MOUSE_BUTTON_LEFT and not painel.get_global_rect().has_point(event.position):
			# clique fora fecha, menos em outro npc: aí a area_jogo troca o foco (fantasma na frente tem prioridade)
			if area_jogo.fantasma_sob_mouse() or area_jogo.npc_sob_mouse() == null:
				fechar()

func _process(_delta: float) -> void:
	if not visible:
		return
	posicionar()
	if not aberto:
		return
	# saiu da festa, infartou ou foi liberado
	if not is_instance_valid(npc) or not npc.is_in_group("npc") or npc.current_estado == Npc.Estado.Infarta:
		fechar()
	# pegou uma carta da loja: ela cuida do tempo
	elif get_viewport().gui_is_dragging():
		fechar(false)
	elif npc.nivel_medo != nivel_mostrado:
		atualizar(true)

func posicionar() -> void:
	var tela = get_viewport().get_visible_rect().size
	painel.modulate.a = entrada
	painel.reset_size()
	var x = tela.x - painel.size.x - MARGEM_TELA if lado > 0.0 else MARGEM_TELA
	painel.position = Vector2(x + (1.0 - entrada) * 80.0 * lado, maxf((tela.y - painel.size.y) / 2.0 - 40.0, 16.0))

# monta a árvore pro nível de medo de agora; acender = um nó que liberou agora brilha
func atualizar(acender: bool) -> void:
	var nivel = npc.nivel_medo
	var antes = liberados
	nivel_mostrado = nivel
	liberados = Npc.NIVEIS_LORE.filter(func(n): return n <= nivel).size()
	var textos: PackedStringArray = npc.dados_lore().lore
	lbl_medo.text = "Nível de medo %d" % nivel
	medo.queue_redraw()
	for i in nos.size():
		var no = nos[i]
		var texto: Label = no.texto
		var liberado = i < liberados
		no.caixa.add_theme_stylebox_override("panel", estilo_liberado if liberado else estilo_bloqueado)
		no.cadeado.visible = not liberado
		if liberado:
			var lore = textos[i] if i < textos.size() else ""
			texto.text = lore if lore != "" else "..."
			texto.add_theme_color_override("font_color", PAPEL if lore != "" else Color(PAPEL, 0.4))
		elif i == liberados:
			texto.text = "Atinja nível de medo %d para desbloquear mais informações" % Npc.NIVEIS_LORE[i]
			texto.add_theme_color_override("font_color", Color(PAPEL, 0.7))
			no.cadeado.modulate.a = 0.7
		else:
			texto.text = "???"
			texto.add_theme_color_override("font_color", Color(PAPEL, 0.35))
			no.cadeado.modulate.a = 0.35
		no.marcador.queue_redraw()
		if acender and liberado and i >= antes:
			acender_no(i)

# o nó que acabou de liberar dá um pulinho, brilha e solta um anel na linha
func acender_no(i: int) -> void:
	var no = nos[i]
	var caixa: Control = no.caixa
	caixa.pivot_offset = caixa.size / 2.0
	caixa.scale = Vector2(1.05, 1.05)
	caixa.modulate = Color(2.2, 2.2, 2.2)
	var tween = create_tween().set_parallel().set_ignore_time_scale()
	tween.tween_property(caixa, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(caixa, "modulate", Color.WHITE, 0.6)
	tween.tween_method(pulsar_no.bind(i), 1.0, 0.0, 0.6)

func pulsar_no(valor: float, i: int) -> void:
	nos[i].pulso = valor
	nos[i].marcador.queue_redraw()

# a linha vertical liga um nó ao seguinte (acesa até onde está liberado) e a bolinha marca o nó
func desenhar_marcador(i: int) -> void:
	var m: Control = nos[i].marcador
	var centro = m.size / 2.0
	var acesa = Color(PAPEL, 0.8)
	var apagada = Color(PAPEL, 0.22)
	if i > 0:
		m.draw_line(Vector2(centro.x, 0.0), centro, acesa if i < liberados else apagada, 3.0)
	if i < nos.size() - 1:
		m.draw_line(centro, Vector2(centro.x, m.size.y), acesa if i + 1 < liberados else apagada, 3.0)
	if i < liberados:
		m.draw_circle(centro, 10.0, PAPEL)
	else:
		m.draw_circle(centro, 9.0, Color(0.05, 0.04, 0.06))
		m.draw_arc(centro, 8.0, 0.0, TAU, 24, Color(PAPEL, 0.7 if i == liberados else 0.3), 3.0, true)
	var pulso: float = nos[i].pulso
	if pulso > 0.0:
		m.draw_arc(centro, 10.0 + (1.0 - pulso) * 20.0, 0.0, TAU, 32, Color(PAPEL, pulso), 3.0, true)

# os 5 quadradinhos de nível, iguais aos do medidor em cima do npc
func desenhar_medo() -> void:
	for i in 5:
		var quadrado = Rect2(i * 26.0, 2.0, 18.0, 18.0)
		medo.draw_rect(quadrado, PAPEL if i < nivel_mostrado else Color(PAPEL, 0.2))
