extends Node2D
class_name Fantasma

const CONTORNO = preload("res://assets/contorno.tres")
const FUMACA = preload("res://scene/fumaca.tscn")
const EFEITO_GRUPO = preload("res://scripts/efeito_grupo.gd")
# susto em área: cada pessoa a mais soma isso ao medo de todas, até o máximo
const BONUS_POR_PESSOA = 0.25
const BONUS_MAXIMO = 2.0
# da mais fraca (2 pessoas) pra mais forte (5 ou mais)
const CORES_GRUPO = [Color(1, 0.85, 0.3), Color(1, 0.55, 0.15), Color(1, 0.25, 0.2), Color(1, 0.2, 0.7)]

enum Tipo {
	Aparicao,
	Poltergeist,
	Espectro,
	Demonio
}

const NOME_TIPO = {
	Tipo.Aparicao: "Aparição",
	Tipo.Poltergeist: "Poltergeist",
	Tipo.Espectro: "Espectro",
	Tipo.Demonio: "Demônio"
}

@export var custo: int = 5
@export var tier: int = 1
@export var tipo: Tipo = Tipo.Aparicao
# quantas vezes dá pra comprar esse fantasma na loja
@export var usos: int = 5

# nome do nó do cômodo em houseRegions onde pode ser colocado, vazio = qualquer lugar
@export var comodo_spawn: String = ""
@export var comodos_proibidos: Array[String] = []
# se preenchido, só pode ser colocado num ponto livre desse grupo (ex.: "armadura")
@export var pontos_spawn: StringName = &""
# só pode ser colocado do lado de fora da casa, na grama
@export var fora_de_casa: bool = false

@export var acoes: Array[Acao] = []
@export var raio_clique: float = 32.0
# só aparece na loja depois dessa quantidade de infartos (GameManager.mortes)
@export var mortes_para_liberar: int = 0
# sem ação pra fazer, anda devagar por perto em vez de ficar parado
@export var passeia: bool = false
@export var velocidade_passeio: float = 45.0
@export var raio_passeio: float = 200.0
# passeia pela casa toda em vez de ficar no próprio cômodo (nunca em cômodo proibido)
@export var passeio_casa: bool = false
@export var espera_passeio_min: float = 2.0
@export var espera_passeio_max: float = 5.0

var recarga_restante: Dictionary = {}
var selecionado: bool = false
# cópia por fantasma, senão o brilho de um acende todos
var material_fantasma: ShaderMaterial = CONTORNO.duplicate()
var escala_sprite: Vector2 = Vector2.ZERO
var tween_pulinho: Tween
var tween_negar: Tween
var tween_aparecer: Tween
# escala do nó como veio da cena; com o mouse em cima ele cresce um pouco a partir dela
var escala_raiz: Vector2 = Vector2.ZERO
# brilho de ectoplasma em volta, pulsando devagar (no escuro é por ele que se acha o fantasma)
var luz: PointLight2D
var tempo_luz: float = randf() * TAU
# o mouse está em cima (decidido no _process): depois de entrar, o raio fica maior pra sair
var no_hover: bool = false
var destino_passeio: Vector2 = Vector2.INF
var espera_passeio: float = randf_range(1.0, 3.0)
var tempo_passeio: float = 0.0
# caminho da navegação até o destino de andar_pelo_caminho
var caminho: PackedVector2Array = PackedVector2Array()
var indice_caminho: int = 0
var destino_caminho: Vector2 = Vector2.INF
var quadro_caminho: int = 0

func _enter_tree() -> void:
	add_to_group("fantasma")
	if luz == null:
		var sprite: AnimatedSprite2D = $AnimatedSprite2D
		luz = PointLight2D.new()
		luz.texture = preload("res://assets/luz.tres")
		luz.color = Color(0.55, 1.0, 0.8)
		luz.texture_scale = 0.9
		luz.position = sprite.position + sprite.offset * sprite.scale
		add_child(luz)

