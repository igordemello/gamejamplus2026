extends CanvasLayer

const FOCO = preload("res://assets/foco.gdshader")
# objetivo em andamento (tom de papel), feito (branco) e falhou (apagado)
const COR_LINHA = [Color(0.86, 0.84, 0.76), Color.WHITE, Color(0.5, 0.5, 0.5)]

@onready var lbl_sustos: Label = $contadores/sustos/lbl_sustos
@onready var lbl_mortes: Label = $contadores/mortes/lbl_mortes
# o "+1" voa até esse ícone
@onready var icone_sustos: Control = $contadores/sustos/icone
@onready var painel_objetivos: PanelContainer = $objetivos
@onready var recorte_objetivos: Control = $objetivos/margem/coluna/recorte
@onready var objetivos: VBoxContainer = $objetivos/margem/coluna/recorte/corpo
@onready var botao_objetivos: Button = $objetivos/margem/coluna/cabecalho/botao
@onready var resumo_objetivos: Label = $objetivos/margem/coluna/cabecalho/resumo
# o painel de objetivos começa aberto e se fecha sozinho depois de tempo_objetivos; toda vez que abre
# de novo (botão, tutorial) fecha depois de tempo_reaberto, e um objetivo que muda abre por tempo_aviso.
# com o mouse em cima ele não fecha
@export var tempo_objetivos: float = 12.0
@export var tempo_reaberto: float = 8.0
@export var tempo_aviso: float = 6.0
var objetivos_abertos: bool = true
var restante_objetivos: float = 0.0
# 1 = aberto, 0 = só a barra do cabeçalho (anima entre os dois)
var abertura_objetivos: float = 1.0
var tween_objetivos: Tween
# cada linha de objetivo: 0 em andamento, 1 feito, 2 falhou (pra abrir o painel quando muda)
var estado_linhas: Dictionary = {}
# retrato de cada marcado no painel de objetivos
var retratos: Dictionary = {}

# o tempo que falta até amanhecer, embaixo dos contadores
var relogio: Label
# o poder do jogador, embaixo do relógio
var poder: Control
# os fantasmas que estão na casa, embaixo do ímã
var lista_fantasmas: Control
var sustos_antes: int = 0
var mortes_antes: int = 0
var tween_sustos: Tween
var tween_mortes: Tween
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
	botao_objetivos.pressed.connect(func(): abrir_objetivos(not objetivos_abertos))
	botao_objetivos.draw.connect(desenhar_seta)
	restante_objetivos = tempo_objetivos
	mostrar_objetivos(1.0)
	relogio = Label.new()
	relogio.add_theme_font_size_override("font_size", 34)
	relogio.mouse_filter = Control.MOUSE_FILTER_PASS
	relogio.tooltip_text = "Tempo\nQuando acabar, amanhece e todo mundo vai embora da festa."
	$contadores.add_child(relogio)
	poder = preload("res://scripts/poder_atrair.gd").new()
	add_child(poder)
	lista_fantasmas = preload("res://scripts/lista_fantasmas.gd").new()
	add_child(lista_fantasmas)
	sustos_antes = GameManager.sustos
	mortes_antes = GameManager.mortes
	if GameManager.toque:
		# celular não tem Esc: botão de pausa no canto, e os objetivos chegam pro lado
		var pausar = Button.new()
		pausar.text = "II"
		pausar.add_theme_font_size_override("font_size", 32)
		pausar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pausar.offset_left = -84
		pausar.offset_top = 10
		pausar.offset_right = -16
		pausar.offset_bottom = 78
		pausar.pressed.connect(func(): get_parent().get_node("pausa").pausar())
		add_child(pausar)
		painel_objetivos.offset_left -= 78
		painel_objetivos.offset_right -= 78
	$contadores/mortes.tooltip_text = "Mortes\nQuantas pessoas morreram de susto. Com %d mortes a polícia é chamada." % get_parent().limite_mortes


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mostrados = GameManager.sustos - voando
	if mostrados != sustos_antes:
		# cresce quando ganha, encolhe quando gasta
		tween_sustos = pular(lbl_sustos, tween_sustos, 1.4 if mostrados > sustos_antes else 0.8)
		sustos_antes = mostrados
	lbl_sustos.text = str(mostrados)
	if GameManager.mortes != mortes_antes:
		tween_mortes = pular(lbl_mortes, tween_mortes, 1.6)
		mortes_antes = GameManager.mortes
	lbl_mortes.text = str(GameManager.mortes)
	# fica mais vermelho conforme chega perto do limite (a polícia)
	lbl_mortes.add_theme_color_override("font_color", Color.WHITE.lerp(Color(1, 0.15, 0.15), clampf(GameManager.mortes / float(get_parent().limite_mortes), 0.0, 1.0)))
	atualizar_objetivos()
	atualizar_relogio()
	if objetivos_abertos:
		# com o mouse em cima não fecha: some uns instantes depois que ele sair
		if GameManager.hover_valido() and painel_objetivos.get_global_rect().has_point(get_viewport().get_mouse_position()):
			restante_objetivos = maxf(restante_objetivos, 1.5)
		restante_objetivos -= minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
		if restante_objetivos <= 0.0:
			abrir_objetivos(false)
	# o texto muda e o painel acompanha o tamanho
	mostrar_objetivos(abertura_objetivos)

	if foco and foco.visible:
		foco.material.set_shader_parameter("forca", foco_forca)
		foco.material.set_shader_parameter("raio", foco_raio)
		foco.material.set_shader_parameter("proporcao", foco.size.x / foco.size.y)
		if is_instance_valid(foco_alvo):
			var centro = foco_alvo.get_global_transform_with_canvas() * Vector2(0, -30)
			foco.material.set_shader_parameter("centro", centro / foco.size)

