extends Node3D
class_name Fantasma

# classe base dos fantasmas: ações com recarga, hover, passeio, mover e caminho pela navegação 3D.
# O desenho é o filho `sprite` (SpritePersonagem); a raiz fica no chão.

const FUMACA = preload("res://scene/efeitos/fumaca.tscn")
const EFEITO_GRUPO = preload("res://scripts/efeitos/efeito_grupo.gd")
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

# cômodo (prefixo do nome do nó) onde pode ser colocado, vazio = qualquer lugar
@export var comodo_spawn: String = ""
@export var comodos_proibidos: Array[String] = []
# se preenchido, só pode ser colocado num ponto livre desse grupo (ex.: "armadura")
@export var pontos_spawn: StringName = &""
# só pode ser colocado do lado de fora da casa, na grama
@export var fora_de_casa: bool = false

@export var acoes: Array[Acao] = []
# só aparece na loja depois dessa quantidade de infartos (GameManager.mortes)
@export var mortes_para_liberar: int = 0
# ganha a ação "Mover": some e aparece onde o jogador escolher (mesmas regras de colocar a carta)
@export var pode_mover: bool = false
@export var recarga_mover: float = 30.0
# sem ação pra fazer, anda devagar por perto em vez de ficar parado
@export var passeia: bool = false
@export var velocidade_passeio: float = 0.51
@export var raio_passeio: float = 2.27
# passeia pela casa toda em vez de ficar no próprio cômodo (nunca em cômodo proibido)
@export var passeio_casa: bool = false
@export var espera_passeio_min: float = 2.0
@export var espera_passeio_max: float = 5.0

var recarga_restante: Dictionary = {}
var selecionado: bool = false
var escala_sprite: Vector3 = Vector3.ZERO
var tween_pulinho: Tween
var tween_negar: Tween
var tween_aparecer: Tween
# escala do nó como veio da cena; com o mouse em cima ele cresce um pouco a partir dela
var escala_raiz: Vector3 = Vector3.ZERO
# brilho verde pulsando, é por ele que se acha o fantasma no escuro
var luz: OmniLight3D
var tempo_luz: float = randf() * TAU
# mouse em cima; depois de entrar a folga aumenta pra não piscar na borda
var no_hover: bool = false
# o mouse está no ícone dele na lista de fantasmas
var destacado: bool = false
# criada aqui e não na cena, pra não aparecer na carta
var acao_mover: Acao
var destino_passeio: Vector3 = Vector3.INF
var espera_passeio: float = randf_range(1.0, 3.0)
var tempo_passeio: float = 0.0
# caminho da navegação até o destino de andar_pelo_caminho
var caminho: PackedVector3Array = PackedVector3Array()
var indice_caminho: int = 0
var destino_caminho: Vector3 = Vector3.INF
var quadro_caminho: int = 0

func _enter_tree() -> void:
	add_to_group("fantasma")
	if pode_mover and acao_mover == null:
		acao_mover = Acao.new()
		acao_mover.nome = "Mover"
		acao_mover.descricao = "Some daqui e aparece no lugar que você escolher."
		acao_mover.recarga = recarga_mover
		acao_mover.metodo = &"mover_para"
		acao_mover.mira = true
		acao_mover.icone = icone_mover()
		acoes = acoes.duplicate()
		acoes.append(acao_mover)
	if luz == null:
		var sprite: SpritePersonagem = $sprite
		luz = OmniLight3D.new()
		luz.light_color = Color(0.55, 1.0, 0.8)
		luz.omni_range = 1.5
		luz.position = sprite.position + Vector3(0, sprite.get_aabb().get_center().y * sprite.scale.y, 0)
		add_child(luz)

func _process(delta: float) -> void:
	# real = delta sem a câmera lenta; a recarga usa o delta do jogo
	var real = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
	for acao in recarga_restante:
		var antes = recarga_restante[acao]
		recarga_restante[acao] = maxf(antes - real, 0.0)
		# piscadinha: ação pronta de novo
		if antes > 0.0 and recarga_restante[acao] == 0.0:
			piscar(1, 0.08)

	tempo_luz += delta
	luz.light_energy = 0.55 + 0.15 * sin(tempo_luz * 1.5)

	no_hover = mouse_em_cima()
	passear(delta)
	var destaque = selecionado or no_hover or destacado
	$sprite.contorno = destaque
	if not (tween_aparecer and tween_aparecer.is_running()):
		if escala_raiz == Vector3.ZERO:
			escala_raiz = scale
		scale = scale.lerp(escala_raiz * (1.08 if destaque else 1.0), minf(15.0 * real, 1.0))