func _process(delta: float) -> void:
	# a recarga anda no tempo do jogo: na câmera lenta ela também desacelera
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	for acao in recarga_restante:
		var antes = recarga_restante[acao]
		recarga_restante[acao] = maxf(antes - delta, 0.0)
		# piscadinha avisando que a ação ficou pronta de novo
		if antes > 0.0 and recarga_restante[acao] == 0.0:
			piscar(1, 0.08)

	tempo_luz += delta
	luz.energy = 0.55 + 0.15 * sin(tempo_luz * 1.5)

	no_hover = mouse_em_cima()
	passear(delta)
	var destaque = selecionado or no_hover
	$AnimatedSprite2D.material = material_fantasma
	material_fantasma.set_shader_parameter("contorno", destaque)
	if not (tween_aparecer and tween_aparecer.is_running()):
		if escala_raiz == Vector2.ZERO:
			escala_raiz = scale
		scale = scale.lerp(escala_raiz * (1.08 if destaque else 1.0), minf(15.0 * real, 1.0))

# onomatopeia em cima do desenho (a luz fica no meio dele)
func onomatopeia(texto: String, cor: Color) -> void:
	Onomatopeia.soltar(texto, global_position + luz.position * scale - Vector2(0, 55), cor)

# fica branco rapidinho algumas vezes
func piscar(vezes: int, duracao: float) -> void:
	var tween = create_tween()
	for i in vezes:
		tween.tween_callback(material_fantasma.set_shader_parameter.bind("brilho", 1.0))
		tween.tween_interval(duracao)
		tween.tween_callback(material_fantasma.set_shader_parameter.bind("brilho", 0.0))
		tween.tween_interval(duracao)

# mede do meio do desenho, porque alguns fantasmas têm a origem nos pés. com ele em destaque o raio
# é maior: o fantasma cresce 8% e o centro do desenho anda, e sem folga o hover ficava piscando na borda
func mouse_em_cima() -> bool:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	var centro = sprite.global_position + sprite.offset * sprite.global_scale
	return centro.distance_to(get_global_mouse_position()) <= raio_clique * (1.25 if no_hover else 1.0)

func executar(acao: Acao) -> void:
	if acao.mira and recarga_restante.get(acao, 0.0) <= 0.0:
		GameManager.house.ui.get_node("area_jogo").comecar_mira(self, acao)
	elif recarga_restante.get(acao, 0.0) <= 0.0 and call(acao.metodo):
		acao_feita(acao)
	else:
		negar()

# escolheu o lugar da ação com mira
func executar_mira(acao: Acao, onde: Vector2) -> void:
	if recarga_restante.get(acao, 0.0) <= 0.0 and call(acao.metodo, onde):
		acao_feita(acao)
	else:
		negar()

func acao_feita(acao: Acao) -> void:
	recarga_restante[acao] = acao.recarga
	pulinho()
	# a casa sente: as luzes em volta piscam
	GameManager.house.piscar_luzes(global_position, 0.25)

# onde a ação pega, pra desenhar no chão: {"centro", "raio"}, {"comodo"} ou vazio se não tem área fixa
func area_de(_acao: Acao) -> Dictionary:
	return {}

func area_raio(raio: float) -> Dictionary:
	return {"centro": global_position, "raio": raio}

# no corredor, que não é cômodo, a área é um círculo
func area_comodo(raio_corredor: float = 250.0) -> Dictionary:
	var comodo = GameManager.house.comodo_em(global_position)
	return area_raio(raio_corredor) if comodo == "" else {"comodo": comodo}

# quanto o susto em área vale pra cada um quando pega essa quantidade de gente
func bonus_em_grupo(quantos: int) -> float:
	return minf(1.0 + BONUS_POR_PESSOA * maxi(quantos - 1, 0), BONUS_MAXIMO)

func medo_em_grupo(medo: int, quantos: int) -> int:
	return roundi(medo * bonus_em_grupo(quantos))