func mostrar_marcados(marcados: Array) -> void:
	for npc in marcados:
		var retrato = TextureRect.new()
		retrato.texture = npc.sprite.sprite_frames.get_frame_texture("andar", 0)
		retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		retrato.custom_minimum_size = Vector2(40, 52)
		retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
		objetivos.get_node("retratos").add_child(retrato)
		retratos[npc] = retrato

# marcado morreu (vermelho) ou fugiu vivo (apagado)
func marcar_retrato(npc, morreu: bool) -> void:
	if retratos.has(npc):
		retratos[npc].modulate = Color(1, 0.25, 0.25, 0.7) if morreu else Color(0.4, 0.4, 0.4, 0.4)

# no último minuto o relógio fica vermelho e pulsa
func atualizar_relogio() -> void:
	var casa = get_parent()
	var falta = maxf(casa.tempo_limite - casa.tempo_partida, 0.0)
	relogio.text = "%d:%02d" % [int(ceilf(falta)) / 60, int(ceilf(falta)) % 60]
	if falta <= 60.0:
		relogio.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
		relogio.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 150.0)

# fechado fica só a barrinha do cabeçalho (título, resumo e botão); abre e fecha deslizando
func abrir_objetivos(abrir: bool = true, tempo: float = -1.0) -> void:
	restante_objetivos = tempo if tempo > 0.0 else tempo_reaberto
	if abrir == objetivos_abertos:
		return
	objetivos_abertos = abrir
	if tween_objetivos:
		tween_objetivos.kill()
	tween_objetivos = create_tween().set_ignore_time_scale()
	tween_objetivos.tween_method(mostrar_objetivos, abertura_objetivos, 1.0 if abrir else 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# um objetivo mudou de estado: abre sozinho um pouco (se já está aberto, só garante o tempo)
func avisar_objetivos() -> void:
	if objetivos_abertos:
		restante_objetivos = maxf(restante_objetivos, tempo_aviso)
	else:
		abrir_objetivos(true, tempo_aviso)

# t de 0 a 1: o corpo do painel encolhe (cortado, subindo e sumindo) e o resumo aparece na barra
func mostrar_objetivos(t: float) -> void:
	abertura_objetivos = t
	recorte_objetivos.visible = t > 0.0
	recorte_objetivos.custom_minimum_size.y = objetivos.get_combined_minimum_size().y * t
	# offset, não position: o corpo é ancorado e position fixaria a largura que ele tem na hora
	objetivos.offset_top = -(1.0 - t) * 18.0
	objetivos.modulate.a = t
	resumo_objetivos.modulate.a = 1.0 - t
	botao_objetivos.queue_redraw()
	# o painel só cresce sozinho: encolhe de volta ao tamanho do que sobrou
	painel_objetivos.reset_size()

# triângulo no botão: aponta pra baixo fechado (abrir) e gira pra cima aberto (fechar)
func desenhar_seta() -> void:
	var modo = botao_objetivos.get_draw_mode()
	var cor = botao_objetivos.get_theme_color("font_pressed_color" if modo in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else "font_hover_color" if modo == BaseButton.DRAW_HOVER else "font_color")
	botao_objetivos.draw_set_transform(botao_objetivos.size / 2.0, PI * abertura_objetivos)
	botao_objetivos.draw_colored_polygon(PackedVector2Array([Vector2(-8, -4), Vector2(8, -4), Vector2(0, 5)]), cor)

func atualizar_objetivos() -> void:
	var h = get_parent()
	var restam = get_tree().get_nodes_in_group("npc").size()
	objetivos.get_node("casa").text = "Tirar todo mundo da casa (restam %d)" % restam
	linha(objetivos.get_node("marcados"), ("Matar o marcado" if h.quantos_marcados == 1 else "Matar os %d marcados (%d/%d)" % [h.quantos_marcados, h.marcados_mortos, h.quantos_marcados]),
		h.objetivo_marcados, h.marcado_escapou)
	linha(objetivos.get_node("comodos"), "Assustar em todos os cômodos juntos (%d/%d)" % [h.comodos_assustados(), h.regionsHouse.size()],
		h.objetivo_comodos, false)
	linha(objetivos.get_node("policial"), "Matar um policial" + ("" if h.policia_chamada else " (vem com %d mortes)" % h.limite_mortes),
		h.objetivo_policial, false)
	# o que aparece na barra com o painel fechado
	var feitos = int(h.objetivo_marcados) + int(h.objetivo_comodos) + int(h.objetivo_policial)
	resumo_objetivos.text = "%d feito%s" % [feitos, "" if feitos == 1 else "s"] if feitos > 0 else ""

# a cor só muda quando o estado muda (e aí o painel abre pra mostrar)
func linha(lbl: Label, texto: String, feito: bool, falhou: bool) -> void:
	var estado = 1 if feito else 2 if falhou else 0
	if estado != estado_linhas.get(lbl, 0):
		estado_linhas[lbl] = estado
		lbl.add_theme_color_override("font_color", COR_LINHA[estado])
		avisar_objetivos()
		if feito:
			GameManager.som.tocar_ui("objetivo")
	if feito:
		lbl.text = texto + " - feito!"
	elif falhou:
		lbl.text = texto + " - falhou"
	else:
		lbl.text = texto

# o número cresce (ou encolhe) do meio e volta
func pular(lbl: Label, tween: Tween, tamanho: float) -> Tween:
	if tween:
		tween.kill()
	lbl.pivot_offset = lbl.size / 2.0
	tween = create_tween().set_ignore_time_scale()
	tween.tween_property(lbl, "scale", Vector2.ONE * tamanho, 0.06)
	tween.tween_property(lbl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

# "+1" que pula da cabeça do npc (posição de tela) e voa em curva até o contador
func voar_susto(de: Vector2, quantos: int = 1) -> void:
	voando += quantos
	var texto = Label.new()
	texto.text = "+%d" % quantos
	texto.add_theme_font_size_override("font_size", 34)
	texto.position = de - Vector2(20, 20)
	texto.pivot_offset = Vector2(20, 20)
	add_child(texto)
	var destino = icone_sustos.global_position + icone_sustos.size / 2.0 - Vector2(20, 20)
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
