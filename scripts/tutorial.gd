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
# já abriu a ficha de um convidado neste passo
var viu_lore: bool = false
# o vaso que a seta está mostrando: só troca se o cômodo dele esvaziar
var vaso_atual: Node2D
# o tutorial do começo da partida (o "Como jogar" da pausa não mexe no medo de ninguém)
var do_comeco: bool = false
# quem fica preso no cômodo do vaso até subir de nível, pra não segurar o vaso à toa
var npc_trancado: Npc
var nivel_soltar: int = 0
var niveis_inicial: int = 0
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
	# a seta fica por cima do painel: o alvo pode estar logo atrás dele
	move_child(seta, get_child_count() - 1)

func comecar(casa, comeco_da_partida: bool = false) -> void:
	house = casa
	do_comeco = comeco_da_partida
	niveis_inicial = total_de_niveis()
	var cam = house.camera
	passos = [
		{"texto": "Deram uma festa na SUA casa sem convidar você. Hora de assombrar até não sobrar ninguém!"},
		{"texto": "Segure o botão esquerdo no vaso da seta: todo mundo naquele cômodo leva um susto.",
			"alvo": levitavel_com_gente,
			"fazendo": func(): return get_tree().get_nodes_in_group("levitavel").any(func(o): return o.segurando),
			"texto_fazendo": "Isso! Continue segurando até a barra de medo em cima deles encher.",
			"trancar": true,
			"feito": func(): return total_de_niveis() > niveis_inicial},
		{"texto": "Cada nível de medo rende 1 susto, a sua moeda. Olhe o contador subir!",
			"destaque": house.ui.get_node("contadores/sustos"), "auto": 4.0},
		{"texto": "Gaste seus sustos: arraste uma carta até a casa. Os quadradinhos mostram onde ela cabe.",
			"destaque": house.ui.get_node("painel_fantasmas"),
			"feito": func(): return get_tree().get_nodes_in_group("fantasma").size() > fantasmas_inicial},
		{"texto": "Um fantasma! Segure o botão esquerdo nele e solte numa ação. O círculo mostra o alcance.",
			"alvo": ultimo_fantasma,
			"feito": func(): return get_tree().get_nodes_in_group("fantasma").any(func(f): return f.recarga_restante.values().any(func(r): return r > 0.0))},
		{"texto": "Quanto mais gente dentro do alcance, mais forte o susto. Junte o povo e capriche!", "auto": 5.0},
		{"texto": "Cada convidado morre de medo de um fantasma. Clique em quem tem a caveira e leia as pistas.",
			"alvo": marcado_vivo,
			"feito": func(): return viu_lore and not house.get_node("lore").aberto},
		{"texto": "Com a vítima apavorada (nível %d de medo), um susto do fantasma certo mata do coração!" % Npc.NIVEL_INFARTO},
		{"texto": "Pra vencer: casa vazia e pelo menos um objetivo cumprido. Eles ficam aqui no canto.",
			"destaque": house.ui.get_node("objetivos"), "abrir_objetivos": true},
		{"texto": "Difícil alcançar alguém? O ímã puxa um convidado pra onde quiser e prende ele lá por %d s." % house.ui.poder.tempo_preso,
			"destaque": house.ui.poder},
		{"texto": "Rodinha dá zoom, botão direito arrasta a câmera. Experimente!",
			"feito": func(): return absf(cam.zoom_alvo - zoom_inicial) > 0.01 or cam.arrastado - arrastado_inicial > 100.0},
		{"texto": "Com %d mortes vem a polícia. Ela não foge: só o Cavaleiro mata, e isso cumpre um objetivo!" % house.limite_mortes},
		{"texto": "Em %d minutos amanhece e a festa acaba. Esc pausa. Boa assombração!" % int(house.tempo_limite / 60.0)},
	]
	viu_lore = false
	vaso_atual = null
	atual = -1
	show()
	fundo.color.a = 0.6
	avancar()

