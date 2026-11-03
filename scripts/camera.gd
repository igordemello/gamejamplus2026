extends Camera2D

@export var zoom_min: float = 0.62
# como a partida começa (o limite continua vindo do enquadramento do editor, mais afastado)
@export var zoom_inicial: float = 0.8
@export var posicao_inicial: Vector2 = Vector2(990, 620)
# zoom acima disso é o jogador olhando algo de perto: o lembrete do zumbi não atrapalha
@export var zoom_de_perto: float = 1.15
# clicar num fantasma da lista aproxima até aqui (se já estiver mais perto, fica como está)
@export var zoom_aproximar: float = 1.1
# quanto cada lembrete afasta, no mínimo
@export var passo_lembrete: float = 0.1
@export var suavidade_conducao: float = 3.0
# segundos sem mexer na câmera até um lembrete poder afastar ela
@export var calma_lembrete: float = 6.0
@export var zoom_max: float = 1.5
@export var passo_zoom: float = 0.1
# quanto maior, mais rápido o zoom chega onde o scroll mandou
@export var suavidade_zoom: float = 8.0
# quanto a tremida perde por segundo
@export var queda_tremida: float = 40.0
# foco num alvo (painel de lore): zoom e a velocidade com que a câmera desliza até ele
@export var zoom_foco: float = 1.6
@export var suavidade_foco: float = 8.0

# o que a câmera mostra do jeito que está no editor é a borda: ela nunca mostra além disso
var limite: Rect2
var zoom_alvo: float
# o zoom do scroll; o zoom de verdade é esse mais o tranco
var zoom_atual: float
var tremida: float = 0.0
var tranco: float = 0.0
# quanto o jogador já arrastou com o botão direito (o tutorial usa)
var arrastado: float = 0.0
# quem está em foco, o ponto do desenho dele (relativo à origem) e de que lado da tela ele fica (1 = esquerda)
var foco: Node2D
var focando: bool = false
var foco_centro: Vector2 = Vector2.ZERO
var foco_lado: float = 1.0
# onde a câmera estava antes do foco; volta = ainda deslizando de volta pra lá
var posicao_antes: Vector2
var volta: bool = false
# o jogo está levando a câmera até um lugar (mexer no scroll ou arrastar cancela)
var conduzindo: bool = false
var posicao_conduzida: Vector2
# quando o jogador mexeu na câmera pela última vez, em ms
var mexeu_em: int = 0
var dedos: Dictionary = {}

func _ready() -> void:
	var tela = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var visivel = tela / zoom
	limite = Rect2(position - visivel / 2, visivel)
	zoom_alvo = zoom_inicial
	zoom_atual = zoom_inicial
	zoom = Vector2.ONE * zoom_inicial
	position = limitar(posicao_inicial, zoom_inicial)

func _process(delta: float) -> void:
	# tremida e tranco em tempo real: continuam durante o hitstop e a câmera lenta
	# (com teto: no frame em que o time_scale muda o delta ainda vem do jeito antigo)
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	tremida = move_toward(tremida, 0.0, queda_tremida * real)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tremida
	tranco = lerpf(tranco, 0.0, minf(10.0 * real, 1.0)) if tranco > 0.0005 else 0.0

	# alvo que sumiu (saiu da festa) solta o foco
	if focando and not is_instance_valid(foco):
		soltar_foco()
	var zoom_destino = zoom_foco if focando else zoom_alvo
	var zoom_antes = zoom.x
	if not is_equal_approx(zoom_atual, zoom_destino):
		# em tempo real: o foco acontece com o mundo em câmera lenta
		var novo = lerpf(zoom_atual, zoom_destino, minf(suavidade_zoom * real, 1.0))
		if absf(novo - zoom_destino) < 0.001:
			novo = zoom_destino
		# aproxima na direção do mouse: o ponto embaixo dele não sai do lugar
		if not focando and not volta and not conduzindo:
			var mouse = get_viewport().get_mouse_position() - get_viewport_rect().size / 2
			position += mouse / zoom_atual - mouse / novo
		zoom_atual = novo
	zoom = Vector2.ONE * zoom_atual * (1.0 + tranco)
	if focando or volta:
		var destino = posicao_foco(foco, foco_centro, foco_lado) if focando else limitar(posicao_antes, zoom_atual)
		position = position.lerp(destino, minf(suavidade_foco * real, 1.0))
		if not focando and position.distance_to(destino) < 1.0 and is_equal_approx(zoom_atual, zoom_alvo):
			volta = false
		prender()
	elif conduzindo:
		var destino = limitar(posicao_conduzida, zoom_atual)
		position = position.lerp(destino, minf(suavidade_conducao * real, 1.0))
		if position.distance_to(destino) < 1.0 and is_equal_approx(zoom_atual, zoom_alvo):
			conduzindo = false
		prender()
	elif zoom.x != zoom_antes:
		prender()

func _unhandled_input(event: InputEvent) -> void:
	# com foco a câmera é do painel: não zoom nem arrasta
	if focando:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_alvo = clampf(zoom_alvo + passo_zoom, zoom_min, zoom_max)
			jogador_mexeu()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_alvo = clampf(zoom_alvo - passo_zoom, zoom_min, zoom_max)
			jogador_mexeu()

	# segurando o botão direito arrasta o mapa junto com o mouse
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		arrastar(event.relative)

# arrasta o mapa junto com o mouse ou o dedo (a area_jogo chama no arraste com um dedo)
func arrastar(relativo: Vector2) -> void:
	if focando:
		return
	volta = false
	jogador_mexeu()
	position -= relativo / zoom
	prender()
	arrastado += relativo.length()