# em cima do desenho
func onomatopeia(texto: String, cor: Color) -> void:
	Onomatopeia.soltar(texto, GameManager.fase.topo($sprite) + Vector3.UP * 0.1, cor)

# fica branco rapidinho algumas vezes
func piscar(vezes: int, duracao: float) -> void:
	var tween = create_tween()
	for i in vezes:
		tween.tween_callback($sprite.set.bind("brilho", 1.0))
		tween.tween_interval(duracao)
		tween.tween_callback($sprite.set.bind("brilho", 0.0))
		tween.tween_interval(duracao)

# depois de entrar a folga aumenta, porque o fantasma cresce 8% e o desenho anda
func mouse_em_cima() -> bool:
	return GameManager.fase.mouse_em_sprite($sprite, 1.25 if no_hover else 1.0)

func executar(acao: Acao) -> void:
	if acao.mira and recarga_restante.get(acao, 0.0) <= 0.0:
		GameManager.fase.ui.get_node("area_jogo").comecar_mira(self, acao)
	elif recarga_restante.get(acao, 0.0) <= 0.0 and call(acao.metodo):
		acao_feita(acao)
	else:
		negar()

# escolheu o lugar da ação com mira
func executar_mira(acao: Acao, onde: Vector3) -> void:
	if recarga_restante.get(acao, 0.0) <= 0.0 and call(acao.metodo, onde):
		acao_feita(acao)
	else:
		negar()

func acao_feita(acao: Acao) -> void:
	recarga_restante[acao] = acao.recarga
	pulinho()
	# as luzes em volta piscam
	GameManager.fase.piscar_luzes(global_position, 0.25)

# onde a ação pega, pra desenhar no chão: {"centro", "raio"}, {"comodo"} ou vazio
func area_de(_acao: Acao) -> Dictionary:
	return {}

func area_raio(raio: float) -> Dictionary:
	return {"centro": global_position, "raio": raio}

# no corredor, que não é cômodo, a área é um círculo
func area_comodo(raio_corredor: float = 2.84) -> Dictionary:
	var comodo = GameManager.fase.comodo_em(global_position)
	return area_raio(raio_corredor) if comodo == "" else {"comodo": comodo}

# quanto o susto em área vale pra cada um quando pega essa quantidade de gente
func bonus_em_grupo(quantos: int) -> float:
	return minf(1.0 + BONUS_POR_PESSOA * maxi(quantos - 1, 0), BONUS_MAXIMO)

func medo_em_grupo(medo: int, quantos: int) -> int:
	return roundi(medo * bonus_em_grupo(quantos))

# feel de pegar mais de um (raios, tremida, multiplicador na tela). chame antes de assustar
func sentir_grupo(npcs: Array, centro: Vector3 = Vector3.INF) -> void:
	var quantos = npcs.size()
	if quantos < 2:
		return
	var fase = GameManager.fase
	if centro == Vector3.INF:
		centro = luz.global_position
	var nivel = mini(quantos - 2, CORES_GRUPO.size() - 1)
	var cor = CORES_GRUPO[nivel]
	var efeito = EFEITO_GRUPO.new()
	efeito.centro = centro
	efeito.alvos = npcs
	efeito.cor = cor
	efeito.forca = float(nivel + 1)
	fase.mundo.add_child(efeito)

	# bem acima, que embaixo fica a onomatopeia da ação
	var acima = centro + Vector3.UP * 2.4
	Onomatopeia.soltar("%d DE UMA VEZ!" % quantos, acima, cor, 4.0 + nivel)
	Onomatopeia.soltar("MEDO X%s" % str(snappedf(bonus_em_grupo(quantos), 0.01)), acima - Vector3.UP * (0.48 + 0.07 * nivel), Color.WHITE, 3.0 + 0.5 * nivel)

	GameManager.hitstop(0.06 + 0.035 * nivel)
	fase.camera.tremer(5.0 + 3.0 * nivel)
	fase.camera.chutar(0.03 + 0.02 * nivel)
	fase.pos.chutar(3.0 + nivel)
	fase.piscar_luzes(centro, 0.3 + 0.1 * nivel)
	# sininho mais agudo quanto mais gente
	var som = GameManager.som.tocar("carta_liberada")
	if som:
		som.pitch_scale = 1.0 + 0.18 * nivel