# pegou mais de um: raios até cada pessoa, impacto proporcional à quantidade e o multiplicador na tela.
# chame antes de assustar (quem infarta ou foge muda de estado no susto)
func sentir_grupo(npcs: Array, centro: Vector2 = Vector2.INF) -> void:
	var quantos = npcs.size()
	if quantos < 2:
		return
	var house = GameManager.house
	if centro == Vector2.INF:
		centro = global_position + luz.position * scale
	var nivel = mini(quantos - 2, CORES_GRUPO.size() - 1)
	var cor = CORES_GRUPO[nivel]
	var efeito = EFEITO_GRUPO.new()
	efeito.centro = centro
	efeito.alvos = npcs
	efeito.cor = cor
	efeito.forca = float(nivel + 1)
	house.y_sort.add_child(efeito)

	# bem acima: logo abaixo fica a onomatopeia da própria ação
	var acima = centro + Vector2(0, -210)
	Onomatopeia.soltar("%d DE UMA VEZ!" % quantos, acima, cor, 4.0 + nivel)
	Onomatopeia.soltar("MEDO X%s" % str(snappedf(bonus_em_grupo(quantos), 0.01)), acima + Vector2(0, 42.0 + 6.0 * nivel), Color.WHITE, 3.0 + 0.5 * nivel)

	GameManager.hitstop(0.06 + 0.035 * nivel)
	house.camera.tremer(5.0 + 3.0 * nivel)
	house.camera.chutar(0.03 + 0.02 * nivel)
	house.pos.chutar(3.0 + nivel)
	house.piscar_luzes(centro, 0.3 + 0.1 * nivel)
	# o mesmo sininho, mais agudo quanto mais gente
	var som = GameManager.som.tocar("carta_liberada")
	if som:
		som.pitch_scale = 1.0 + 0.18 * nivel

# ação com mira: dá pra escolher esse lugar?
func mira_valida(_acao: Acao, _onde: Vector2) -> bool:
	return false