func avancar() -> void:
	# passou com o botão Próximo antes de ele subir de nível: não fica preso à toa
	soltar_trancado()
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
	GameManager.som.tocar_ui("hover_ui")
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
	# a ficha do convidado abre por cima: o painel sai da frente enquanto ele lê
	var lore = house.get_node("lore")
	viu_lore = viu_lore or lore.aberto
	painel.visible = not lore.aberto
	if passo.has("trancar"):
		trancar_quem_assusta()
	# o texto responde ao que ele está fazendo
	if not concluido and passo.has("fazendo"):
		texto.text = passo.texto_fazendo if passo.fazendo.call() else passo.texto
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
		GameManager.som.tocar_ui("carta_liberada")
		painel.pivot_offset = painel.size / 2.0
		painel.scale = Vector2.ONE * 1.08
		tween_painel = create_tween().set_ignore_time_scale()
		tween_painel.tween_property(painel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var passo_agora = atual
		get_tree().create_timer(1.0, true, false, true).timeout.connect(func():
			if atual == passo_agora:
				avancar())
	elif passo.has("auto") and not concluido and tempo_passo >= passo["auto"]:
		avancar()

func terminar() -> void:
	soltar_trancado()
	# o medo do tutorial não conta: a partida começa de verdade agora (os sustos ganhos ficam)
	if do_comeco:
		do_comeco = false
		for npc in get_tree().get_nodes_in_group("npc"):
			npc.zerar_medo()
		house.ui.letreiro("VALENDO!", get_viewport().get_visible_rect().size * Vector2(0.5, 0.3))
		GameManager.som.tocar_ui("objetivo")
	apagar_destaques()
	painel.visible = true
	fundo.color.a = 0.0
	atual = passos.size()
	hide()

func total_de_niveis() -> int:
	var total = 0
	for npc in get_tree().get_nodes_in_group("npc"):
		total += npc.nivel_medo
	return total

# segurou um vaso: alguém do cômodo dele (ou o mais perto, que vem correndo) fica preso até subir de nível
func trancar_quem_assusta() -> void:
	if is_instance_valid(npc_trancado):
		if npc_trancado.nivel_medo >= nivel_soltar:
			soltar_trancado()
		return
	# o passo já foi cumprido: ele ainda pode estar segurando o vaso, mas ninguém mais fica preso
	if total_de_niveis() > niveis_inicial:
		return
	var vaso = null
	for candidato in get_tree().get_nodes_in_group("levitavel"):
		if candidato.segurando:
			vaso = candidato
	if vaso == null:
		return
	var regiao = vaso.get_region_at_position(vaso.global_position)
	if regiao == null:
		return
	var livres = get_tree().get_nodes_in_group("npc").filter(func(n): return n.pode_ser_atraido())
	var no_comodo = livres.filter(func(n): return house.comodo_em(n.global_position) == String(regiao.name))
	var perto = func(a, b): return a.global_position.distance_to(vaso.global_position) < b.global_position.distance_to(vaso.global_position)
	var lugar = Vector2.INF
	if not no_comodo.is_empty():
		no_comodo.sort_custom(perto)
		npc_trancado = no_comodo[0]
		lugar = npc_trancado.global_position
	elif not livres.is_empty():
		livres.sort_custom(perto)
		npc_trancado = livres[0]
		# um ponto do cômodo do vaso, o melhor entre alguns sorteados: perto dele, mas sem ficar em cima
		var melhor = INF
		for i in 12:
			var ponto = house.ponto_na_casa(npc_trancado.get_random_point_in_region(regiao))
			var distancia = absf(ponto.distance_to(vaso.global_position) - 90.0)
			if distancia < melhor and house.comodo_em(ponto) == String(regiao.name):
				melhor = distancia
				lugar = ponto
	if npc_trancado == null or lugar == Vector2.INF:
		npc_trancado = null
		return
	nivel_soltar = npc_trancado.nivel_medo + 1
	# o tempo é só um teto: quem solta é subir de nível, ou o tutorial acabar
	npc_trancado.atrair(lugar, 600.0)

func soltar_trancado() -> void:
	if is_instance_valid(npc_trancado) and npc_trancado.atraido:
		npc_trancado.soltar_atracao()
	npc_trancado = null

func rodando() -> bool:
	return visible and atual >= 0 and atual < passos.size()

# o vaso do cômodo com mais gente, pra segurar ele já assustar alguém. segurando ou com gente, não troca
func levitavel_com_gente() -> Node:
	var vasos = get_tree().get_nodes_in_group("levitavel")
	if is_instance_valid(vaso_atual) and vaso_atual.is_in_group("levitavel") and (vaso_atual.segurando or gente_no_comodo_de(vaso_atual) > 0):
		return vaso_atual
	var melhor = objeto_levitavel if is_instance_valid(objeto_levitavel) and objeto_levitavel.is_in_group("levitavel") else null
	var mais = -1
	for vaso in vasos:
		var quantos = gente_no_comodo_de(vaso)
		if quantos > mais:
			mais = quantos
			melhor = vaso
	vaso_atual = melhor
	return melhor

func gente_no_comodo_de(vaso: Node2D) -> int:
	var comodo = house.comodo_em(vaso.global_position)
	if comodo == "":
		return 0
	return get_tree().get_nodes_in_group("npc").filter(func(n): return house.comodo_em(n.global_position) == comodo).size()

# quem o jogador tem que matar, pra seta mostrar onde clicar: o mais embaixo na tela, longe do painel
func marcado_vivo() -> Node:
	var melhor = null
	for npc in house.marcados:
		if is_instance_valid(npc) and npc.is_in_group("npc") and (melhor == null or npc.global_position.y > melhor.global_position.y):
			melhor = npc
	return melhor

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
	if no is Npc:
		# acima da caveira de marcado
		return no.get_global_transform_with_canvas() * Vector2(0, no.altura_marca - 16.0) if no.marca else no.get_global_transform_with_canvas() * Vector2(0, no.topo_desenho)
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