# ação com mira: só o Mover usa a regra de colocar a carta
func mira_valida(acao: Acao, onde: Vector3) -> bool:
	return acao == acao_mover and GameManager.fase.ui.get_node("area_jogo").pode_soltar_em(self, onde)

# fumaça no chão, onde o fantasma está
func soltar_fumaca() -> void:
	var fumaca = FUMACA.instantiate()
	GameManager.fase.mundo.add_child(fumaca)
	fumaca.global_position = global_position

# some numa fumaça e aparece lá
func mover_para(onde: Vector3) -> bool:
	if ocupado_agora():
		return false
	destino_passeio = Vector3.INF
	caminho = PackedVector3Array()
	onomatopeia("VUUSH!", Color(0.7, 1, 0.9))
	GameManager.som.tocar("vush")
	soltar_fumaca()
	var some = create_tween()
	some.tween_property(self, "scale", escala_raiz * 0.2, 0.12)
	some.parallel().tween_property($sprite, "modulate:a", 0.0, 0.12)
	some.tween_callback(func():
		global_position = onde
		aparecer())
	return true

static var textura_mover: ImageTexture

# seta em quatro direções, em pixel (é a única ação sem arte própria)
static func icone_mover() -> ImageTexture:
	if textura_mover:
		return textura_mover
	var desenho = [
		"......##......",
		".....####.....",
		"....######....",
		"......##......",
		"..#...##...#..",
		".##...##...##.",
		"##############",
		"##############",
		".##...##...##.",
		"..#...##...#..",
		"......##......",
		"....######....",
		".....####.....",
		"......##......",
	]
	var imagem = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 14:
			if desenho[y][x] == "#":
				imagem.set_pixel(x, y, Color(0.86, 0.84, 0.76))
	imagem.resize(56, 56, Image.INTERPOLATE_NEAREST)
	textura_mover = ImageTexture.create_from_image(imagem)
	return textura_mover