# chamado quando é solto da loja: cresce com um pulinho e aparece
func aparecer() -> void:
	if escala_raiz == Vector2.ZERO:
		escala_raiz = scale
	scale = escala_raiz * 0.3
	modulate.a = 0.0
	tween_aparecer = create_tween().set_parallel()
	tween_aparecer.tween_property(self, "scale", escala_raiz, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_aparecer.tween_property(self, "modulate:a", 1.0, 0.15)
	# fumaça no chão e uma tremidinha
	var fumaca = FUMACA.instantiate()
	fumaca.position = get_parent().to_local(global_position)
	get_parent().add_child(fumaca)
	GameManager.house.camera.tremer(3.0)

# amassa e estica rapidinho quando usa uma ação
func pulinho() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	if escala_sprite == Vector2.ZERO:
		escala_sprite = sprite.scale
	if tween_pulinho:
		tween_pulinho.kill()
	tween_pulinho = create_tween()
	tween_pulinho.tween_property(sprite, "scale", escala_sprite * Vector2(1.25, 0.8), 0.06)
	tween_pulinho.tween_property(sprite, "scale", escala_sprite, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# balança a cabeça que não quando a ação não deu (recarregando ou ninguém perto)
func negar() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	# o offset é em pixels da arte; assim dá uns 5 px na tela em qualquer escala
	var passo = 5.0 / sprite.global_scale.x
	if tween_negar:
		tween_negar.kill()
	tween_negar = create_tween()
	for x in [passo, -passo, passo * 0.5, 0.0]:
		tween_negar.tween_property(sprite, "offset:x", x, 0.05)

# parado por um tempo, depois anda até um ponto ali perto, no mesmo cômodo. para com o mouse em cima
# (pra dar pra clicar) e quando tem o que fazer
func passear(delta: float) -> void:
	if not passeia:
		return
	if selecionado or no_hover or ocupado_agora():
		destino_passeio = Vector2.INF
		return
	if destino_passeio == Vector2.INF:
		espera_passeio -= delta
		if espera_passeio <= 0.0:
			espera_passeio = randf_range(espera_passeio_min, espera_passeio_max)
			destino_passeio = sortear_passeio()
			tempo_passeio = 0.0
		return
	tempo_passeio += delta
	var antes = global_position
	mover_passeio(destino_passeio, velocidade_passeio * delta)
	if global_position != antes:
		virar_para(antes.direction_to(global_position))
	if global_position.distance_to(destino_passeio) <= 4.0 or tempo_passeio > 8.0:
		destino_passeio = Vector2.INF

# ficou tempo demais em cima de alguém: quem passeia vai pra outro lugar; parado por natureza, não muda
func redirecionar() -> bool:
	if not passeia or ocupado_agora():
		return false
	destino_passeio = sortear_passeio()
	tempo_passeio = 0.0
	return destino_passeio != Vector2.INF

func ocupado_agora() -> bool:
	return (has_method("ocupado") and call("ocupado")) or (has_method("ocupada") and call("ocupada"))

# um ponto da malha ali perto, no mesmo cômodo, sem parede nem cômodo proibido. INF se não achar
func sortear_passeio() -> Vector2:
	var house = GameManager.house
	var comodo = house.comodo_em(global_position)
	# caiu num cômodo proibido (empurrado ou de um caminho antigo): o passeio é o jeito de sair de lá
	var saindo = house.comodo_proibido(global_position, comodos_proibidos)
	var alcance = raio_passeio * (3.0 if saindo else 1.0)
	for i in 12:
		var longe = global_position + Vector2.from_angle(randf() * TAU) * randf_range(alcance * 0.3, alcance)
		var ponto = house.ponto_na_casa(longe)
		if house.eh_parede(ponto) or house.comodo_proibido(ponto, comodos_proibidos):
			continue
		if not passeio_casa and not saindo and house.comodo_em(ponto) != comodo:
			continue
		if saindo or caminho_permitido(ponto, comodo):
			return ponto
	return Vector2.INF

# o caminho até lá não passa por cômodo proibido nem, sem passeio_casa, por outro cômodo
func caminho_permitido(ate: Vector2, comodo: String) -> bool:
	var house = GameManager.house
	var rota = NavigationServer2D.map_get_path(get_world_2d().navigation_map, global_position, ate, true, 1)
	for i in range(1, rota.size()):
		var trecho = rota[i - 1].distance_to(rota[i])
		var passos = int(trecho / 30.0) + 1
		for j in passos + 1:
			var ponto = rota[i - 1].lerp(rota[i], j / float(passos))
			if house.comodo_proibido(ponto, comodos_proibidos):
				return false
			if not passeio_casa and house.comodo_em(ponto) != comodo:
				return false
	return true

func mover_passeio(destino: Vector2, passo: float) -> void:
	andar_pelo_caminho(destino, passo)

# cada fantasma vira do jeito dele (o desenho de cada um olha pra um lado)
func virar_para(_direcao: Vector2) -> void:
	pass

# a recarga de uma ação fica cheia (enquanto ela ainda está acontecendo) ou zera (não deu certo)
func segurar_recarga(metodo: StringName) -> void:
	for acao in acoes:
		if acao.metodo == metodo:
			recarga_restante[acao] = acao.recarga

func liberar_recarga(metodo: StringName) -> void:
	for acao in acoes:
		if acao.metodo == metodo:
			recarga_restante[acao] = 0.0

# anda um passo até o destino seguindo a malha de navegação da casa (camada 1, a dos NPCs),
# então não atravessa parede. recalcula o caminho quando o destino muda mais de 8 px
# (ou quando ficou um quadro sem andar, porque aí o caminho guardado é de outra viagem)
func andar_pelo_caminho(destino: Vector2, passo: float) -> void:
	var quadro = Engine.get_physics_frames()
	if caminho.is_empty() or quadro - quadro_caminho > 1 or destino_caminho.distance_to(destino) > 8.0:
		destino_caminho = destino
		caminho = NavigationServer2D.map_get_path(get_world_2d().navigation_map, global_position, destino, true, 1)
		indice_caminho = 0
	while indice_caminho < caminho.size() and global_position.distance_to(caminho[indice_caminho]) < 1.0:
		indice_caminho += 1
	quadro_caminho = quadro
	# sem caminho, fica parado; acabando o caminho, o último trecho até o destino é curto
	if caminho.is_empty():
		return
	var proximo = caminho[indice_caminho] if indice_caminho < caminho.size() else destino
	global_position = global_position.move_toward(proximo, passo)

func npc_mais_perto() -> Npc:
	var meu_comodo = GameManager.house.comodo_em(global_position)
	var mais_perto: Npc = null

	for npc in get_tree().get_nodes_in_group("npc"):
		if GameManager.house.comodo_em(npc.global_position) != meu_comodo:
			continue
		if mais_perto == null or global_position.distance_to(npc.global_position) < global_position.distance_to(mais_perto.global_position):
			mais_perto = npc

	return mais_perto