# dedos na tela (índice -> posição): com dois, a pinça dá zoom e arrasta pelo meio deles
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# o primeiro dedo: o que ficou de antes (soltou com o jogo pausado) não vale
			if event.index == 0:
				dedos.clear()
			dedos[event.index] = event.position
		else:
			dedos.erase(event.index)
	elif event is InputEventScreenDrag and dedos.has(event.index):
		if dedos.size() == 2 and not focando:
			var outro = dedos.keys().filter(func(i): return i != event.index)[0]
			pincar(dedos[outro], dedos[event.index], event.position)
		dedos[event.index] = event.position

# o ponto do mundo que estava no meio dos dedos continua no meio deles
func pincar(fixo: Vector2, antes: Vector2, depois: Vector2) -> void:
	var fator = fixo.distance_to(depois) / maxf(fixo.distance_to(antes), 1.0)
	var novo = clampf(zoom_atual * fator, zoom_min, zoom_max)
	var meio_tela = get_viewport_rect().size / 2.0
	var mundo = position + ((fixo + antes) / 2.0 - meio_tela) / zoom_atual
	zoom_alvo = novo
	zoom_atual = novo
	zoom = Vector2.ONE * novo * (1.0 + tranco)
	volta = false
	jogador_mexeu()
	var destino = mundo - ((fixo + depois) / 2.0 - meio_tela) / novo
	arrastado += position.distance_to(destino) * novo
	position = destino
	prender()

func jogador_mexeu() -> void:
	conduzindo = false
	mexeu_em = Time.get_ticks_msec()

# leva a vista até um ponto, aproximando um pouco
func aproximar_de(ponto: Vector2) -> void:
	if focando:
		return
	zoom_alvo = maxf(zoom_alvo, zoom_aproximar)
	posicao_conduzida = ponto
	conduzindo = true
	volta = false
	# conta como mexer na câmera: o lembrete do zumbi não puxa ela de volta logo depois
	mexeu_em = Time.get_ticks_msec()

# afasta até mostrar tudo, inclusive o lado de fora da casa (ganhou o zumbi)
func mostrar_exterior() -> void:
	if focando:
		return
	zoom_alvo = zoom_min
	posicao_conduzida = Vector2(960, 540)
	conduzindo = true
	volta = false

# um ponto está na vista nesse zoom e nessa posição? (as cartas tampam a parte de baixo da tela)
func ponto_na_vista(ponto: Vector2, zoom_ref: float, centro: Vector2) -> bool:
	var tela = get_viewport_rect().size
	var tela_ponto = (ponto - centro) * zoom_ref + tela / 2.0
	return Rect2(60, 40, tela.x - 120, tela.y - 200).has_point(tela_ponto)

# lembra o jogador de algo fora da vista com um afastamento leve, só o que precisar pra aparecer.
# não faz nada se ele está olhando de perto, mexeu na câmera agora há pouco ou o ponto já aparece.
# devolve se mexeu na câmera
func lembrar_de(ponto: Vector2) -> bool:
	if focando or volta or conduzindo or zoom_alvo > zoom_de_perto:
		return false
	if Time.get_ticks_msec() - mexeu_em < calma_lembrete * 1000.0 or ponto_na_vista(ponto, zoom_alvo, position):
		return false
	var novo_zoom = maxf(zoom_alvo - passo_lembrete, zoom_min)
	var centro = limitar(position, novo_zoom)
	while not ponto_na_vista(ponto, novo_zoom, centro) and novo_zoom > zoom_min:
		# puxa a vista na direção dele e, se não bastar, afasta mais
		centro = limitar(centro.lerp(ponto, 0.25), novo_zoom)
		if not ponto_na_vista(ponto, novo_zoom, centro):
			novo_zoom = maxf(novo_zoom - 0.03, zoom_min)
	zoom_alvo = novo_zoom
	posicao_conduzida = centro.lerp(ponto, 0.2) if not ponto_na_vista(ponto, novo_zoom, centro) else centro
	conduzindo = true
	return true

# onde a câmera fica pro alvo aparecer no meio de uma metade da tela (lado 1: a esquerda, -1: a direita),
# já respeitando o limite. centro é o ponto do desenho do alvo, relativo à origem dele
func posicao_foco(alvo: Node2D, centro: Vector2, lado: float) -> Vector2:
	var tela = get_viewport_rect().size
	return limitar(alvo.global_position + centro + Vector2(lado * tela.x / 4.0 / zoom_foco, 0.0), zoom_foco)

# desliza e dá zoom no alvo, guardando o enquadramento de antes (só na primeira vez: trocar de alvo não perde)
func focar(alvo: Node2D, centro: Vector2, lado: float) -> void:
	if not focando and not volta:
		posicao_antes = position
	focando = true
	foco = alvo
	foco_centro = centro
	foco_lado = lado
	volta = false

# volta ao enquadramento de antes: o zoom do scroll e a posição guardada
func soltar_foco() -> void:
	if not focando:
		return
	focando = false
	foco = null
	volta = true

func prender() -> void:
	position = limitar(position, zoom.x)

# o ponto mais perto dele onde a vista, nesse zoom, não passa do limite
func limitar(ponto: Vector2, zoom_ref: float) -> Vector2:
	var meio = (get_viewport_rect().size / zoom_ref / 2).min(limite.size / 2)
	return ponto.clamp(limite.position + meio, limite.end - meio)

# chacoalha a tela; se já estiver tremendo mais forte, fica a mais forte
func tremer(forca: float) -> void:
	tremida = maxf(tremida, forca)

# aproxima de repente um tiquinho e volta (0.03 = 3%)
func chutar(forca: float) -> void:
	tranco = maxf(tranco, forca)
