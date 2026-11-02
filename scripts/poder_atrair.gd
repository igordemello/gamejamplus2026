extends Control

# poder do jogador, um botão embaixo dos contadores: escolhe um convidado, escolhe um lugar,
# e ele vai até lá e fica preso por tempo_preso segundos. a area_jogo passa os cliques no mapa pra cá

const MARCA = preload("res://scripts/marca_atracao.gd")
const PAPEL = Color(0.86, 0.84, 0.76)
const TAMANHO = 84.0
# o ícone tem 32 px: em 64 fica em pixel inteiro e cabe no botão
const LADO_ICONE = 64.0

@export var recarga: float = 120.0
@export var tempo_preso: float = 30.0
@export var tempo_lento: float = 0.25

enum Etapa { Nada, EscolheNpc, EscolheLugar }

var etapa: int = Etapa.Nada
var escolhido: Npc
var restante: float = 0.0
var no_mapa_ok: bool = false
var realce: float = 0.0
var piscada: float = 0.0
# tranco do botão, em tamanho
var soco: float = 0.0
# as mesmas regras de uma carta, pros quadradinhos de onde dá pra soltar (areas_chao e area_jogo.pode_soltar_em)
var comodo_spawn: String = ""
var comodos_proibidos: Array[String] = []
var pontos_spawn: StringName = &""
var fora_de_casa: bool = false

var icone: Texture2D