# solto da loja: cresce com um pulinho e aparece
func aparecer() -> void:
	if escala_raiz == Vector3.ZERO:
		escala_raiz = scale
	scale = escala_raiz * 0.3
	$sprite.modulate.a = 0.0
	tween_aparecer = create_tween().set_parallel()
	tween_aparecer.tween_property(self, "scale", escala_raiz, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_aparecer.tween_property($sprite, "modulate:a", 1.0, 0.15)
	soltar_fumaca()
	GameManager.fase.camera.tremer(3.0)

# amassa e estica rapidinho quando usa uma ação
func pulinho() -> void:
	var sprite: SpritePersonagem = $sprite
	if escala_sprite == Vector3.ZERO:
		escala_sprite = sprite.scale
	if tween_pulinho:
		tween_pulinho.kill()
	tween_pulinho = create_tween()
	tween_pulinho.tween_property(sprite, "scale", escala_sprite * Vector3(1.25, 0.8, 1.0), 0.06)
	tween_pulinho.tween_property(sprite, "scale", escala_sprite, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# balança pros lados quando a ação não deu
func negar() -> void:
	var sprite: SpritePersonagem = $sprite
	# offset é em pixels da arte: dá uns 6 cm no mundo em qualquer escala
	var passo = 0.057 / (sprite.pixel_size * sprite.global_basis.get_scale().x)
	if tween_negar:
		tween_negar.kill()
	tween_negar = create_tween()
	for x in [passo, -passo, passo * 0.5, 0.0]:
		tween_negar.tween_property(sprite, "offset:x", x, 0.05)

# espera um pouco e anda até um ponto ali perto. para com o mouse em cima (pra dar pra clicar) e quando está ocupado
func passear(delta: float) -> void:
	if not passeia:
		return
	if selecionado or no_hover or ocupado_agora():
		destino_passeio = Vector3.INF
		return
	if destino_passeio == Vector3.INF:
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
	if global_position.distance_to(destino_passeio) <= 0.05 or tempo_passeio > 8.0:
		destino_passeio = Vector3.INF

# ficou tempo demais em cima de alguém: quem passeia vai pra outro lugar
func redirecionar() -> bool:
	if not passeia or ocupado_agora():
		return false
	destino_passeio = sortear_passeio()
	tempo_passeio = 0.0
	return destino_passeio != Vector3.INF

func ocupado_agora() -> bool:
	return (has_method("ocupado") and call("ocupado")) or (has_method("ocupada") and call("ocupada"))

# um ponto da malha ali perto, no mesmo cômodo, sem parede nem cômodo proibido. INF se não achar
func sortear_passeio() -> Vector3:
	var fase = GameManager.fase
	var comodo = fase.comodo_em(global_position)
	# caiu num cômodo proibido: o passeio é o jeito de sair de lá
	var saindo = fase.comodo_proibido(global_position, comodos_proibidos)
	var alcance = raio_passeio * (3.0 if saindo else 1.0)
	for i in 12:
		var angulo = randf() * TAU
		var longe = global_position + Vector3(cos(angulo), 0.0, sin(angulo)) * randf_range(alcance * 0.3, alcance)
		var ponto = fase.ponto_na_casa(longe)
		if fase.eh_parede(ponto) or fase.comodo_proibido(ponto, comodos_proibidos):
			continue
		if not passeio_casa and not saindo and fase.comodo_em(ponto) != comodo:
			continue
		if saindo or caminho_permitido(ponto, comodo):
			return ponto
	return Vector3.INF

# o caminho até lá não passa por cômodo proibido nem, sem passeio_casa, por outro cômodo
func caminho_permitido(ate: Vector3, comodo: String) -> bool:
	var fase = GameManager.fase
	var rota = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, ate, true, 1)
	for i in range(1, rota.size()):
		var trecho = rota[i - 1].distance_to(rota[i])
		var passos = int(trecho / 0.34) + 1
		for j in passos + 1:
			var ponto = rota[i - 1].lerp(rota[i], j / float(passos))
			if fase.comodo_proibido(ponto, comodos_proibidos):
				return false
			if not passeio_casa and fase.comodo_em(ponto) != comodo:
				return false
	return true

func mover_passeio(destino: Vector3, passo: float) -> void:
	andar_pelo_caminho(destino, passo)

# cada fantasma vira do jeito dele
func virar_para(_direcao: Vector3) -> void:
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

# anda um passo seguindo a malha da casa (camada 1), sem atravessar parede. recalcula o caminho se o
# destino mudou mais de 9 cm ou se ficou um quadro sem andar (aí o caminho guardado é de outra viagem)
func andar_pelo_caminho(destino: Vector3, passo: float) -> void:
	var quadro = Engine.get_physics_frames()
	if caminho.is_empty() or quadro - quadro_caminho > 1 or destino_caminho.distance_to(destino) > 0.09:
		destino_caminho = destino
		caminho = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, destino, true, 1)
		indice_caminho = 0
	# a malha fica uns 10 cm acima do chão: compara sem o y, senão o ponto nunca é "alcançado" e ele não sai do lugar
	while indice_caminho < caminho.size() and Vector2(global_position.x - caminho[indice_caminho].x, global_position.z - caminho[indice_caminho].z).length() < 0.012:
		indice_caminho += 1
	quadro_caminho = quadro
	# sem caminho fica parado; no fim dele o último trecho é reto até o destino
	if caminho.is_empty():
		return
	var proximo = caminho[indice_caminho] if indice_caminho < caminho.size() else destino
	proximo.y = 0.0
	global_position = global_position.move_toward(proximo, passo)

func npc_mais_perto() -> Npc:
	var meu_comodo = GameManager.fase.comodo_em(global_position)
	var mais_perto: Npc = null

	for npc in get_tree().get_nodes_in_group("npc"):
		if GameManager.fase.comodo_em(npc.global_position) != meu_comodo:
			continue
		if mais_perto == null or global_position.distance_to(npc.global_position) < global_position.distance_to(mais_perto.global_position):
			mais_perto = npc

	return mais_perto

# npcs a até raio, do mais perto pro mais longe
func npcs_perto(raio: float) -> Array:
	var perto = get_tree().get_nodes_in_group("npc").filter(
		func(npc): return global_position.distance_to(npc.global_position) <= raio
	)
	perto.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return perto