func _ready() -> void:
	icone = load("res://assets/magnet.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2.ONE * TAMANHO
	size = Vector2.ONE * TAMANHO
	position = Vector2(16, 176)
	tooltip_text = "Atrair\nEscolha um convidado e um lugar: ele vai até lá e fica preso por %d s. Recarga de %d s." % [tempo_preso, recarga]
	mouse_entered.connect(func(): GameManager.som.tocar_ui("hover_ui"))

func ativo() -> bool:
	return etapa != Etapa.Nada

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if ativo():
			cancelar()
		elif restante > 0.0:
			negar()
		else:
			comecar()

func comecar() -> void:
	etapa = Etapa.EscolheNpc
	escolhido = null
	var house = GameManager.house
	house.mirando = true
	house.get_node("lore").fechar(false)
	GameManager.mudar_tempo(tempo_lento, 0.15)
	GameManager.som.tocar_ui("carta_pegar")
	piscada = 1.0
	soco = 1.0

func cancelar() -> void:
	terminar()

func terminar() -> void:
	etapa = Etapa.Nada
	escolhido = null
	GameManager.house.mirando = false
	GameManager.mudar_tempo(1.0, 0.1)
	var area = GameManager.house.ui.get_node("area_jogo")
	area.mouse_default_cursor_shape = Control.CURSOR_ARROW
	area.queue_redraw()
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.em_destaque = false

func negar() -> void:
	var inicio = position.x
	var tween = create_tween().set_ignore_time_scale()
	for desvio in [8.0, -8.0, 5.0, -3.0, 0.0]:
		tween.tween_property(self, "position:x", inicio + desvio, 0.04)

# a cada quadro enquanto ativo, chamado pela area_jogo: quem está em destaque e o cursor
func processar(area: Control) -> void:
	var house = GameManager.house
	if get_viewport().gui_is_dragging():
		cancelar()
		return
	if etapa == Etapa.EscolheNpc:
		var hover = area.npc_sob_mouse()
		no_mapa_ok = hover != null and hover.pode_ser_atraido()
		for npc in get_tree().get_nodes_in_group("npc"):
			npc.em_destaque = npc == hover
	else:
		if not is_instance_valid(escolhido) or not escolhido.pode_ser_atraido():
			cancelar()
			return
		no_mapa_ok = area.pode_soltar_em(self, house.get_global_mouse_position())
		for npc in get_tree().get_nodes_in_group("npc"):
			npc.em_destaque = npc == escolhido
	area.mouse_default_cursor_shape = Control.CURSOR_CROSS

# clique no mapa enquanto ativo (vem do _gui_input da area_jogo)
func clique_no_mapa(event: InputEventMouseButton, area: Control) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		cancelar()
	elif event.button_index != MOUSE_BUTTON_LEFT:
		return
	elif etapa == Etapa.EscolheNpc:
		var npc = area.npc_sob_mouse()
		if npc and npc.pode_ser_atraido():
			# agarrou: ele leva um susto, sem saber de onde
			escolhido = npc
			etapa = Etapa.EscolheLugar
			GameManager.som.tocar_ui("hover_carta")
			npc.pular_de_susto()
			npc.mostrar_exclamacao("?")
			GameManager.house.camera.tremer(2.5)
	elif no_mapa_ok:
		var quem = escolhido
		terminar()
		usar(quem, GameManager.house.get_global_mouse_position())

# o poder em si: também é o que os testes chamam
func usar(npc: Npc, onde: Vector2) -> bool:
	if restante > 0.0 or not npc.pode_ser_atraido():
		return false
	var house = GameManager.house
	var lugar = house.ponto_na_casa(onde)
	npc.atrair(lugar, tempo_preso)
	restante = recarga
	var marca = MARCA.new()
	marca.npc = npc
	marca.lugar = lugar
	marca.duracao = tempo_preso
	house.efeitos_chao.add_child(marca)
	Onomatopeia.soltar("VEM CA!", npc.global_position + Vector2(0, -190), Color(1, 0.35, 0.3), 5.0)
	GameManager.som.tocar("vush")
	GameManager.som.tocar("buu_invocacao")
	GameManager.som.tocar("cavaleiro")
	# o tranco da corrente: congela um instante e sacode tudo (sai da câmera lenta na hora, senão não congela)
	GameManager.tempo_normal()
	GameManager.hitstop(0.1)
	house.camera.tremer(8.0)
	house.camera.chutar(0.05)
	house.pos.chutar(5.0)
	house.piscar_luzes(npc.global_position, 0.4)
	house.piscar_luzes(lugar, 0.4)
	npc.pular_de_susto()
	piscada = 1.0
	soco = 1.0
	return true

# a dica ao lado do cursor (desenhada pela area_jogo)
func dica() -> String:
	if etapa == Etapa.EscolheNpc:
		return "Escolha um convidado"
	return "Clique onde ele vai ficar" if no_mapa_ok else "Aqui não dá"

func _process(delta: float) -> void:
	var antes = restante
	restante = maxf(restante - delta, 0.0)
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	if antes > 0.0 and restante == 0.0:
		piscada = 1.0
		soco = 1.0
		GameManager.som.tocar_ui("carta_liberada")
	piscada = maxf(piscada - 3.0 * real, 0.0)
	soco = maxf(soco - 4.0 * real, 0.0)
	var mouse_em_cima = Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	realce = lerpf(realce, 1.0 if mouse_em_cima or ativo() else 0.0, minf(15.0 * real, 1.0))
	queue_redraw()

func _draw() -> void:
	var centro = size / 2.0
	# pronto, o botão respira de leve; ativo, pulsa mais forte
	var respira = 0.03 * sin(Time.get_ticks_msec() / 250.0) if ativo() else (0.012 * sin(Time.get_ticks_msec() / 500.0) if restante <= 0.0 else 0.0)
	var raio = (TAMANHO / 2.0 - 4.0) * (1.0 + 0.08 * realce + 0.25 * soco + respira)
	var falta = restante / recarga
	draw_circle(centro, raio, Color(0.05, 0.04, 0.06, 0.92), true, -1.0, true)
	if icone:
		var lado = LADO_ICONE * raio / (TAMANHO / 2.0 - 4.0)
		draw_texture_rect(icone, Rect2(centro - Vector2.ONE * lado / 2.0, Vector2.ONE * lado), false, Color.WHITE if restante <= 0.0 else Color(0.35, 0.35, 0.4))
	draw_arc(centro, raio, 0.0, TAU, 48, Color(1, 1, 1, 0.2), 2.0, true)
	draw_arc(centro, raio, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - falta), 48, Color(1, 0.35, 0.3) if ativo() else Color.WHITE, 3.0, true)
	if restante > 0.0:
		draw_string(get_theme_default_font(), centro + Vector2(-raio, 10.0), str(ceili(restante)), HORIZONTAL_ALIGNMENT_CENTER, raio * 2.0, 30)
	if piscada > 0.0:
		draw_arc(centro, raio * (1.0 + (1.0 - piscada) * 0.5), 0.0, TAU, 48, Color(1, 1, 1, piscada), 3.0, true)
